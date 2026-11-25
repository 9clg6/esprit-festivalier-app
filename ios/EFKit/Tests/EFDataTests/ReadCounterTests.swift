import Foundation
import Testing
import EFDomain
import EFData

// STORY-066 / FR-036 "Lectures d'articles comptées (mock first)" (architecture ADR-007 §4, decision 2026-11-25):
// reads counted anonymously, no user or device identifier, aggregated per article and per day;
// queued on the device now, sent later in batches by STORY-030 (`POST /v1/events`, Analytics Engine).
// "au premier affichage du texte complet": the feed excerpt never counts (review of PR #24, finding 2).
// Review of PR #24 (Opus), findings 3 and 4: the queue stays bounded, out of the backup, and a send that
// fails or is cut short loses nothing.
// Helper `temporaryDirectory` in FavoritesStoreTests.swift.
// Assumed API:
//   EFDomain: struct ArticleReadCount: Sendable, Codable, Hashable {
//     init(articleId: ArticleKey, day: String, count: Int)
//     let articleId: ArticleKey; let day: String   // "yyyy-MM-dd", Europe/Paris
//     let count: Int }
//   EFData: actor ReadCounter {
//     init(directory: URL, now: @escaping @Sendable () -> Date = { Date() })
//     func record(_ article: ArticleKey, at date: Date) throws
//     func articleShown(_ article: ArticleKey, fullText: Bool, at date: Date) throws  // counts only the full text
//     var pending: [ArticleReadCount]                       // reading it changes nothing
//     func acknowledge(_ counts: [ArticleReadCount]) throws // after a successful upload; replaces `drain()`
//   }
// Decisions specified here:
// - the day is the Paris calendar day of the read (UTC+1 in winter, UTC+2 in summer);
// - at most one read per article per day on this device (FR-036): a second read the same day is
//   not counted, even after an acknowledge; the next Paris day counts again. So a pending count is 1;
// - showing only the excerpt counts nothing and does not use up the day's read;
// - `pending` then `acknowledge`: only the acknowledged counts leave the queue; a read recorded in
//   between stays; acknowledging twice, or a count never recorded, changes nothing else;
// - reads older than 30 Paris days (by `now`) are dropped: neither pending nor kept in `reads.json`,
//   acknowledged or not. A read 30 days old is kept, 31 days old is dropped;
// - `reads.json` is excluded from the backup after the first write and stays so after later writes
//   (an atomic write replaces the file and loses the flag);
// - the encoded aggregate has exactly the keys `articleId`, `day`, `count`: no user, device or
//   install identifier, no time of day;
// - the queue, the per-day memory and the acknowledgements are kept across instances.
// Review of PR #24 (Opus): counted under the article key of ADR-007, the number of `/<slug>-<number>/`
// (`ArticleKey(numbered:)`), never the URL: two addresses of one article share the day's read, the payload's
// `articleId` is "10675", and a key the server would refuse (not 1 to 9 digits) is never queued
// (ReadCounterArticleKeyTests.swift).
// Consent (NFR-005, "respect du choix de mesure d'audience") is the caller's: no setting exists yet.

private func date(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

private func key(_ rawValue: String) -> ArticleKey { ArticleKey(rawValue: rawValue) }

private func countedRead(_ article: String, _ day: String) -> ArticleReadCount {
    ArticleReadCount(articleId: key(article), day: day, count: 1)
}

/// A clock the test moves by hand.
private final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ iso: String) { current = date(iso) }

    func now() -> Date { lock.withLock { current } }

    func set(_ iso: String) { lock.withLock { current = date(iso) } }
}

private func makeCounter(in directory: URL, clock: ManualClock) -> ReadCounter {
    ReadCounter(directory: directory, now: { clock.now() })
}

private func makeCounter(at iso: String = "2026-11-26T12:00:00Z") -> ReadCounter {
    makeCounter(in: temporaryDirectory(), clock: ManualClock(iso))
}

@Suite struct ReadCounterTests {
    @Test func nothingReadGivesNothingPending() async throws {
        let counter = makeCounter()

        #expect(await counter.pending.isEmpty)
        try await counter.acknowledge([])
        #expect(await counter.pending.isEmpty)
    }

    @Test func aReadIsQueuedForItsArticleAndParisDay() async throws {
        let counter = makeCounter()

        try await counter.record(key("10675"), at: date("2026-11-25T09:30:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theDayIsTheParisDayNotTheUTCDay() async throws {
        let winter = makeCounter(at: "2026-11-26T12:00:00Z")
        try await winter.record(key("10601"), at: date("2026-11-25T22:59:00Z"))  // 23:59 in Paris
        try await winter.record(key("10602"), at: date("2026-11-25T23:00:00Z"))   // 00:00 on the 26th
        let summer = makeCounter(at: "2026-07-15T12:00:00Z")
        try await summer.record(key("10603"), at: date("2026-07-14T22:30:00Z"))         // 00:30 on the 15th

        #expect(Set(await winter.pending) == [
            countedRead("10601", "2026-11-25"), countedRead("10602", "2026-11-26")
        ])
        #expect(await summer.pending == [countedRead("10603", "2026-07-15")])
    }

