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
