import Foundation
import Testing
import EFDomain
import EFData

// STORY-018 "Favoris stockés sur l'appareil, sans compte" (architecture: stockage local,
// JSON Codable in Application Support; ADR-004 local first). Shape kept for STORY-023:
// every entry carries `updatedAt` and `deleted`, the most recent wins.
// Decisions specified here:
// - `FavoritesStore` is an `actor`; mutations `throw` when the file cannot be written;
// - one file, `favorites.json`, in the directory given at init (created if missing);
// - missing or unreadable file -> empty store, no crash; the next write replaces it;
// - `favoriteIDs`: live favorites, most recently added first, stable even when the clock
//   gives the same time twice, and kept across instances;
// - add on a live favorite and remove on a non-favorite do nothing (no new date, no tombstone);
// - remove keeps a tombstone (deleted = true, later updatedAt); add again revives it (deleted = false,
//   later updatedAt) and puts it first;
// - `toggle` returns the new state (true = now a favorite).

/// A clock that moves one second per reading, from a whole second (JSON round trip safe).
private final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_795_000_000)
    private let step: TimeInterval

    init(step: TimeInterval = 1) { self.step = step }

    func now() -> Date {
        lock.withLock {
            current += step
            return current
        }
    }
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "FavoritesStoreTests-\(UUID().uuidString)")
}

private func makeStore(in directory: URL, clock: SteppingClock = SteppingClock()) -> FavoritesStore {
    FavoritesStore(directory: directory, now: { clock.now() })
}

private func storedEntry(_ id: Festival.ID, in store: FavoritesStore) async throws -> FavoriteEntry {
    try #require(await store.entries.first { $0.festivalId == id }, "no entry for \(id)")
}

private func requireActor<T: Actor>(_: T) {}

@Suite struct FavoritesStoreBasicsTests {
    @Test func aNewStoreHasNoFavorite() async {
        let store = makeStore(in: temporaryDirectory())

        #expect(await store.favoriteIDs.isEmpty)
        #expect(await store.entries.isEmpty)
        #expect(await !store.contains("hellfest"))
    }

    @Test func anAddedFestivalIsAFavorite() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.add("hellfest")

        #expect(await store.contains("hellfest"))
        #expect(await store.favoriteIDs == ["hellfest"])
        #expect(await !store.contains("trans-musicales"))
    }

    @Test func aRemovedFestivalIsNoLongerAFavorite() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("hellfest")
        try await store.add("trans-musicales")

        try await store.remove("hellfest")

        #expect(await !store.contains("hellfest"))
        #expect(await store.favoriteIDs == ["trans-musicales"])
    }

    @Test func toggleAddsThenRemovesAndReturnsTheNewState() async throws {
        let store = makeStore(in: temporaryDirectory())

        let first = try await store.toggle("hellfest")
        #expect(first == true)
        #expect(await store.contains("hellfest"))

        let second = try await store.toggle("hellfest")
        #expect(second == false)
        #expect(await !store.contains("hellfest"))
    }

    @Test func theStoreIsAnActor() {
        requireActor(makeStore(in: temporaryDirectory()))
    }
}

@Suite struct FavoritesStoreOrderTests {
    @Test func mostRecentlyAddedComesFirst() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.add("a")
        try await store.add("b")
        try await store.add("c")

        #expect(await store.favoriteIDs == ["c", "b", "a"])
    }

    @Test func orderIsStableWhenTheClockDoesNotMove() async throws {
        let directory = temporaryDirectory()
        let frozen = SteppingClock(step: 0)
        let store = makeStore(in: directory, clock: frozen)

        try await store.add("a")
        try await store.add("b")
        try await store.add("c")

        #expect(await store.favoriteIDs == ["c", "b", "a"])
        #expect(await makeStore(in: directory, clock: frozen).favoriteIDs == ["c", "b", "a"])
    }

    @Test func addingAFavoriteAgainDoesNotMoveIt() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("a")
        try await store.add("b")
        let before = try await storedEntry("a", in: store)

        try await store.add("a")

        #expect(await store.favoriteIDs == ["b", "a"])
        #expect(try await storedEntry("a", in: store) == before)
    }

    @Test func aFestivalAddedAgainAfterRemovalComesFirst() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("a")
        try await store.add("b")
        try await store.remove("a")

        try await store.add("a")

        #expect(await store.favoriteIDs == ["a", "b"])
    }
}

@Suite struct FavoritesStoreTombstoneTests {
    @Test func anAddedFavoriteHasALiveEntry() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.add("hellfest")