    @Test func theSameArticleReadTwiceTheSameDayCountsOnce() async throws {
        let counter = makeCounter()

        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10675"), at: date("2026-11-25T20:00:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theSameArticleTheNextDayCountsAgain() async throws {
        let counter = makeCounter()

        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10675"), at: date("2026-11-26T08:00:00Z"))

        #expect(Set(await counter.pending) == [countedRead("10675", "2026-11-25"), countedRead("10675", "2026-11-26")])
    }

    @Test func differentArticlesTheSameDayAreCountedApart() async throws {
        let counter = makeCounter()

        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10672"), at: date("2026-11-25T08:05:00Z"))

        #expect(Set(await counter.pending) == [countedRead("10675", "2026-11-25"), countedRead("10672", "2026-11-25")])
    }

    @Test func theQueueIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-11-25T12:00:00Z")
        try await makeCounter(in: directory, clock: clock).record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        let reopened = makeCounter(in: directory, clock: clock)

        #expect(await reopened.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theSameDayDedupIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-11-25T12:00:00Z")
        try await makeCounter(in: directory, clock: clock).record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        let reopened = makeCounter(in: directory, clock: clock)
        try await reopened.record(key("10675"), at: date("2026-11-25T18:00:00Z"))

        #expect(await reopened.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theQueuedPayloadHasNoIdentifierAndNoTime() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T09:30:00Z"))

        let json = try JSONEncoder().encode(await counter.pending)
        let objects = try #require(JSONSerialization.jsonObject(with: json) as? [[String: Any]])

        #expect(objects.count == 1)
        let aggregate = try #require(objects.first)
        #expect(Set(aggregate.keys) == ["articleId", "day", "count"])
        #expect(aggregate["articleId"] as? String == "10675")
        #expect(aggregate["day"] as? String == "2026-11-25")
        #expect(aggregate["count"] as? Int == 1)
    }
}

// Finding 2: "au premier affichage du texte complet". Until the native reader (STORY-055) the article
// screen shows the feed excerpt, so nothing is counted yet.
@Suite struct ReadCounterFullTextTests {
    @Test func showingTheExcerptCountsNothing() async throws {
        let counter = makeCounter()

        try await counter.articleShown(key("10675"), fullText: false, at: date("2026-11-25T09:30:00Z"))

        #expect(await counter.pending.isEmpty)
    }

    @Test func showingTheFullTextCountsARead() async throws {
        let counter = makeCounter()

        try await counter.articleShown(key("10675"), fullText: true, at: date("2026-11-25T09:30:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theExcerptFirstDoesNotUseUpTheDaysRead() async throws {
        let counter = makeCounter()

        try await counter.articleShown(key("10675"), fullText: false, at: date("2026-11-25T08:00:00Z"))
        try await counter.articleShown(key("10675"), fullText: true, at: date("2026-11-25T09:00:00Z"))
        try await counter.articleShown(key("10675"), fullText: true, at: date("2026-11-25T10:00:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }
}

// Finding 4: a destructive `drain()` lost the reads when the upload then failed. Now `pending`, the upload,
// then `acknowledge` of what was sent.
@Suite struct ReadCounterAcknowledgeTests {
    @Test func readingPendingChangesNothing() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-11-25T12:00:00Z")
        let counter = makeCounter(in: directory, clock: clock)
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        _ = await counter.pending
        _ = await counter.pending

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
        #expect(await makeCounter(in: directory, clock: clock).pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func acknowledgedCountsLeaveTheQueue() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10672"), at: date("2026-11-25T08:05:00Z"))

        try await counter.acknowledge(await counter.pending)

        #expect(await counter.pending.isEmpty)
    }

    @Test func onlyTheAcknowledgedCountsLeave() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10672"), at: date("2026-11-25T08:05:00Z"))

        try await counter.acknowledge([countedRead("10675", "2026-11-25")])

        #expect(await counter.pending == [countedRead("10672", "2026-11-25")])
    }

    @Test func aReadRecordedDuringTheUploadIsNotLost() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        let sent = await counter.pending

        try await counter.record(key("10672"), at: date("2026-11-25T08:05:00Z"))
        try await counter.acknowledge(sent)

        #expect(await counter.pending == [countedRead("10672", "2026-11-25")])
    }

    @Test func unacknowledgedCountsSurviveARestart() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-11-25T12:00:00Z")
        let counter = makeCounter(in: directory, clock: clock)
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        _ = await counter.pending  // the upload starts, then the app is killed

        let reopened = makeCounter(in: directory, clock: clock)

        #expect(await reopened.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func acknowledgingTwiceIsHarmless() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.record(key("10672"), at: date("2026-11-25T08:05:00Z"))
        let sent = [countedRead("10675", "2026-11-25")]

        try await counter.acknowledge(sent)
        try await counter.acknowledge(sent)

        #expect(await counter.pending == [countedRead("10672", "2026-11-25")])
        try await counter.record(key("10675"), at: date("2026-11-25T21:00:00Z"))
        #expect(await counter.pending == [countedRead("10672", "2026-11-25")], "the day's read stays used up")
    }

    @Test func acknowledgingACountNeverRecordedDoesNotBlockThatRead() async throws {
        let counter = makeCounter()

        try await counter.acknowledge([countedRead("10675", "2026-11-25")])
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func aReadTheSameDayAfterAnAcknowledgeIsNotCountedAgain() async throws {
        let counter = makeCounter()
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.acknowledge(await counter.pending)

        try await counter.record(key("10675"), at: date("2026-11-25T21:00:00Z"))

        #expect(await counter.pending.isEmpty)
    }

    @Test func anAcknowledgeIsKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-11-25T12:00:00Z")
        let counter = makeCounter(in: directory, clock: clock)
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))
        try await counter.acknowledge(await counter.pending)

