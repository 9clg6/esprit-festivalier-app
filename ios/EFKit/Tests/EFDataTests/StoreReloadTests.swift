import Foundation
import Testing
import EFDomain
import EFData

// Review of PR #20: `reload()` on FavoritesStore and PicksStore (added without specs). Need: after
// something else changes the file (the account deletion erases it, another instance writes it),
// `reload()` makes the store show what is on disk. A missing file reloads as empty, no error.
// Helpers `temporaryDirectory`, `makeStore` in FavoritesStoreTests.swift.

private func erase(_ name: String, in directory: URL) throws {
    try FileManager.default.removeItem(at: directory.appending(path: name))
}

@Suite struct FavoritesStoreReloadTests {
    @Test func favoritesAreGoneAfterTheFileIsErased() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("hellfest")
        try erase("favorites.json", in: directory)

        await store.reload()

        #expect(await store.favoriteIDs.isEmpty)
        #expect(await store.entries.isEmpty, "no tombstone either")
    }

    @Test func anErasedFavoriteDoesNotComeBackWithTheNextAdd() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("hellfest")
        try erase("favorites.json", in: directory)
        await store.reload()

        try await store.add("vieilles-charrues")

        #expect(await makeStore(in: directory).favoriteIDs == ["vieilles-charrues"])
    }

    @Test func aFavoriteAddedByAnotherInstanceShowsAfterReload() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("hellfest")
        try await makeStore(in: directory).add("vieilles-charrues")

        await store.reload()

        #expect(await store.favoriteIDs == ["vieilles-charrues", "hellfest"])
    }

    @Test func reloadingAMissingFileGivesAnEmptyStore() async throws {
        let store = makeStore(in: temporaryDirectory().appending(path: "never-created"))

        await store.reload()

        #expect(await store.entries.isEmpty)
    }
}

@Suite struct PicksStoreReloadTests {
    private func makePicks(in directory: URL) -> PicksStore {
        let clock = SteppingClock()
        return PicksStore(directory: directory, now: { clock.now() })
    }

    @Test func picksAreGoneAfterTheFileIsErased() async throws {
        let directory = temporaryDirectory()
        let store = makePicks(in: directory)
        try await store.setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        try erase("picks.json", in: directory)

        await store.reload()

        #expect(await store.pickedIDs.isEmpty)
        #expect(await store.entries.isEmpty, "no tombstone either")
    }

    @Test func anErasedPickDoesNotComeBackWithTheNextPick() async throws {
        let directory = temporaryDirectory()
        let store = makePicks(in: directory)
        try await store.setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        try erase("picks.json", in: directory)
        await store.reload()

        try await store.setPicked("hellfest-gojira", true, festivalId: "hellfest")

        #expect(await makePicks(in: directory).pickedIDs == ["hellfest-gojira"])
    }

    @Test func aPickMadeByAnotherInstanceShowsAfterReload() async throws {
        let directory = temporaryDirectory()
        let store = makePicks(in: directory)
        try await store.setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        try await makePicks(in: directory).setPicked("hellfest-gojira", true, festivalId: "hellfest")

        await store.reload()

        #expect(await store.pickedIDs == ["hellfest-iron-maiden", "hellfest-gojira"])
    }

    @Test func reloadingAMissingFileGivesAnEmptyStore() async throws {
        let store = makePicks(in: temporaryDirectory().appending(path: "never-created"))

        await store.reload()

        #expect(await store.entries.isEmpty)
    }
}

@Suite struct LocalReactionServiceReloadTests {
    private let article = ArticleKey(rawValue: "10675")

    private func makeService(in directory: URL) -> LocalReactionService {
        let clock = SteppingClock()
        return LocalReactionService(directory: directory, now: { clock.now() })
    }

    @Test func reactionsAreGoneAfterTheFileIsErased() async throws {
        let directory = temporaryDirectory()
        let service = makeService(in: directory)
        _ = try await service.set(.love, active: true, on: article)
        try erase("reactions.json", in: directory)

        await service.reload()

        #expect(try await service.summary(for: article).mine.isEmpty)
        #expect(await service.entries.isEmpty, "no tombstone either")
    }

    @Test func anErasedReactionDoesNotComeBackWithTheNextOne() async throws {
        let directory = temporaryDirectory()
        let service = makeService(in: directory)
        _ = try await service.set(.love, active: true, on: article)
        try erase("reactions.json", in: directory)
        await service.reload()

        _ = try await service.set(.fire, active: true, on: article)

        #expect(try await makeService(in: directory).summary(for: article).mine == [.fire])
    }

    @Test func reloadingAMissingFileGivesAnEmptyService() async throws {
        let service = makeService(in: temporaryDirectory().appending(path: "never-created"))

        await service.reload()

        #expect(await service.entries.isEmpty)
    }
}

private func key(_ rawValue: String) -> ArticleKey { ArticleKey(rawValue: rawValue) }

private let noon = try! Date("2026-11-25T11:00:00Z", strategy: .iso8601)

/// The clock stays on the day of the reads, so they never age past the 30-day limit.
private func makeCounter(in directory: URL) -> ReadCounter { ReadCounter(directory: directory, now: { noon }) }

@Suite struct ReadCounterReloadTests {

    @Test func readsAreGoneAfterTheFileIsErased() async throws {
        let directory = temporaryDirectory()
        let counter = makeCounter(in: directory)
        try await counter.record(key("10675"), at: noon)
        try erase("reads.json", in: directory)

        await counter.reload()

        #expect(await counter.pending.isEmpty)
    }

    @Test func anErasedReadDoesNotComeBackWithTheNextOne() async throws {
        let directory = temporaryDirectory()
        let counter = makeCounter(in: directory)
        try await counter.record(key("10675"), at: noon)
        try erase("reads.json", in: directory)
        await counter.reload()

        try await counter.record(key("10672"), at: noon)

        #expect(await makeCounter(in: directory).pending.map(\.articleId.rawValue) == ["10672"])
    }

    @Test func anUnreadableFileIsKeptAsideAndCountingContinues() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unreadable = Data("{ not json".utf8)
        try unreadable.write(to: directory.appending(path: "reads.json"))

        let counter = makeCounter(in: directory)
        #expect(await counter.pending.isEmpty)
        try await counter.record(key("10675"), at: noon)

        #expect(try Data(contentsOf: directory.appending(path: "reads.corrupt.json")) == unreadable)
        #expect(await makeCounter(in: directory).pending.map(\.articleId.rawValue) == ["10675"])
    }
}
