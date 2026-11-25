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
    private let store: FavoritesStore

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

    func toggle(_ id: Festival.ID) {
        // Instant feedback; the store has the last word (a failed write puts the heart back).
        ids = contains(id) ? ids.filter { $0 != id } : [id] + ids
        Task {
            _ = try? await store.toggle(id)
            ids = await store.favoriteIDs
        }
    }
}
