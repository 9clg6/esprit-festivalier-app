import EFDomain
import Foundation

/// Favorite festival sheets and their image, kept in Application Support (not Caches, which the
/// system may empty) so they open offline (NFR-003).
public actor OfflineCache {
    private let directory: URL
    private let fetchImage: @Sendable (URL) async throws -> Data

    public init(directory: URL, fetchImage: @escaping @Sendable (URL) async throws -> Data) {
        self.directory = directory
        self.fetchImage = fetchImage
    }

    /// Stores the sheet and the bytes of its image. An image that cannot be fetched is skipped and
    /// never replaces the one already stored.
    public func save(_ detail: FestivalDetail) async throws {
        let id = detail.festival.id
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // A copy of public data: it can be downloaded again, so it stays out of iCloud backups.
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var folder = directory
        try folder.setResourceValues(excluded)
        try Self.encoder.encode(detail).write(to: sheetFile(id), options: .atomic)
        guard let url = detail.festival.imageURL else {
            try? FileManager.default.removeItem(at: imageFile(id))
            return
        }
        guard let bytes = try? await fetchImage(url) else { return }
        try bytes.write(to: imageFile(id), options: .atomic)
    }

    public func remove(_ id: Festival.ID) throws {
        for file in [sheetFile(id), imageFile(id)] where FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
    }

    public func detail(_ id: Festival.ID) -> FestivalDetail? {
        (try? Data(contentsOf: sheetFile(id))).flatMap { try? Self.decoder.decode(FestivalDetail.self, from: $0) }
    }

    public func imageData(_ id: Festival.ID) -> Data? { try? Data(contentsOf: imageFile(id)) }

    public func isAvailableOffline(_ id: Festival.ID) -> Bool { detail(id) != nil }

    /// The source's answer (refreshing the stored copy of a saved festival), or the stored copy when
    /// the source fails. A festival never saved is not stored by reading it.
    public func festival(id: Festival.ID, from source: any FestivalSource) async throws -> FestivalDetail {
        do {
            let fresh = try await source.festival(id: id)
            if let stored = detail(id), stored != fresh {
                if stored.festival.imageURL == fresh.festival.imageURL {
                    try? Self.encoder.encode(fresh).write(to: sheetFile(id), options: .atomic)
                } else {
                    try? await save(fresh)
                }
            }
            return fresh
        } catch {
            guard let stored = detail(id) else { throw error }
            return stored
        }
    }

    private func sheetFile(_ id: Festival.ID) -> URL { directory.appending(path: "\(id).json") }
    private func imageFile(_ id: Festival.ID) -> URL { directory.appending(path: "\(id).image") }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
