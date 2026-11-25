import EFData
import EFDomain
import Foundation
import Observation

/// The favorites every screen reads, so the hearts of the list, the detail, the map and
/// "Mes festivals" stay in sync. The `FavoritesStore` keeps them on disk.
@MainActor @Observable
final class FavoritesModel {
    /// Most recently added first.
    private(set) var ids: [Festival.ID] = []
    /// Short non-blocking message after a failed write; cleared after a few seconds.
    private(set) var saveError: String?
    /// Counts the user's additions (heart, swipe, VoiceOver action): the light haptic's trigger.
    private(set) var additions = 0
    private let store: FavoritesStore
    /// The last write: each write waits for it, so writes reach the store in tap order.
    private var pending: Task<Void, Never>?
    /// Writes not finished yet, and whether one failed since the queue was last empty.
    private var queued = 0
    private var failedSinceDrain = false
    /// Bumped by each tap on an id: a failed write reverts the heart only if it is still the last tap.
    private var generation: [Festival.ID: Int] = [:]
    private var hideError: Task<Void, Never>?

    init(store: FavoritesStore) { self.store = store }

    func contains(_ id: Festival.ID) -> Bool { ids.contains(id) }

    func load() async {
        #if DEBUG
        // Debug builds only: `-seedFavorites hellfest,trans-musicales` (simulator runs).
        for id in UserDefaults.standard.string(forKey: "seedFavorites")?.split(separator: ",") ?? [] {
            try? await store.add(String(id))
        }
        #endif
        ids = await store.favoriteIDs
    }

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

    private func apply(_ id: Festival.ID, _ isFavorite: Bool) {
        let others = ids.filter { $0 != id }
        ids = isFavorite ? (contains(id) ? ids : [id] + others) : others
    }
}
