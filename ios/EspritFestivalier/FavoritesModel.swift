import EFData
import EFDomain
import Foundation
import Observation

/// The favorites every screen reads, so the hearts of the list, the detail, the map and
/// "Mes festivals" stay in sync. The `FavoritesStore` keeps them on disk; each favorite's sheet
/// and image are copied to the `OfflineCache` (STORY-008).
@MainActor @Observable
final class FavoritesModel {
    /// Most recently added first.
    private(set) var ids: [Festival.ID] = []
    /// Favorites whose sheet is stored on the device ("Disponible hors ligne").
    private(set) var offlineIDs: Set<Festival.ID> = []
    /// Short non-blocking message after a failed write; cleared after a few seconds.
    private(set) var saveError: String?
    /// Counts the user's additions (heart, swipe, VoiceOver action): the light haptic's trigger.
    private(set) var additions = 0
    private let store: FavoritesStore
    private let offline: OfflineCache
    private let festivals: any FestivalSource
    /// The last write: each write waits for it, so writes reach the store in tap order.
    private var pending: Task<Void, Never>?
    /// Writes not finished yet, and whether one failed since the queue was last empty.
    private var queued = 0
    private var failedSinceDrain = false
    /// Bumped by each tap on an id: a failed write reverts the heart only if it is still the last tap.
    private var generation: [Festival.ID: Int] = [:]
    private var hideError: Task<Void, Never>?

    init(store: FavoritesStore, offline: OfflineCache, festivals: any FestivalSource) {
        self.store = store
        self.offline = offline
        self.festivals = festivals
    }

    func contains(_ id: Festival.ID) -> Bool { ids.contains(id) }

    func load() async {
        #if DEBUG
        // Debug builds only: `-seedFavorites hellfest,trans-musicales` (simulator runs).
        for id in UserDefaults.standard.string(forKey: "seedFavorites")?.split(separator: ",") ?? [] {
            try? await store.add(String(id))
        }
        #endif
        ids = await store.favoriteIDs
        // Copies left by an interrupted removal go; favorites without a copy get one.
        for stored in await offline.storedFestivals() where !ids.contains(stored.id) {
            try? await offline.remove(stored.id)
        }
        for id in ids { await keepOffline(id, true) }
    }

    /// What "Exporter mes données" writes.
    func entries() async -> [FavoriteEntry] { await store.entries }

    /// After the account deletion erased the files and the offline copies (or failed halfway).
    func reloadAfterErase() async {
        await store.reload()
        ids = await store.favoriteIDs
        var stored = Set<Festival.ID>()
        for id in ids where await offline.isAvailableOffline(id) { stored.insert(id) }
        offlineIDs = stored
    }

    /// The stored image of a favorite, shown instead of the network one.
    func offlineImage(_ id: Festival.ID) async -> Data? { await offline.imageData(id) }

    /// Sets the state the user sees the heart move to, decided at tap time (never flipped on disk).
    func toggle(_ id: Festival.ID) {
        let target = !contains(id)
        if target { additions += 1 }
        apply(id, target)
        let token = (generation[id] ?? 0) + 1
        generation[id] = token
        queued += 1
        let previous = pending
        pending = Task {
            await previous?.value
            do {
                try await store.setFavorite(id, target)
                // Off the write queue: the download must not delay the next heart.
                Task { await keepOffline(id, target) }
            } catch {
                failedSinceDrain = true
                let onDisk = await store.contains(id)
                if generation[id] == token { apply(id, onDisk) }
                show(error: "Impossible d'enregistrer le favori")
            }
            queued -= 1
            await resyncIfDrainedAfterFailure()
        }
    }

    /// A revert reads the disk before the writes still queued, so once they are all done the hearts
    /// are taken again from the store.
    private func resyncIfDrainedAfterFailure() async {
        guard queued == 0, failedSinceDrain else { return }
        let onDisk = await store.favoriteIDs
        // A tap during the read: its own write resyncs when it is done.
        guard queued == 0 else { return }
        failedSinceDrain = false
        ids = onDisk
    }

    /// A newer message restarts the delay: an older timer never hides it.
    private func show(error message: String) {
        saveError = message
        hideError?.cancel()
        hideError = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { saveError = nil }
        }
    }

    /// Saves or removes the offline copy; a failure only leaves the mention off.
    private func keepOffline(_ id: Festival.ID, _ isFavorite: Bool) async {
        if isFavorite, await !offline.isAvailableOffline(id),
           let detail = try? await festivals.festival(id: id) {
            try? await offline.save(detail)
            // Removed while the copy was being made: the removal's own cleanup may have run already.
            if !contains(id) { try? await offline.remove(id) }
        } else if !isFavorite {
            try? await offline.remove(id)
        }
        // The heart may have moved again meanwhile: the mention follows the current state.
        if contains(id), await offline.isAvailableOffline(id) {
            offlineIDs.insert(id)
        } else {
            offlineIDs.remove(id)
        }
    }

    private func apply(_ id: Festival.ID, _ isFavorite: Bool) {
        let others = ids.filter { $0 != id }
        ids = isFavorite ? (contains(id) ? ids : [id] + others) : others
    }
}
