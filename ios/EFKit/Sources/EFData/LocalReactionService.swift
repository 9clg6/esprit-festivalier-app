import EFDomain
import Foundation

/// One reaction of mine on an article. A removed one stays as a tombstone (`deleted`), like a
/// favorite, so a later sync can tell "removed" from "never set".
public struct ReactionEntry: Sendable, Codable, Hashable {
    public let articleId: ArticleKey
    public let reaction: Reaction
    public let updatedAt: Date
    public let deleted: Bool
}

/// Reactions kept on the device in `reactions.json` (ADR-004, ADR-007), until the server (STORY-061).
/// No account needed. Without a server there are no counts; `demoCounts` (source `mock`) makes some up.
public actor LocalReactionService: ReactionService {
    private var file: LocalJSONFile<ReactionEntry>
    private let demoCounts: Bool
    private let now: @Sendable () -> Date
    /// Tombstones included (the export keeps only the live ones).
    public private(set) var entries: [ReactionEntry]

    /// A missing, empty or unreadable file gives no reaction; unreadable bytes are copied to
    /// `reactions.corrupt.json` before the first write replaces them.
    public init(directory: URL, demoCounts: Bool = false, now: @escaping @Sendable () -> Date = { Date() }) {
        var file = LocalJSONFile<ReactionEntry>(directory.appending(path: "reactions.json"))
        entries = file.read()
        self.file = file
        self.demoCounts = demoCounts
        self.now = now
    }

    /// Reads the file again, after something else changed it (the account deletion erases it).
    public func reload() { entries = file.read() }

    /// Forgets the reactions in memory, before the account deletion erases the file: a write that
    /// lands in between cannot put them back.
    public func reset() { entries = [] }

    public func summary(for article: ArticleKey) -> ReactionSummary {
        let mine = Set(entries.filter { $0.articleId == article && !$0.deleted }.map(\.reaction))
        guard demoCounts else { return ReactionSummary(mine: mine, counts: nil, isDemo: false) }
        let counts = Dictionary(uniqueKeysWithValues: Reaction.allCases.enumerated().map { index, reaction in
            (reaction, Self.demoCount(article, index) + (mine.contains(reaction) ? 1 : 0))
        })
        return ReactionSummary(mine: mine, counts: counts, isDemo: true)
    }

    /// Idempotent: the same value twice keeps the entry and its date.
    public func set(_ reaction: Reaction, active: Bool, on article: ArticleKey) throws -> ReactionSummary {
        guard article.isNumbered else { return summary(for: article) }
        let current = entries.first { $0.articleId == article && $0.reaction == reaction }
        let isActive = current.map { !$0.deleted } ?? false
        guard active != isActive, active || current != nil else { return summary(for: article) }
        let updated = ReactionEntry(articleId: article, reaction: reaction, updatedAt: now(), deleted: !active)
        let others = entries.filter { $0.articleId != article || $0.reaction != reaction }
        try file.write(others + [updated], now: now())
        entries = others + [updated]
        return summary(for: article)
    }

    /// The same article always gets the same made-up count (not `Hasher`: it changes every launch).
    private static func demoCount(_ article: ArticleKey, _ index: Int) -> Int {
        let seed = article.rawValue.unicodeScalars.reduce(UInt64(5381)) { $0 &* 33 &+ UInt64($1.value) }
        return Int((seed >> UInt64(index * 7)) % 40)
    }
}
