import EFDomain
import Foundation

/// Article reads counted anonymously (FR-036, ADR-007): at most one per article per Paris day on this
/// device, queued in `reads.json` until STORY-030 sends them (`POST /v1/events`). No user or device
/// identifier, no time of day. Asking for consent is the caller's job (NFR-005).
public actor ReadCounter {
    /// A read of the day; `drained` once handed over, kept so the same day does not count again.
    struct Entry: Sendable, Codable, Hashable {
        let articleId: Article.ID
        let day: String
        let drained: Bool
    }

    private var file: LocalJSONFile<Entry>
    private var entries: [Entry]

    /// A missing, empty or unreadable file gives an empty queue; unreadable bytes are copied to
    /// `reads.corrupt.json` before the first write replaces them.
    public init(directory: URL) {
        var file = LocalJSONFile<Entry>(directory.appending(path: "reads.json"))
        entries = file.read()
        self.file = file
    }

    /// Reads the file again, after something else changed it (the account deletion erases it).
    public func reload() { entries = file.read() }

    public var pending: [ArticleReadCount] {
        entries.filter { !$0.drained }.map { ArticleReadCount(articleId: $0.articleId, day: $0.day, count: 1) }
    }

    public func record(_ article: Article.ID, at date: Date) throws {
        let day = Self.parisDay(date)
        guard !entries.contains(where: { $0.articleId == article && $0.day == day }) else { return }
        // ponytail: drained reads of earlier days are only kept for the dedup; a read dated in the past
        // after they go would count again (clocks going back), acceptable for anonymous aggregates.
        let kept = entries.filter { !$0.drained || $0.day >= day }
        try save(kept + [Entry(articleId: article, day: day, drained: false)], now: date)
    }

    /// The pending aggregates, cleared from the queue.
    public func drain() throws -> [ArticleReadCount] {
        let drained = pending
        guard !drained.isEmpty else { return [] }
        try save(entries.map { Entry(articleId: $0.articleId, day: $0.day, drained: true) }, now: Date())
        return drained
    }

    private func save(_ updated: [Entry], now: Date) throws {
        try file.write(updated, now: now)
        entries = updated
    }

    private static func parisDay(_ date: Date) -> String {
        let paris = TimeZone(identifier: "Europe/Paris") ?? .current
        return date.formatted(Date.ISO8601FormatStyle(timeZone: paris).year().month().day())
    }
}