        let reopened = makeCounter(in: directory, clock: clock)
        #expect(await reopened.pending.isEmpty)
        try await reopened.record(key("10675"), at: date("2026-11-25T18:00:00Z"))

        #expect(await reopened.pending.isEmpty)
    }
}

// Finding 3: the queue stays bounded (30 days) and out of the device backup.
@Suite struct ReadCounterRetentionTests {
    @Test func aReadOf30DaysAgoIsStillPending() async throws {
        let clock = ManualClock("2026-10-26T10:00:00Z")
        let counter = makeCounter(in: temporaryDirectory(), clock: clock)
        try await counter.record(key("10675"), at: date("2026-10-26T10:00:00Z"))

        clock.set("2026-11-25T11:00:00Z")

        #expect(await counter.pending == [countedRead("10675", "2026-10-26")])
    }

    @Test func aReadOf31DaysAgoIsDropped() async throws {
        let clock = ManualClock("2026-10-25T10:00:00Z")
        let counter = makeCounter(in: temporaryDirectory(), clock: clock)
        try await counter.record(key("10675"), at: date("2026-10-25T10:00:00Z"))

        clock.set("2026-11-25T11:00:00Z")

        #expect(await counter.pending.isEmpty)
    }

    @Test func anExpiredReadIsNotPendingAfterARestartEither() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-10-01T10:00:00Z")
        try await makeCounter(in: directory, clock: clock).record(key("10675"), at: date("2026-10-01T10:00:00Z"))

        clock.set("2026-11-25T11:00:00Z")

        #expect(await makeCounter(in: directory, clock: clock).pending.isEmpty)
    }

    @Test func daysOlderThan30DaysLeaveTheFile() async throws {
        let directory = temporaryDirectory()
        let clock = ManualClock("2026-10-01T10:00:00Z")
        let counter = makeCounter(in: directory, clock: clock)
        try await counter.record(key("10604"), at: date("2026-10-01T10:00:00Z"))
        try await counter.acknowledge(await counter.pending)
        clock.set("2026-10-02T10:00:00Z")
        try await counter.record(key("10605"), at: date("2026-10-02T10:00:00Z"))

        clock.set("2026-11-25T11:00:00Z")
        try await counter.record(key("10675"), at: date("2026-11-25T11:00:00Z"))

        let stored = try String(contentsOf: directory.appending(path: "reads.json"), encoding: .utf8)
        #expect(!stored.contains("2026-10-01"), "the memory of an acknowledged old day is dropped")
        #expect(!stored.contains("2026-10-02"), "an old read never sent is dropped")
        #expect(stored.contains("2026-11-25"))
        #expect(await counter.pending == [countedRead("10675", "2026-11-25")])
    }

    @Test func theFileIsExcludedFromTheBackupAfterTheFirstWrite() async throws {
        let directory = temporaryDirectory()
        let counter = makeCounter(in: directory, clock: ManualClock("2026-11-25T12:00:00Z"))

        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        #expect(try isExcludedFromBackup(directory.appending(path: "reads.json")))
    }

    @Test func theFileStaysExcludedFromTheBackupAfterLaterWrites() async throws {
        let directory = temporaryDirectory()
        let counter = makeCounter(in: directory, clock: ManualClock("2026-11-25T12:00:00Z"))
        try await counter.record(key("10675"), at: date("2026-11-25T08:00:00Z"))

        try await counter.record(key("10672"), at: date("2026-11-25T09:00:00Z"))
        #expect(try isExcludedFromBackup(directory.appending(path: "reads.json")), "after a second read")

        try await counter.acknowledge(await counter.pending)
        #expect(try isExcludedFromBackup(directory.appending(path: "reads.json")), "after an acknowledge")
    }

    private func isExcludedFromBackup(_ file: URL) throws -> Bool {
        var file = file
        file.removeAllCachedResourceValues()
        return try file.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true
    }
}
