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
    private let store: FavoritesStore
    /// The last write: each write waits for it, so writes reach the store in tap order.
    private var pending: Task<Void, Never>?
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
        apply(id, target)
        let previous = pending
        pending = Task {
            await previous?.value
            do {
                try await store.setFavorite(id, target)
            } catch {
                apply(id, await store.contains(id))
                show(error: "Impossible d'enregistrer le favori")
            }
        }
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
