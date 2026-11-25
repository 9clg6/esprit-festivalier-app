import Foundation

/// What the Profil switches on (STORY-024). Kept on the device until the server exists.
public struct NotificationPreferences: Sendable, Hashable, Codable {
    public var festivalJ7: Bool
    public var festivalJ1: Bool
    /// The article sections notified (FR-012: only "Programmation" by default).
    public var articleCategories: Set<Article.Category>

    public init(
        festivalJ7: Bool = true, festivalJ1: Bool = true, articleCategories: Set<Article.Category> = [.programmation]
    ) {
        self.festivalJ7 = festivalJ7
        self.festivalJ1 = festivalJ1
        self.articleCategories = articleCategories
    }

    /// A field saved by no older build gets its default.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NotificationPreferences()
        festivalJ7 = try values.decodeIfPresent(Bool.self, forKey: .festivalJ7) ?? defaults.festivalJ7
        festivalJ1 = try values.decodeIfPresent(Bool.self, forKey: .festivalJ1) ?? defaults.festivalJ1
        articleCategories = try values.decodeIfPresent(Set<Article.Category>.self, forKey: .articleCategories)
            ?? defaults.articleCategories
    }
}

public enum FestivalReminderKind: String, CaseIterable, Sendable {
    // swiftlint:disable:next identifier_name
    case j7, j1

    var daysBefore: Int { self == .j7 ? 7 : 1 }
}

public struct FestivalReminder: Sendable, Hashable {
    /// Depends on the festival and the kind only: planning again replaces, never duplicates.
    public let id: String
    public let festivalId: Festival.ID
    public let kind: FestivalReminderKind
    public let fireDate: Date
    public let body: String

    public init(id: String, festivalId: Festival.ID, kind: FestivalReminderKind, fireDate: Date, body: String) {
        self.id = id
        self.festivalId = festivalId
        self.kind = kind
        self.fireDate = fireDate
        self.body = body
    }
}

/// J-7 and J-1 of the favorite festivals, at 10:00 on the caller's calendar (STORY-025).
public enum FestivalReminders {
    public static let identifierPrefix = "fav-"

    public static func plan(
        favorites: [Festival], preferences: NotificationPreferences, now: Date, calendar: Calendar
    ) -> [FestivalReminder] {
        let kinds = FestivalReminderKind.allCases.filter {
            $0 == .j7 ? preferences.festivalJ7 : preferences.festivalJ1
        }
        return favorites.flatMap { festival in
            kinds.compactMap { kind -> FestivalReminder? in
                let firstDay = calendar.startOfDay(for: festival.startDate)
                guard let day = calendar.date(byAdding: .day, value: -kind.daysBefore, to: firstDay),
                      let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
                      fireDate > now
                else { return nil }
                return FestivalReminder(
                    id: "\(identifierPrefix)\(festival.id)-\(kind.rawValue)", festivalId: festival.id, kind: kind,
                    fireDate: fireDate,
                    body: kind == .j7 ? "\(festival.name) commence dans 7 jours" : "\(festival.name) commence demain !"
                )
            }
        }
        .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
    }
}

/// Concert and festival reminders share the 64 pending local notifications iOS keeps.
public struct NotificationPlan: Sendable, Hashable {
    public let concerts: [ConcertReminder]
    public let festivals: [FestivalReminder]

    /// The `limit` earliest fire dates, whatever their kind; a tie goes to the concert.
    public static func earliest(
        concerts: [ConcertReminder], festivals: [FestivalReminder], limit: Int = ConcertReminders.limit
    ) -> NotificationPlan {
        let concerts = concerts.sorted { $0.fireDate < $1.fireDate }
        let festivals = festivals.sorted { $0.fireDate < $1.fireDate }
        var keptConcerts = 0
        var keptFestivals = 0
        while keptConcerts + keptFestivals < limit {
            let concert = concerts.indices.contains(keptConcerts) ? concerts[keptConcerts].fireDate : nil
            let festival = festivals.indices.contains(keptFestivals) ? festivals[keptFestivals].fireDate : nil
            switch (concert, festival) {
            case (nil, nil): return NotificationPlan(concerts: concerts, festivals: festivals)
            case let (concert?, festival?) where festival < concert: keptFestivals += 1
            case (_?, _): keptConcerts += 1
            case (nil, _?): keptFestivals += 1
            }
        }
        return NotificationPlan(
            concerts: Array(concerts.prefix(keptConcerts)), festivals: Array(festivals.prefix(keptFestivals))
        )
    }
}

public enum ArticleNotification: Sendable, Hashable {
    case article(Article)
    case summary(count: Int)

    public var body: String {
        switch self {
        case .article(let article): article.title
        case .summary(let count): "\(count) nouveaux articles"
        }
    }
}

public struct ArticleCheck: Sendable, Hashable {
    public let notifications: [ArticleNotification]
    /// To keep for the next refresh.
    public let seen: Set<Article.ID>
}

/// The articles of the feed not seen at the last refresh, in the followed sections (STORY-027).
public enum NewArticles {
    public static let maxNotifications = 3

    /// `seen == nil` is the first run: everything is recorded, nothing notified.
    public static func check(
        feed: [Article], seen: Set<Article.ID>?, preferences: NotificationPreferences
    ) -> ArticleCheck {
        let allSeen = (seen ?? []).union(feed.map(\.id))
        guard let seen else { return ArticleCheck(notifications: [], seen: allSeen) }
        let new = feed
            .filter { !seen.contains($0.id) && preferences.articleCategories.contains($0.category) }
            .sorted { $0.publishedAt > $1.publishedAt }
        let notifications: [ArticleNotification] = new.count > maxNotifications
            ? [.summary(count: new.count)] : new.map { .article($0) }
        return ArticleCheck(notifications: notifications, seen: allSeen)
    }
}
