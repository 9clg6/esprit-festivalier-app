import Foundation
import Testing
import EFDomain
import EFData

// STORY-058 / FR-030 "Réactions sur l'appareil (mock first)" (architecture ADR-007 §3; UX "Réactions : états").
// Works without an account; kept on the device (ADR-004) until the server (STORY-061) exists.
// Same file store as FavoritesStore (helpers `temporaryDirectory`, `SteppingClock` in FavoritesStoreTests.swift).
// Assumed API (EFData):
//   struct ReactionEntry: Sendable, Codable, Hashable {
//     let articleId: ArticleKey; let reaction: Reaction; let updatedAt: Date; let deleted: Bool }
//   actor LocalReactionService: ReactionService {
//     init(directory: URL, demoCounts: Bool = false, now: @escaping @Sendable () -> Date = { Date() })
//     var entries: [ReactionEntry]   // for the export, tombstones included
//   }
// Decisions specified here:
// - one active reaction per type per article; several types on one article; tapping again removes it;
// - `set` is idempotent (same value twice: same entry, same date); removing keeps a tombstone
//   (deleted, later updatedAt), like favorites, for the future sync; removing a never-set one leaves no entry;
// - one file, `reactions.json`, in the given directory (created if missing); kept across instances;
//   deleting the directory (account deletion) resets the reactions;
// - an unreadable non-empty file is kept aside, unchanged, as `reactions.corrupt.json` before the first write;
// - no fake counts: by default `counts == nil` and `isDemo == false`, even after reacting
//   (UX: "libellé seul ; jamais de « 0 »"); `demoCounts: true` (source `mock`) gives counts for
//   every reaction, flagged `isDemo`, stable for an article, and my active reaction adds 1.
// Review of PR #24 (Opus): keyed by `ArticleKey` (ADR-007), the number of `/<slug>-<number>/`, not by the
// article's URL: a changed slug, a tracking query, http or www keep the reactions; the server will only
// take 1 to 9 digits, so a key that is not one is never stored (the bar is not shown for such an article).

private let article = ArticleKey(rawValue: "10675")
private let otherArticle = ArticleKey(rawValue: "10672")
private let articleAddress = "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/"

private func key(_ address: String) throws -> ArticleKey {
    try #require(ArticleKey(numbered: URL(string: address)!), "no key for \(address)")
}

private func makeService(
    in directory: URL, demoCounts: Bool = false, clock: SteppingClock = SteppingClock()
) -> LocalReactionService {
    LocalReactionService(directory: directory, demoCounts: demoCounts, now: { clock.now() })
}

private func entry(_ reaction: Reaction, on article: ArticleKey, in service: LocalReactionService) async throws
    -> ReactionEntry {
    try #require(
        await service.entries.first { $0.articleId == article && $0.reaction == reaction },
        "no entry for \(reaction) on \(article)"
    )
}

@Suite struct LocalReactionServiceTests {
    @Test func aNewArticleHasNoReactionOfMine() async throws {
        let summary = try await makeService(in: temporaryDirectory()).summary(for: article)

        #expect(summary.mine.isEmpty)
    }

    @Test func reactingMarksTheReactionAsMine() async throws {
        let service = makeService(in: temporaryDirectory())

        let returned = try await service.set(.love, active: true, on: article)

        #expect(returned.mine == [.love])
        #expect(try await service.summary(for: article).mine == [.love])
    }

    @Test func tappingAgainRemovesIt() async throws {
        let service = makeService(in: temporaryDirectory())

        #expect(try await service.toggle(.fire, on: article).mine == [.fire])
        #expect(try await service.toggle(.fire, on: article).mine.isEmpty)
        #expect(try await service.summary(for: article).mine.isEmpty)
    }

    @Test func severalReactionTypesOnOneArticleAreAllowed() async throws {
        let service = makeService(in: temporaryDirectory())

        try await service.toggle(.love, on: article)
        try await service.toggle(.clap, on: article)
        try await service.toggle(.insight, on: article)

        #expect(try await service.summary(for: article).mine == [.love, .clap, .insight])
    }

    @Test func reactionsBelongToTheirArticle() async throws {
        let service = makeService(in: temporaryDirectory())

        try await service.toggle(.wow, on: article)

        #expect(try await service.summary(for: article).mine == [.wow])
        #expect(try await service.summary(for: otherArticle).mine.isEmpty)
    }

    @Test func settingTheSameReactionTwiceKeepsOneEntryWithItsFirstDate() async throws {
        let service = makeService(in: temporaryDirectory())
        try await service.set(.love, active: true, on: article)
        let first = try await entry(.love, on: article, in: service)

        try await service.set(.love, active: true, on: article)

        #expect(await service.entries.count == 1)
        #expect(try await entry(.love, on: article, in: service) == first)
    }

    @Test func removingANeverSetReactionLeavesNoEntry() async throws {
        let service = makeService(in: temporaryDirectory())

        let summary = try await service.set(.clap, active: false, on: article)

        #expect(summary.mine.isEmpty)
        #expect(await service.entries.isEmpty)
    }

    @Test func removingKeepsATombstoneWithALaterDate() async throws {
        let service = makeService(in: temporaryDirectory())
        try await service.set(.love, active: true, on: article)
        let added = try await entry(.love, on: article, in: service)

        try await service.set(.love, active: false, on: article)
        let removed = try await entry(.love, on: article, in: service)
        try await service.set(.love, active: false, on: article)

        #expect(removed.deleted)
        #expect(removed.updatedAt > added.updatedAt)
        #expect(await service.entries.count == 1)
        #expect(try await entry(.love, on: article, in: service) == removed)
    }