        let added = try await storedEntry("hellfest", in: store)
        #expect(added.deleted == false)
    }

    @Test func removingKeepsATombstoneWithALaterDate() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("hellfest")
        let added = try await storedEntry("hellfest", in: store)

        try await store.remove("hellfest")

        let removed = try await storedEntry("hellfest", in: store)
        #expect(removed.deleted == true)
        #expect(removed.updatedAt > added.updatedAt)
        #expect(await store.entries.count == 1)
        #expect(await !store.favoriteIDs.contains("hellfest"))
    }

    @Test func addingAgainClearsTheTombstoneWithALaterDate() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("hellfest")
        try await store.remove("hellfest")
        let removed = try await storedEntry("hellfest", in: store)

        try await store.add("hellfest")

        let revived = try await storedEntry("hellfest", in: store)
        #expect(revived.deleted == false)
        #expect(revived.updatedAt > removed.updatedAt)
        #expect(await store.entries.count == 1)
        #expect(await store.contains("hellfest"))
    }

    @Test func toggleOffAlsoLeavesATombstone() async throws {
        let store = makeStore(in: temporaryDirectory())
        _ = try await store.toggle("hellfest")

        _ = try await store.toggle("hellfest")

        #expect(try await storedEntry("hellfest", in: store).deleted == true)
    }

    @Test func removingANonFavoriteLeavesNoTrace() async throws {
        let store = makeStore(in: temporaryDirectory())

        try await store.remove("never-added")

        #expect(await store.entries.isEmpty)
    }

    @Test func removingTwiceKeepsTheFirstTombstoneDate() async throws {
        let store = makeStore(in: temporaryDirectory())
        try await store.add("hellfest")
        try await store.remove("hellfest")
        let first = try await storedEntry("hellfest", in: store)

        try await store.remove("hellfest")

        #expect(try await storedEntry("hellfest", in: store) == first)
    }
}

@Suite struct FavoritesStorePersistenceTests {
    @Test func aNewStoreOnTheSameDirectorySeesTheFavorites() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("a")
        try await store.add("b")

        let reopened = makeStore(in: directory)

        #expect(await reopened.favoriteIDs == ["b", "a"])
        #expect(await reopened.contains("a"))
    }

    @Test func tombstonesAndDatesSurviveAReopen() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        try await store.add("a")
        try await store.add("b")
        try await store.remove("a")
        let saved = await store.entries

        let reopened = makeStore(in: directory)

        #expect(Set(await reopened.entries) == Set(saved))
        #expect(await reopened.favoriteIDs == ["b"])
    }

    @Test func aStoreOnAnotherDirectoryIsIndependent() async throws {
        try await makeStore(in: temporaryDirectory()).add("a")

        #expect(await makeStore(in: temporaryDirectory()).favoriteIDs.isEmpty)
    }

    @Test func aMissingDirectoryIsCreatedOnFirstWrite() async throws {
        let directory = temporaryDirectory().appending(path: "nested/Favorites")
        let store = makeStore(in: directory)
        #expect(await store.favoriteIDs.isEmpty)

        try await store.add("a")

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "favorites.json").path))
        #expect(await makeStore(in: directory).favoriteIDs == ["a"])
    }

    @Test func aCorruptFileGivesAnEmptyStoreThatStillWorks() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: directory.appending(path: "favorites.json"))

        let store = makeStore(in: directory)
        #expect(await store.favoriteIDs.isEmpty)
        #expect(await store.entries.isEmpty)

        try await store.add("a")
        #expect(await makeStore(in: directory).favoriteIDs == ["a"])
    }

    @Test func anEmptyFileGivesAnEmptyStore() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appending(path: "favorites.json"))

        #expect(await makeStore(in: directory).favoriteIDs.isEmpty)
    }

    @Test func aWriteThatCannotBeSavedThrows() async throws {
        // The "directory" is a regular file: nothing can be saved under it.
        let blocker = temporaryDirectory()
        try Data("x".utf8).write(to: blocker)
        let store = makeStore(in: blocker)

        await #expect(throws: (any Error).self) {
            try await store.add("a")
        }
    }
}

@Suite struct FavoritesStoreConcurrencyTests {
    @Test func manyConcurrentAddsAreAllKept() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)
        let ids = (0..<100).map { "festival-\($0)" }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { try await store.add(id) }
            }
            try await group.waitForAll()
        }

        #expect(Set(await store.favoriteIDs) == Set(ids))
        #expect(await store.favoriteIDs.count == ids.count)
        #expect(Set(await makeStore(in: directory).favoriteIDs) == Set(ids))
    }

    @Test func twoConcurrentTogglesEndOffAndAgreeOnDisk() async throws {
        let directory = temporaryDirectory()
        let store = makeStore(in: directory)

        let results = try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask { try await store.toggle("hellfest") }
            group.addTask { try await store.toggle("hellfest") }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        #expect(results.sorted { !$0 && $1 } == [false, true])
        #expect(await !store.contains("hellfest"))
        #expect(await store.entries.count == 1)
        let reopened = makeStore(in: directory)
        #expect(await !reopened.contains("hellfest"))
        #expect(try await storedEntry("hellfest", in: reopened).deleted == true)
    }
}
