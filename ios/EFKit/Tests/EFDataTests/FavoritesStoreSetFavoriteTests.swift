import Foundation
import Testing
import EFDomain
import EFData

// Regression specs from the review of PR #15 (STORY-018). Helpers live in FavoritesStoreTests.swift.
//
// Bug 2, inverted intent: the UI knows the state the user wants but called `toggle`, which flips
// the state on disk; with a stale view (load not finished, failed write) the heart did the opposite.
// Contract: `setFavorite(_ id:, _ isFavorite:) throws` sets the wanted state and is idempotent:
// - true on a live favorite changes nothing (same entry, same `updatedAt`, same place);
// - false on a removed favorite keeps the first tombstone; false on an unknown id leaves no entry;
// - two calls with the same value, even concurrent, end in that state with one entry.

@Suite struct FavoritesStoreSetFavoriteTests {
    @Test func settingTrueMakesAFavoriteThatSurvivesAReopen() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)

        try await store.setFavorite("hellfest", true)

        #expect(await store.contains("hellfest"))
        #expect(try await storedEntry("hellfest", in: store).deleted == false)
        #expect(await makeStore(in: directory).favoriteIDs == ["hellfest"])
    }

    @Test func settingTrueTwiceKeepsOneFavorite() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.setFavorite("hellfest", true)
        try await store.setFavorite("hellfest", true)

        #expect(await store.contains("hellfest"))
        #expect(await store.entries.count == 1)
    }

    @Test func settingTrueOnAFavoriteKeepsItsDateAndPlace() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("a")
        try await store.add("b")
        let before = try await storedEntry("a", in: store)

        try await store.setFavorite("a", true)

        #expect(await store.favoriteIDs == ["b", "a"])
        #expect(try await storedEntry("a", in: store) == before)
    }

    @Test func settingFalseLeavesATombstone() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("hellfest")
        let added = try await storedEntry("hellfest", in: store)

        try await store.setFavorite("hellfest", false)

        let removed = try await storedEntry("hellfest", in: store)
        #expect(removed.deleted == true)
        #expect(removed.updatedAt > added.updatedAt)
        #expect(await !makeStore(in: directory).contains("hellfest"))
    }

    @Test func settingFalseTwiceKeepsTheFirstTombstone() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("hellfest")
        try await store.setFavorite("hellfest", false)
        let first = try await storedEntry("hellfest", in: store)

        try await store.setFavorite("hellfest", false)

        #expect(try await storedEntry("hellfest", in: store) == first)
        #expect(await store.entries.count == 1)
    }

    @Test func settingFalseOnANonFavoriteLeavesNoTrace() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.setFavorite("never-added", false)

        #expect(await store.entries.isEmpty)
    }

    @Test func settingTrueAfterRemovalRevivesItFirst() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("a")
        try await store.add("b")
        try await store.remove("a")

        try await store.setFavorite("a", true)

        #expect(await store.favoriteIDs == ["a", "b"])
        #expect(await store.entries.count == 2)
    }

    @Test func twoConcurrentSetsToTrueEndOnAndAgreeOnDisk() async throws {
        // The case `toggle` got wrong: two taps both meaning "favorite" must not cancel out.
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await store.setFavorite("hellfest", true) }
            group.addTask { try await store.setFavorite("hellfest", true) }
            try await group.waitForAll()
        }

        #expect(await store.contains("hellfest"))
        #expect(await store.entries.count == 1)
        #expect(await makeStore(in: directory).contains("hellfest"))
    }
}
