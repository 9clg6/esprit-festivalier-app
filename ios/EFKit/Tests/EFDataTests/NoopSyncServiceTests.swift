import Foundation
import Testing
import EFDomain
import EFData

// STORY-022 / STORY-023 mock first: no `GET/PUT /v1/me/sync` yet. The app talks to a `SyncService`
// (NFR-008, swapped later for the API client); until then a no-op one says sync is not available.
// Helpers `temporaryDirectory`, `SteppingClock` in FavoritesStoreTests.swift.
// Assumed API:
//   EFDomain:
//     enum SyncStatus: Sendable, Equatable { case unavailable; case synced(at: Date) }
//     protocol SyncService: Sendable {
//       var lastSyncedAt: Date? { get async }      // nil: "not synced yet"
//       func sync() async throws -> SyncStatus
//     }
//   EFData: struct NoopSyncService: SyncService { init() }
// Decisions specified here:
// - sync() answers `.unavailable` (offline / demo), never `.synced`, and does not throw;
// - lastSyncedAt stays nil, before and after;
// - favorites and picks on the device are left as they are (same entries, same bytes on disk).

@Suite struct NoopSyncServiceTests {
    @Test func theNoopIsASyncService() {
        let service: any SyncService = NoopSyncService()
        _ = service
    }

    @Test func syncSaysItIsNotAvailable() async throws {
        #expect(try await NoopSyncService().sync() == .unavailable)
    }

    @Test func nothingIsEverSynced() async throws {
        let sync = NoopSyncService()
        #expect(await sync.lastSyncedAt == nil)

        _ = try await sync.sync()

        #expect(await sync.lastSyncedAt == nil)
    }

    @Test func syncLeavesTheLocalDataAsItIs() async throws {
        let directory = temporaryDirectory()
        let clock = SteppingClock()
        let favorites = FavoritesStore(directory: directory, now: { clock.now() })
        try await favorites.add("hellfest")
        try await favorites.add("removed")
        try await favorites.remove("removed")
        try await PicksStore(directory: directory, now: { clock.now() }).setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        let favoriteEntries = await favorites.entries
        let favoriteBytes = try Data(contentsOf: directory.appending(path: "favorites.json"))
        let pickBytes = try Data(contentsOf: directory.appending(path: "picks.json"))

        _ = try await NoopSyncService().sync()

        #expect(await FavoritesStore(directory: directory).entries == favoriteEntries)
        #expect(try Data(contentsOf: directory.appending(path: "favorites.json")) == favoriteBytes)
        #expect(try Data(contentsOf: directory.appending(path: "picks.json")) == pickBytes)
    }
}
