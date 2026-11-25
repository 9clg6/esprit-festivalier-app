import Foundation
import Testing
import EFDomain
import EFData

// Review of PR #24 (Opus): reads (STORY-066, FR-036) are counted under the article key of ADR-007, the
// number of `/<slug>-<number>/` (`ArticleKey(numbered:)`), never the article's URL:
// - two addresses of one article (another slug, a tracking query, http, www) share the day's read;
// - the payload's `articleId` is the number ("10675"), the address appears nowhere;
// - the server will only take 1 to 9 digits ("Clés d'articles validées"): any other key is never queued,
//   and nothing is written for it. The article screen skips an article whose address has no number.
// Helper `temporaryDirectory` in FavoritesStoreTests.swift.

private let noon = try! Date("2026-11-25T12:00:00Z", strategy: .iso8601)
private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

private func makeCounter(in directory: URL = temporaryDirectory()) -> ReadCounter {
    ReadCounter(directory: directory, now: { noon })
}

private func numbered(_ address: String) throws -> ArticleKey {
    try #require(ArticleKey(numbered: URL(string: address)!), "no key for \(address)")
}

private let articleAddress = "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/"

@Suite struct ReadCounterArticleKeyTests {
    @Test(arguments: [
        "https://esprit-festivalier.fr/a-nantes-orelsan-seduit-10675/",
        "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/?utm_source=rss&utm_medium=app",
        "http://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/",
        "https://www.esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675"
    ])
    func anotherAddressOfTheSameArticleTheSameDayIsNotCountedAgain(_ otherAddress: String) async throws {
        let counter = makeCounter()

        try await counter.articleShown(try numbered(articleAddress), fullText: true, at: date("2026-11-25T08:00:00Z"))
        try await counter.articleShown(try numbered(otherAddress), fullText: true, at: date("2026-11-25T20:00:00Z"))

        #expect(await counter.pending == [
            ArticleReadCount(articleId: ArticleKey(rawValue: "10675"), day: "2026-11-25", count: 1)
        ])
    }

    @Test func thePayloadCarriesTheArticleNumberNeverItsAddress() async throws {
        let counter = makeCounter()
        try await counter.record(try numbered(articleAddress + "?utm_source=rss"), at: date("2026-11-25T09:30:00Z"))

        let json = try JSONEncoder().encode(await counter.pending)
        let objects = try #require(JSONSerialization.jsonObject(with: json) as? [[String: Any]])

        #expect(objects.count == 1)
        #expect(objects.first?["articleId"] as? String == "10675")
        let text = try #require(String(bytes: json, encoding: .utf8))
        #expect(!text.contains("esprit-festivalier"))
        #expect(!text.contains("orelsan"))
    }

    @Test(arguments: ["/a-propos/", "https://esprit-festivalier.fr/a-propos/", "1234567890", ""])
    func aKeyTheServerWouldRefuseIsNeverQueued(_ rawKey: String) async throws {
        let directory = temporaryDirectory()
        let counter = makeCounter(in: directory)

        try await counter.record(ArticleKey(rawValue: rawKey), at: date("2026-11-25T08:00:00Z"))
        try await counter.articleShown(ArticleKey(rawValue: rawKey), fullText: true, at: date("2026-11-25T09:00:00Z"))

        #expect(await counter.pending.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "reads.json").path))
    }
}
