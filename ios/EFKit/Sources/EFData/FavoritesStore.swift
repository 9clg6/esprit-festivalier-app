import EFDomain
import Foundation

/// One favorite. A removed favorite stays as a tombstone (`deleted`) so a later sync can tell
/// "removed" from "never added"; the most recent `updatedAt` wins.
public struct FavoriteEntry: Sendable, Codable, Hashable {
    public let festivalId: Festival.ID
    public let updatedAt: Date
    public let deleted: Bool
}

/// Favorites kept on the device in `favorites.json` (ADR-004, local first). No account needed.
public actor FavoritesStore {
    private var file: LocalJSONFile<FavoriteEntry>
    private let now: @Sendable () -> Date
    /// Oldest first: a favorite added again moves to the end, so the order survives equal dates.
    public private(set) var entries: [FavoriteEntry]

    /// A missing, empty or unreadable file gives an empty store. Unreadable bytes (corrupt, or a
    /// future schema) are copied to `favorites.corrupt.json` before the first write replaces them.
    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        var file = LocalJSONFile<FavoriteEntry>(directory.appending(path: "favorites.json"))
        entries = file.read()
        self.file = file
        self.now = now
    }

    /// Reads the file again, after something else changed it (the account deletion erases it).
    public func reload() { entries = file.read() }

    /// Live favorites, most recently added first.
    public var favoriteIDs: [Festival.ID] { entries.filter { !$0.deleted }.reversed().map(\.festivalId) }

    public func contains(_ id: Festival.ID) -> Bool { entries.contains { $0.festivalId == id && !$0.deleted } }

    public func add(_ id: Festival.ID) throws {
        guard !contains(id) else { return }
        let added = FavoriteEntry(festivalId: id, updatedAt: now(), deleted: false)
        try save(entries.filter { $0.festivalId != id } + [added])
    }

    public func remove(_ id: Festival.ID) throws {
        guard contains(id) else { return }
        let removed = FavoriteEntry(festivalId: id, updatedAt: now(), deleted: true)
        try save(entries.map { $0.festivalId == id ? removed : $0 })
    }

    /// Sets the wanted state; idempotent (a second call with the same value changes nothing).
    public func setFavorite(_ id: Festival.ID, _ isFavorite: Bool) throws {
        if isFavorite { try add(id) } else { try remove(id) }
    }

    /// Returns the new state: `true` when the festival is now a favorite.
    @discardableResult
    public func toggle(_ id: Festival.ID) throws -> Bool {
        if contains(id) {
            try remove(id)
            return false
        }
        try add(id)
        return true
    }

    /// The new list replaces the old one only once written.
    private func save(_ updated: [FavoriteEntry]) throws {
        try file.write(updated, now: now())
        entries = updated
    }
}
