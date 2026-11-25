import EFDomain
import Foundation

/// Article reads counted anonymously (FR-036, ADR-007): at most one per article per Paris day on this
/// device, queued in `reads.json` until STORY-030 sends them (`POST /v1/events`). No user or device
/// identifier, no time of day. The file keeps 30 Paris days and stays out of the device backup.
/// Asking for consent is the caller's job (NFR-005).
public actor ReadCounter {
    /// A read of the day; `acknowledged` once sent, kept so the same day does not count again.
    struct Entry: Sendable, Codable, Hashable {
        let articleId: Article.ID
        let day: String
        let acknowledged: Bool
    }

    private static let retentionDays = 30
    private let url: URL
    private var file: LocalJSONFile<Entry>
    private var entries: [Entry]
    private let now: @Sendable () -> Date

    /// A missing, empty or unreadable file gives an empty queue; unreadable bytes are copied to
    /// `reads.corrupt.json` before the first write replaces them.
    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        url = directory.appending(path: "reads.json")
        var file = LocalJSONFile<Entry>(url)
        entries = file.read()
        self.file = file
        self.now = now
    }

    /// Reads the file again, after something else changed it (the account deletion erases it).
    public func reload() { entries = file.read() }

    /// What is still to send; reading it changes nothing.
    public var pending: [ArticleReadCount] {
        kept.filter { !$0.acknowledged }.map { ArticleReadCount(articleId: $0.articleId, day: $0.day, count: 1) }
    }

    /// The article screen: only the full text counts (FR-036), the excerpt does not use up the day's read.
    public func articleShown(_ article: Article.ID, fullText: Bool, at date: Date) throws {
        guard fullText else { return }
        try record(article, at: date)
    }

    public func record(_ article: Article.ID, at date: Date) throws {
        let day = Self.parisDay(date)
        let kept = kept
        guard day >= cutoff, !kept.contains(where: { $0.articleId == article && $0.day == day }) else { return }
        try save(kept + [Entry(articleId: article, day: day, acknowledged: false)])
    }

    /// After a successful upload: only these counts leave the queue; their day's read stays used up.
    public func acknowledge(_ counts: [ArticleReadCount]) throws {
        let sent = Set(counts.map { "\($0.articleId)|\($0.day)" })
        let updated = kept.map { entry in
            sent.contains("\(entry.articleId)|\(entry.day)")
                ? Entry(articleId: entry.articleId, day: entry.day, acknowledged: true) : entry
        }
        guard updated != entries else { return }
        try save(updated)
    }

    /// The entries of the last 30 Paris days.
    private var kept: [Entry] { entries.filter { $0.day >= cutoff } }

    private var cutoff: String {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = Self.paris
        let date = now()
        return Self.parisDay(paris.date(byAdding: .day, value: -Self.retentionDays, to: date) ?? date)
    }

    /// An atomic write replaces the file and loses the backup flag: it is set again each time.
    private func save(_ updated: [Entry]) throws {
        try file.write(updated, now: now())
        entries = updated
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var url = url
        try url.setResourceValues(excluded)
    }

    private static let paris = TimeZone(identifier: "Europe/Paris") ?? .current

    private static func parisDay(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: paris).year().month().day())
    }
}
