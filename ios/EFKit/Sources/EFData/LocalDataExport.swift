import EFDomain
import Foundation

/// "Exporter mes données" (STORY-032, NFR-005), built on the device until `GET /v1/me/export`
/// exists. Only live favorites, picks and reactions; article reads (anonymous) are not exported.
/// Keys sorted, so the same data gives the same bytes.
public struct LocalDataExport: Sendable, Codable, Equatable {
    public let account: AuthSession?
    public let favorites: [FavoriteEntry]
    public let picks: [PickEntry]
    public let reactions: [ReactionEntry]
    public let reminderLead: ReminderLead
    /// Per-type notification switches known on the device (STORY-024 owns the types).
    public let notifications: [String: Bool]
    public let exportedAt: Date

    public init(
        account: AuthSession?, favorites: [FavoriteEntry], picks: [PickEntry], reactions: [ReactionEntry],
        reminderLead: ReminderLead, notifications: [String: Bool], exportedAt: Date
    ) {
        self.account = account
        self.favorites = favorites.filter { !$0.deleted }
        self.picks = picks.filter { !$0.deleted }
        self.reactions = reactions.filter { !$0.deleted }
        self.reminderLead = reminderLead
        self.notifications = notifications
        self.exportedAt = exportedAt
    }

    public init(json: Data) throws {
        self = try Self.decoder.decode(Self.self, from: json)
    }

    public func json() throws -> Data { try Self.encoder.encode(self) }

    private enum CodingKeys: String, CodingKey {
        case account, favorites, picks, reactions, reminderLeadMinutes, notifications, exportedAt
    }

    private struct Favorite: Codable {
        let festivalId: Festival.ID
        let addedAt: Date
    }

    private struct Pick: Codable {
        let performanceId: Performance.ID
        let festivalId: Festival.ID?
        let pickedAt: Date
    }

    private struct ReactionItem: Codable {
        let articleId: ArticleKey
        let reaction: Reaction
        let reactedAt: Date
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let minutes = try container.decode(Int.self, forKey: .reminderLeadMinutes)
        guard let lead = ReminderLead(rawValue: minutes) else {
            throw DecodingError.dataCorruptedError(
                forKey: .reminderLeadMinutes, in: container, debugDescription: "Unknown reminder lead \(minutes)"
            )
        }
        self.init(
            account: try container.decodeIfPresent(AuthSession.self, forKey: .account),
            favorites: try container.decode([Favorite].self, forKey: .favorites).map {
                FavoriteEntry(festivalId: $0.festivalId, updatedAt: $0.addedAt, deleted: false)
            },
            picks: try container.decode([Pick].self, forKey: .picks).map {
                PickEntry(
                    performanceId: $0.performanceId, festivalId: $0.festivalId, updatedAt: $0.pickedAt, deleted: false
                )
            },
            reactions: try container.decode([ReactionItem].self, forKey: .reactions).map {
                ReactionEntry(articleId: $0.articleId, reaction: $0.reaction, updatedAt: $0.reactedAt, deleted: false)
            },
            reminderLead: lead,
            notifications: try container.decode([String: Bool].self, forKey: .notifications),
            exportedAt: try container.decode(Date.self, forKey: .exportedAt)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // `null` when signed out: the key is always there.
        try container.encode(account, forKey: .account)
        try container.encode(
            favorites.map { Favorite(festivalId: $0.festivalId, addedAt: $0.updatedAt) }, forKey: .favorites
        )
        try container.encode(
            picks.map { Pick(performanceId: $0.performanceId, festivalId: $0.festivalId, pickedAt: $0.updatedAt) },
            forKey: .picks
        )
        try container.encode(
            reactions.map { ReactionItem(articleId: $0.articleId, reaction: $0.reaction, reactedAt: $0.updatedAt) },
            forKey: .reactions
        )
        try container.encode(reminderLead.rawValue, forKey: .reminderLeadMinutes)
        try container.encode(notifications, forKey: .notifications)
        try container.encode(exportedAt, forKey: .exportedAt)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
