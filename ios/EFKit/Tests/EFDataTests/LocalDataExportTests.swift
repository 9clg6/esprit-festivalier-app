import Foundation
import Testing
import EFDomain
import EFData

// STORY-032 "Confidentialité": "Exporter mes données" from the Profil (UX E12, NFR-005 export RGPD).
// Mock first: no `GET /v1/me/export` yet, so the export is built on the device from what it knows.
// Helper `temporaryDirectory` in FavoritesStoreTests.swift.
// Assumed API (EFData, pure):
//   struct LocalDataExport: Sendable, Codable, Equatable {
//     init(account: AuthSession?, favorites: [FavoriteEntry], picks: [PickEntry], reactions: [ReactionEntry],
//          reminderLead: ReminderLead, notifications: [String: Bool], exportedAt: Date)
//     func json() throws -> Data          // the document the user gets
//     init(json: Data) throws             // reads it back
//   }
// Decisions specified here:
// - top-level keys, always present: exportedAt, account (null when signed out), favorites, picks,
//   reactions (STORY-058), reminderLeadMinutes, notifications;
// - account: userId, provider ("apple" | "email"), email (email accounts), createdAt;
//   favorite: festivalId, addedAt; pick: performanceId, festivalId, pickedAt;
//   reaction: articleId (the ADR-007 article key, "10675", never the URL), reaction (its key, "love"), reactedAt;
// - article reads (STORY-066) are not exported: anonymous aggregates, nothing personal;
// - dates in ISO 8601 ("2026-11-25T09:30:00Z"); keys sorted, so the same data gives the same bytes;
// - only live favorites, picks and reactions: no tombstone, no `deleted` key anywhere;
// - `notifications` is the per-type switches known on the device, as given (STORY-024 owns the types);
// - the document decodes back to an equal value.

private let addedAt = try! Date("2026-11-25T09:30:00Z", strategy: .iso8601)
private let exportedAt = try! Date("2026-11-26T08:00:00Z", strategy: .iso8601)
private let emailAccount = AuthSession(
    userId: "user-1", provider: .email, email: "fan@example.org",
    createdAt: try! Date("2026-11-20T12:00:00Z", strategy: .iso8601)
)

private struct StoredData {
    let favorites: [FavoriteEntry]
    let picks: [PickEntry]
    let reactions: [ReactionEntry]
}

/// A favorite, a pick and a reaction kept, one of each removed (tombstones), all dated `addedAt`.
private func storedData() async throws -> StoredData {
    let directory = temporaryDirectory()
    let favorites = FavoritesStore(directory: directory, now: { addedAt })
    try await favorites.add("hellfest")
    try await favorites.add("removed-festival")
    try await favorites.remove("removed-festival")
    let picks = PicksStore(directory: directory, now: { addedAt })
    try await picks.setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
    try await picks.setPicked("hellfest-removed-set", true, festivalId: "hellfest")
    try await picks.setPicked("hellfest-removed-set", false, festivalId: "hellfest")
    let reactions = LocalReactionService(directory: directory, now: { addedAt })
    // Reacted from the article's address: exported under its ADR-007 key ("10675"), never the URL.
    let article = try #require(ArticleKey(numbered: URL(string: "https://esprit-festivalier.fr/orelsan-10675/?utm_source=rss")!))
    _ = try await reactions.set(.love, active: true, on: article)
    _ = try await reactions.set(.fire, active: true, on: ArticleKey(rawValue: "99999"))
    _ = try await reactions.set(.fire, active: false, on: ArticleKey(rawValue: "99999"))
    return StoredData(favorites: await favorites.entries, picks: await picks.entries, reactions: await reactions.entries)
}

private func export(account: AuthSession? = emailAccount) async throws -> LocalDataExport {
    let data = try await storedData()
    return LocalDataExport(
        account: account, favorites: data.favorites, picks: data.picks, reactions: data.reactions, reminderLead: .ten,
        notifications: ["articles": true, "favoris": false], exportedAt: exportedAt
    )
}

private func object(_ export: LocalDataExport) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: export.json()) as? [String: Any])
}

private func list(_ key: String, in export: LocalDataExport) throws -> [[String: Any]] {
    try #require(try object(export)[key] as? [[String: Any]])
}

@Suite struct LocalDataExportTests {
    @Test func theDocumentHasTheStableTopLevelKeys() async throws {
        let keys = Set(try object(try await export()).keys)

        #expect(keys == ["exportedAt", "account", "favorites", "picks", "reactions", "reminderLeadMinutes", "notifications"])
    }

