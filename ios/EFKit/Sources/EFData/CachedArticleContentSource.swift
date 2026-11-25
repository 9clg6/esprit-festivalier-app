import EFDomain
import Foundation

/// Keeps one JSON copy per article on disk (ADR-007 "Cache hors ligne", NFR-002). A copy younger than
/// `maxAge` and of the current parser version is returned as is; otherwise the source is asked, and if
/// it fails the copy is returned. Without a copy, the source's error reaches the caller unchanged.
/// At most `limit` copies: storing one more removes the one stored longest ago.
public actor CachedArticleContentSource: ArticleContentSource {
    private let source: any ArticleContentSource
    private let directory: URL
    private let parserVersion: Int
    private let maxAge: TimeInterval
    private let limit: Int
    private let now: @Sendable () -> Date

    public init(
        wrapping source: any ArticleContentSource, directory: URL, parserVersion: Int = SiteTemplate.v1.parserVersion,
        maxAge: TimeInterval = 3600, limit: Int = 100, now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.source = source
        self.directory = directory
        self.parserVersion = parserVersion
        self.maxAge = maxAge
        self.limit = limit
        self.now = now
    }

    public func content(at url: URL) async throws -> ArticleContent {
        let file = directory.appending(path: Self.fileName(ArticleKey(url: url)))
        let copy = Self.copy(at: file)
        if let copy, copy.content.parserVersion == parserVersion, now().timeIntervalSince(copy.storedAt) < maxAge {
            return copy.content
        }
        do {
            let fresh = try await source.content(at: url)
            store(fresh, at: file)
            return fresh
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let copy else { throw error }
            return copy.content
        }
    }

    // ponytail: the file's modification date is the time of storage (set from `now`), no index file.
    private static func copy(at file: URL) -> (content: ArticleContent, storedAt: Date)? {
        guard let data = try? Data(contentsOf: file),
              let content = try? JSONDecoder().decode(ArticleContent.self, from: data),
              let storedAt = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        else { return nil }
        return (content, storedAt)
    }

    /// A failed write only costs the offline copy.
    private func store(_ content: ArticleContent, at file: URL) {
        let manager = FileManager.default
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(content), (try? data.write(to: file, options: .atomic)) != nil
        else { return }
        try? manager.setAttributes([.modificationDate: now()], ofItemAtPath: file.path(percentEncoded: false))
        evictOldest()
    }

    private func evictOldest() {
        let key = URLResourceKey.contentModificationDateKey
        let copies = ((try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [key])) ?? []).filter { $0.pathExtension == "json" }
        guard copies.count > limit else { return }
        func storedAt(_ file: URL) -> Date {
            (try? file.resourceValues(forKeys: [key]).contentModificationDate) ?? .distantPast
        }
        let byAge = copies.map { ($0, storedAt($0)) }.sorted { $0.1 < $1.1 }
        for (file, _) in byAge.prefix(copies.count - limit) { try? FileManager.default.removeItem(at: file) }
    }

    /// The key is a number, or a path for an address without one.
    private static func fileName(_ key: ArticleKey) -> String {
        key.rawValue.replacingOccurrences(of: "/", with: "_") + ".json"
    }
}
