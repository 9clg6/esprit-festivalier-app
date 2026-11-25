import Foundation
import Testing
import EFDomain
import EFData

// STORY-019 "cocher ☆/★" (UX E6): the picked concerts live on the device (architecture: stockage
// local, "concerts cochés" as JSON in Application Support; ADR-004 local first, no account).
// Same shape as FavoritesStore (helpers `temporaryDirectory`, `SteppingClock` in FavoritesStoreTests.swift).
// Assumed API (EFData):
//   struct PickEntry: Codable, Hashable { performanceId: Performance.ID; updatedAt: Date; deleted: Bool }
//   actor PicksStore {
//     init(directory: URL, now: @escaping @Sendable () -> Date = { Date() })
//     var entries: [PickEntry]; var pickedIDs: Set<Performance.ID>
//     func isPicked(_ id: Performance.ID) -> Bool
//     func setPicked(_ id: Performance.ID, _ picked: Bool) throws
//   }
// Decisions specified here:
// - one file, `picks.json`, in the given directory (created if missing); kept across instances;
// - unpicking keeps a tombstone (deleted, later updatedAt); picking again revives it;
// - `setPicked` is idempotent: same value twice changes nothing (same entry, same date);
//   false on a never-picked id leaves no entry;
// - missing or empty file -> empty store; an unreadable non-empty file is kept aside, unchanged,
//   as `picks.corrupt.json` before the first write; a failed write throws.

private func makePicks(in directory: URL, clock: SteppingClock = SteppingClock()) -> PicksStore {
    PicksStore(directory: directory, now: { clock.now() })
}

private func pickEntry(_ id: Performance.ID, in store: PicksStore) async throws -> PickEntry {
    try #require(await store.entries.first { $0.performanceId == id }, "no entry for \(id)")
}

private func requireActor<T: Actor>(_: T) {}

@Suite struct PicksStoreTests {
    @Test func aNewStoreHasNoPick() async {
        let store = makePicks(in: temporaryDirectory())

        #expect(await store.pickedIDs.isEmpty)
        #expect(await !store.isPicked("hellfest-iron-maiden"))
    }

    @Test func theStoreIsAnActor() {
        requireActor(makePicks(in: temporaryDirectory()))
    }

    @Test func aPickedConcertIsPicked() async throws {
        let store = makePicks(in: temporaryDirectory())

        try await store.setPicked("hellfest-iron-maiden", true)

        #expect(await store.isPicked("hellfest-iron-maiden"))
        #expect(await store.pickedIDs == ["hellfest-iron-maiden"])
        #expect(try await pickEntry("hellfest-iron-maiden", in: store).deleted == false)
    }

    @Test func anUnpickedConcertLeavesATombstoneWithALaterDate() async throws {
        let store = makePicks(in: temporaryDirectory())
        try await store.setPicked("iron-maiden", true)
        let picked = try await pickEntry("iron-maiden", in: store)

        try await store.setPicked("iron-maiden", false)

        let unpicked = try await pickEntry("iron-maiden", in: store)
        #expect(await !store.isPicked("iron-maiden"))
        #expect(await store.pickedIDs.isEmpty)
        #expect(unpicked.deleted == true)
        #expect(unpicked.updatedAt > picked.updatedAt)
        #expect(await store.entries.count == 1)
    }

    @Test func pickingAgainRevivesTheEntry() async throws {
        let store = makePicks(in: temporaryDirectory())
        try await store.setPicked("iron-maiden", true)
        try await store.setPicked("iron-maiden", false)
        let tombstone = try await pickEntry("iron-maiden", in: store)

        try await store.setPicked("iron-maiden", true)

        let revived = try await pickEntry("iron-maiden", in: store)
        #expect(revived.deleted == false)
        #expect(revived.updatedAt > tombstone.updatedAt)
        #expect(await store.entries.count == 1)
    }

    @Test func pickingTwiceChangesNothing() async throws {
        let store = makePicks(in: temporaryDirectory())
        try await store.setPicked("iron-maiden", true)
        let first = try await pickEntry("iron-maiden", in: store)

        try await store.setPicked("iron-maiden", true)

        #expect(try await pickEntry("iron-maiden", in: store) == first)
        #expect(await store.entries.count == 1)
    }

    @Test func unpickingTwiceKeepsTheFirstTombstone() async throws {
        let store = makePicks(in: temporaryDirectory())
        try await store.setPicked("iron-maiden", true)
        try await store.setPicked("iron-maiden", false)
        let first = try await pickEntry("iron-maiden", in: store)

        try await store.setPicked("iron-maiden", false)

        #expect(try await pickEntry("iron-maiden", in: store) == first)
    }

    @Test func unpickingANeverPickedConcertLeavesNoTrace() async throws {
        let store = makePicks(in: temporaryDirectory())

        try await store.setPicked("never", false)

        #expect(await store.entries.isEmpty)
    }

    @Test func concurrentPicksAreAllKept() async throws {
        let directory = temporaryDirectory()
        let store = makePicks(in: directory)
        let ids = Set((0..<50).map { "set-\($0)" })

        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask { try await store.setPicked(id, true) }
            }
            try await group.waitForAll()
        }

        #expect(await store.pickedIDs == ids)
        #expect(await makePicks(in: directory).pickedIDs == ids)
    }
}

@Suite struct PicksStorePersistenceTests {
    @Test func picksAndTombstonesSurviveAReopen() async throws {
        let directory = temporaryDirectory()
        let store = makePicks(in: directory)
        try await store.setPicked("kept", true)
        try await store.setPicked("dropped", true)
        try await store.setPicked("dropped", false)
        let saved = await store.entries

        let reopened = makePicks(in: directory)

        #expect(await reopened.pickedIDs == ["kept"])
        #expect(Set(await reopened.entries) == Set(saved))
    }

    @Test func picksAreWrittenToPicksJSONInANewDirectory() async throws {
        let directory = temporaryDirectory().appending(path: "nested/Picks")

        try await makePicks(in: directory).setPicked("kept", true)

        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "picks.json").path))
    }

    @Test func picksDoNotMixWithFavoritesInTheSameDirectory() async throws {
        let directory = temporaryDirectory()
        try await makePicks(in: directory).setPicked("hellfest", true)

        #expect(await FavoritesStore(directory: directory).favoriteIDs.isEmpty)
    }

    @Test func anEmptyFileGivesAnEmptyStore() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: directory.appending(path: "picks.json"))

        let store = makePicks(in: directory)
        #expect(await store.pickedIDs.isEmpty)
        try await store.setPicked("kept", true)

        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "picks.corrupt.json").path))
    }

    @Test func corruptBytesAreKeptAsideAndTheStoreStillWorks() async throws {
        let directory = temporaryDirectory()
        let unreadable = Data("{ not json".utf8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try unreadable.write(to: directory.appending(path: "picks.json"))

        let store = makePicks(in: directory)
        #expect(await store.pickedIDs.isEmpty)
        try await store.setPicked("kept", true)

        #expect(try Data(contentsOf: directory.appending(path: "picks.corrupt.json")) == unreadable)
        #expect(await makePicks(in: directory).pickedIDs == ["kept"])
    }

    @Test func aWriteThatCannotBeSavedThrows() async throws {
        let blocker = temporaryDirectory()
        try Data("x".utf8).write(to: blocker)
        let store = makePicks(in: blocker)

        await #expect(throws: (any Error).self) {
            try await store.setPicked("kept", true)
        }
    }
}
