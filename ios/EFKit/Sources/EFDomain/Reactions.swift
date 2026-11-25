import Foundation

/// The five positive reactions of an article (FR-030, ADR-007), in the bar's order. The raw value is
/// the key kept on disk and sent to the API; the emoji is only the rendering.
public enum Reaction: String, CaseIterable, Codable, Sendable {
    case love, fire, clap, wow, insight

    public var emoji: String {
        switch self {
        case .love: "❤️"
        case .fire: "🔥"
        case .clap: "👏"
        case .wow: "🤩"
        case .insight: "💡"
        }
    }

    /// What VoiceOver reads: never the emoji's name.
    public var label: String {
        switch self {
        case .love: "J'adore"
        case .fire: "Ça chauffe"
        case .clap: "Bravo"
        case .wow: "Waouh"
        case .insight: "Instructif"
        }
    }
}

/// My reactions on an article and, once known, everyone's counts.
public struct ReactionSummary: Sendable, Equatable {
    public let mine: Set<Reaction>
    /// nil: no counts yet (before the server). Never shown as "0".
    public let counts: [Reaction: Int]?
    /// Demo counts (source `mock`): the screen says so.
    public let isDemo: Bool

    public init(mine: Set<Reaction>, counts: [Reaction: Int]?, isDemo: Bool) {
        self.mine = mine
        self.counts = counts
        self.isDemo = isDemo
    }
}

/// Reactions on articles (FR-030). The device is the truth for "mine"; a server only adds counts.
public protocol ReactionService: Sendable {
    func summary(for article: ArticleKey) async throws -> ReactionSummary
    func set(_ reaction: Reaction, active: Bool, on article: ArticleKey) async throws -> ReactionSummary
}

/// Reads of one article on one Paris day (FR-036): anonymous, no user, device or time of day.
public struct ArticleReadCount: Sendable, Codable, Hashable {
    public let articleId: ArticleKey
    /// "yyyy-MM-dd", Europe/Paris.
    public let day: String
    public let count: Int

    public init(articleId: ArticleKey, day: String, count: Int) {
        self.articleId = articleId
        self.day = day
        self.count = count
    }
}