    @Test func reactionsAreKeptAcrossInstances() async throws {
        let directory = temporaryDirectory()
        let first = makeService(in: directory)
        try await first.toggle(.love, on: article)
        try await first.toggle(.fire, on: article)
        try await first.toggle(.fire, on: article)

        let reopened = makeService(in: directory)

        #expect(try await reopened.summary(for: article).mine == [.love])
        #expect(await reopened.entries.count == 2)
    }

    @Test func theReactionsLiveInReactionsJSONInTheGivenDirectory() async throws {
        let directory = temporaryDirectory()

        try await makeService(in: directory).toggle(.love, on: article)

        let file = directory.appending(path: "reactions.json")
        #expect(FileManager.default.fileExists(atPath: file.path))
        let text = try #require(String(bytes: try Data(contentsOf: file), encoding: .utf8))
        #expect(text.contains("\"love\""))
        #expect(!text.contains("❤️"))
    }

    @Test func deletingTheDirectoryResetsTheReactions() async throws {
        let directory = temporaryDirectory()
        try await makeService(in: directory).toggle(.love, on: article)

        try FileManager.default.removeItem(at: directory)

        let fresh = makeService(in: directory)
        #expect(try await fresh.summary(for: article).mine.isEmpty)
        #expect(await fresh.entries.isEmpty)
    }

    @Test func anUnreadableFileIsKeptAsideBeforeTheFirstWrite() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unreadable = Data("{ not json".utf8)
        try unreadable.write(to: directory.appending(path: "reactions.json"))

        let service = makeService(in: directory)
        #expect(try await service.summary(for: article).mine.isEmpty)
        try await service.toggle(.clap, on: article)

        #expect(try Data(contentsOf: directory.appending(path: "reactions.corrupt.json")) == unreadable)
        #expect(try await makeService(in: directory).summary(for: article).mine == [.clap])
    }

    @Test func withoutTheServerThereAreNoCounts() async throws {
        let service = makeService(in: temporaryDirectory())

        let before = try await service.summary(for: article)
        let after = try await service.toggle(.love, on: article)

        #expect(before.counts == nil)
        #expect(after.counts == nil)
        #expect(!before.isDemo)
        #expect(!after.isDemo)
    }

    @Test func theDemoSourceShowsCountsFlaggedAsDemo() async throws {
        let summary = try await makeService(in: temporaryDirectory(), demoCounts: true).summary(for: article)

        let counts = try #require(summary.counts)
        #expect(summary.isDemo)
        #expect(Set(counts.keys) == Set(Reaction.allCases))
        #expect(counts.values.allSatisfy { $0 >= 0 })
    }

    @Test func demoCountsAreStableForAnArticle() async throws {
        let first = try await makeService(in: temporaryDirectory(), demoCounts: true).summary(for: article)
        let second = try await makeService(in: temporaryDirectory(), demoCounts: true).summary(for: article)

        #expect(first.counts != nil)
        #expect(first.counts == second.counts)
    }

    @Test func inTheDemoMyReactionAddsOne() async throws {
        let service = makeService(in: temporaryDirectory(), demoCounts: true)
        let before = try #require(try await service.summary(for: article).counts)

        let reacted = try await service.toggle(.fire, on: article)
        let removed = try await service.toggle(.fire, on: article)

        #expect(reacted.isDemo)
        #expect(reacted.counts?[.fire] == (before[.fire] ?? 0) + 1)
        #expect(reacted.counts?[.love] == before[.love])
        #expect(removed.counts == before)
    }
}

@Suite struct LocalReactionServiceArticleKeyTests {
    @Test(arguments: [
        "https://esprit-festivalier.fr/a-nantes-orelsan-seduit-10675/",
        "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/?utm_source=rss",
        "http://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/",
        "https://www.esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675"
    ])
    func anotherAddressOfTheSameArticleKeepsMyReactions(_ otherAddress: String) async throws {
        let service = makeService(in: temporaryDirectory())
        try await service.toggle(.love, on: try key(articleAddress))

        #expect(try await service.summary(for: try key(otherAddress)).mine == [.love])
    }

    @Test func theReactionIsStoredUnderTheNumberNotTheAddress() async throws {
        let directory = temporaryDirectory()
        let service = makeService(in: directory)

        try await service.toggle(.love, on: try key(articleAddress))

        #expect(await service.entries.map(\.articleId) == [article])
        let text = try String(contentsOf: directory.appending(path: "reactions.json"), encoding: .utf8)
        #expect(text.contains("\"10675\""))
        #expect(!text.contains("orelsan"))
        #expect(!text.contains("esprit-festivalier.fr"))
    }

    @Test(arguments: ["/a-propos/", "1234567890", ""])
    func aKeyTheServerWouldRefuseIsNeverStored(_ rawKey: String) async throws {
        let directory = temporaryDirectory()
        let service = makeService(in: directory)
        let refused = ArticleKey(rawValue: rawKey)

        let summary = try await service.toggle(.love, on: refused)

        #expect(summary.mine.isEmpty)
        #expect(try await service.summary(for: refused).mine.isEmpty)
        #expect(await service.entries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "reactions.json").path))
    }
}
