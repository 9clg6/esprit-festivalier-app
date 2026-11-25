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
    private let file: URL
    private let now: @Sendable () -> Date
    /// Oldest first: a favorite added again moves to the end, so the order survives equal dates.
    public private(set) var entries: [FavoriteEntry]
    /// Bytes of a non-empty file that could not be decoded, kept aside before the first write.
    private var unreadable: Data?

    /// A missing, empty or unreadable file gives an empty store. Unreadable bytes (corrupt, or a
    /// future schema) are copied to `favorites.corrupt.json` before the first write replaces them.
    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        file = directory.appending(path: "favorites.json")
        self.now = now
        let saved = (try? Data(contentsOf: file)) ?? Data()
        let decoded = try? Self.decoder.decode([FavoriteEntry].self, from: saved)
        entries = decoded ?? []
        unreadable = decoded == nil && !saved.isEmpty ? saved : nil
    }

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
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try keepUnreadableAside()
        try Self.encoder.encode(updated).write(to: file, options: .atomic)
        entries = updated
    }

    /// Never overwrites an earlier copy: a second one gets a timestamped name.
    private func keepUnreadableAside() throws {
        guard let unreadable else { return }
        let directory = file.deletingLastPathComponent()
        var copy = directory.appending(path: "favorites.corrupt.json")
        if FileManager.default.fileExists(atPath: copy.path) {
            let format = DateFormatter()
            format.locale = Locale(identifier: "en_US_POSIX")
            format.dateFormat = "yyyyMMdd-HHmmss"
            copy = directory.appending(path: "favorites.corrupt-\(format.string(from: now())).json")
        }
        try unreadable.write(to: copy, options: .withoutOverwriting)
        self.unreadable = nil
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