    @Test func theAccountIsExported() async throws {
        let account = try #require(try object(try await export())["account"] as? [String: Any])

        #expect(account["userId"] as? String == "user-1")
        #expect(account["provider"] as? String == "email")
        #expect(account["email"] as? String == "fan@example.org")
        #expect(account["createdAt"] as? String == "2026-11-20T12:00:00Z")
    }

    @Test func anAppleAccountSaysApple() async throws {
        let apple = AuthSession(userId: "user-2", provider: .apple, email: nil, createdAt: addedAt)

        let account = try #require(try object(try await export(account: apple))["account"] as? [String: Any])

        #expect(account["provider"] as? String == "apple")
    }

    @Test func signedOutTheAccountIsNull() async throws {
        let document = try object(try await export(account: nil))

        #expect(document.keys.contains("account"))
        #expect(document["account"] is NSNull)
    }

    @Test func liveFavoritesAreExportedWithTheirDate() async throws {
        let favorites = try list("favorites", in: try await export())

        #expect(favorites.count == 1)
        #expect(favorites.first?["festivalId"] as? String == "hellfest")
        #expect(favorites.first?["addedAt"] as? String == "2026-11-25T09:30:00Z")
    }

    @Test func livePicksAreExportedWithTheirFestivalAndDate() async throws {
        let picks = try list("picks", in: try await export())

        #expect(picks.count == 1)
        #expect(picks.first?["performanceId"] as? String == "hellfest-iron-maiden")
        #expect(picks.first?["festivalId"] as? String == "hellfest")
        #expect(picks.first?["pickedAt"] as? String == "2026-11-25T09:30:00Z")
    }

    @Test func liveReactionsAreExportedByKeyWithTheirDate() async throws {
        let reactions = try list("reactions", in: try await export())

        #expect(reactions.count == 1)
        #expect(reactions.first?["articleId"] as? String == "10675")
        #expect(reactions.first?["reaction"] as? String == "love")
        #expect(reactions.first?["reactedAt"] as? String == "2026-11-25T09:30:00Z")
        #expect(reactions.first.map { Set($0.keys) } == ["articleId", "reaction", "reactedAt"])
    }

    @Test func articleReadsAreNotExported() async throws {
        let keys = Set(try object(try await export()).keys)

        #expect(!keys.contains { $0.lowercased().contains("read") })
    }

    @Test func noTombstoneIsExported() async throws {
        let text = try #require(String(bytes: try await export().json(), encoding: .utf8))

        #expect(!text.contains("removed-festival"))
        #expect(!text.contains("hellfest-removed-set"))
        #expect(!text.contains("99999"))
        #expect(!text.contains("deleted"))
    }

    @Test func remindersAndNotificationPreferencesAreExported() async throws {
        let document = try object(try await export())

        #expect(document["reminderLeadMinutes"] as? Int == 10)
        #expect(document["notifications"] as? [String: Bool] == ["articles": true, "favoris": false])
        #expect(document["exportedAt"] as? String == "2026-11-26T08:00:00Z")
    }

    @Test func nothingStoredGivesEmptyLists() throws {
        let empty = LocalDataExport(
            account: nil, favorites: [], picks: [], reactions: [], reminderLead: .default, notifications: [:], exportedAt: exportedAt
        )
        let document = try object(empty)

        #expect((document["favorites"] as? [Any])?.isEmpty == true)
        #expect((document["picks"] as? [Any])?.isEmpty == true)
        #expect((document["reactions"] as? [Any])?.isEmpty == true)
        #expect(document["reminderLeadMinutes"] as? Int == 15)
    }

    @Test func theSameDataGivesTheSameBytesWithSortedKeys() async throws {
        let first = try await export()
        let second = try await export()

        #expect(try first.json() == second.json())
        let text = try #require(String(bytes: try first.json(), encoding: .utf8))
        let order = ["\"account\"", "\"exportedAt\"", "\"favorites\"", "\"notifications\"", "\"picks\"", "\"reactions\"", "\"reminderLeadMinutes\""]
            .compactMap { text.range(of: $0)?.lowerBound }
        #expect(order.count == 7)
        #expect(order == order.sorted())
    }

    @Test func theDocumentDecodesBack() async throws {
        let original = try await export()

        #expect(try LocalDataExport(json: original.json()) == original)
    }

    @Test func aSignedOutDocumentDecodesBack() async throws {
        let original = try await export(account: nil)

        #expect(try LocalDataExport(json: original.json()) == original)
    }
}
