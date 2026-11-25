import Foundation
import Testing
import EFDomain
import EFData

// STORY-066 / FR-036 "Lectures d'articles comptées (mock first)" (architecture ADR-007 §4, decision 2026-11-25):
// reads counted anonymously, no user or device identifier, aggregated per article and per day;
// queued on the device now, sent later in batches by STORY-030 (`POST /v1/events`, Analytics Engine).
// Helper `temporaryDirectory` in FavoritesStoreTests.swift.
// Assumed API:
//   EFDomain: struct ArticleReadCount: Sendable, Codable, Hashable {
//     init(articleId: Article.ID, day: String, count: Int)
//     let articleId: Article.ID; let day: String   // "yyyy-MM-dd", Europe/Paris
//     let count: Int }
//   EFData: actor ReadCounter {
//     init(directory: URL)
//     func record(_ article: Article.ID, at date: Date) throws
//     var pending: [ArticleReadCount]
//     func drain() throws -> [ArticleReadCount]   // returns the pending aggregates and clears them
//   }
// Decisions specified here:
// - the day is the Paris calendar day of the read (UTC+1 in winter, UTC+2 in summer);
// - at most one read per article per day on this device (FR-036): a second read the same day is
//   not counted, even after a drain; the next Paris day counts again. So a pending count is 1;
// - the encoded aggregate has exactly the keys `articleId`, `day`, `count`: no user, device or
//   install identifier, no time of day;
// - the queue and the per-day memory are kept across instances; a drain is kept too.
// Consent (NFR-005, "respect du choix de mesure d'audience") is the caller's: no setting exists yet.

private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

private func countedRead(_ article: Article.ID, _ day: String) -> ArticleReadCount {
    ArticleReadCount(articleId: article, day: day, count: 1)
}

@Suite struct ReadCounterTests {
    @Test func nothingReadGivesNothingPending() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        #expect(await counter.pending.isEmpty)
        #expect(try await counter.drain().isEmpty)
    }

    @Test func aReadIsQueuedForItsArticleAndParisDay() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        try await counter.record("10675", at: date("2026-11-25T09:30:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theDayIsTheParisDayNotTheUTCDay() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        try await counter.record("winter-before", at: date("2026-11-25T22:59:00Z"))  // 23:59 in Paris
        try await counter.record("winter-after", at: date("2026-11-25T23:00:00Z"))   // 00:00 on the 26th
        try await counter.record("summer", at: date("2026-07-14T22:30:00Z"))         // 00:30 on the 15th

        #expect(Set(await counter.pending) == [
            countedRead("winter-before", "2026-11-25"), countedRead("winter-after", "2026-11-26"), countedRead("summer", "2026-07-15")
        ])
    }

    @Test func theSameArticleReadTwiceTheSameDayCountsOnce() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        try await counter.record("10675", at: date("2026-11-25T20:00:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theSameArticleTheNextDayCountsAgain() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        try await counter.record("10675", at: date("2026-11-26T08:00:00Z"))

        #expect(Set(await counter.pending) == [countedRead("10675", "2026-11-25"), countedRead("10675", "2026-11-26")])
    }

    @Test func differentArticlesTheSameDayAreCountedApart() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())

        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        try await counter.record("10672", at: date("2026-11-25T08:05:00Z"))

        #expect(Set(await counter.pending) == [countedRead("10675", "2026-11-25"), countedRead("10672", "2026-11-25")])
    }

    @Test func drainReturnsThePendingAggregatesAndClearsThem() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())
        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        try await counter.record("10672", at: date("2026-11-25T08:05:00Z"))

        let drained = try await counter.drain()

        #expect(Set(drained) == [countedRead("10675", "2026-11-25"), countedRead("10672", "2026-11-25")])
        #expect(await counter.pending.isEmpty)
        #expect(try await counter.drain().isEmpty)
    }

    @Test func aReadTheSameDayAfterADrainIsNotCountedAgain() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())
        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        #expect(try await counter.drain() == [countedRead("10675", "2026-11-25")])

        try await counter.record("10675", at: date("2026-11-25T21:00:00Z"))

        #expect(await counter.pending.isEmpty)
    }

    @Test func theQueueIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        try await ReadCounter(directory: directory).record("10675", at: date("2026-11-25T08:00:00Z"))

        let reopened = ReadCounter(directory: directory)

        #expect(await reopened.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theSameDayDedupIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        try await ReadCounter(directory: directory).record("10675", at: date("2026-11-25T08:00:00Z"))

        let reopened = ReadCounter(directory: directory)
        try await reopened.record("10675", at: date("2026-11-25T18:00:00Z"))

        #expect(await reopened.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func aDrainIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        let counter = ReadCounter(directory: directory)
        try await counter.record("10675", at: date("2026-11-25T08:00:00Z"))
        #expect(try await counter.drain() == [countedRead("10675", "2026-11-25")])

        let reopened = ReadCounter(directory: directory)
        try await reopened.record("10675", at: date("2026-11-25T18:00:00Z"))

        #expect(await reopened.pending.isEmpty)
    }

    @Test func theQueuedPayloadHasNoIdentifierAndNoTime() async throws {
        let counter = ReadCounter(directory: temporaryDirectory())
        try await counter.record("10675", at: date("2026-11-25T09:30:00Z"))

        let json = try JSONEncoder().encode(try await counter.drain())
        let objects = try #require(JSONSerialization.jsonObject(with: json) as? [[String: Any]])

        #expect(objects.count == 1)
        let aggregate = try #require(objects.first)
        #expect(Set(aggregate.keys) == ["articleId", "day", "count"])
        #expect(aggregate["articleId"] as? String == "10675")
        #expect(aggregate["day"] as? String == "2026-11-25")
        #expect(aggregate["count"] as? Int == 1)
    }
}
