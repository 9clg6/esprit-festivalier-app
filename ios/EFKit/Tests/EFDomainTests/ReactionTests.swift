import Foundation
import Testing
import EFDomain

// STORY-058 / FR-030 "Réactions aux articles" (architecture ADR-007 §3, decision 2026-11-25):
// 5 fixed positive reactions, ❤️ J'adore, 🔥 Ça chauffe, 👏 Bravo, 🤩 Waouh, 💡 Instructif.
// Neutral keys (`love`, `fire`, `clap`, `wow`, `insight`) for storage and the future API
// (D1 `CHECK (reaction IN ('love','fire','clap','wow','insight'))`): the emoji is only the rendering.
// VoiceOver reads the label, never the emoji name, so the label carries no emoji.
// Assumed API (EFDomain):
//   enum Reaction: String, CaseIterable, Codable, Sendable { case love, fire, clap, wow, insight
//     var emoji: String; var label: String }
//   struct ReactionSummary: Sendable, Equatable {
//     init(mine: Set<Reaction>, counts: [Reaction: Int]?, isDemo: Bool)
//     let mine: Set<Reaction>; let counts: [Reaction: Int]?  // nil: no counts yet (beta)
//     let isDemo: Bool                                        // demo counts ("Données de démonstration")
//   }
//   protocol ReactionService: Sendable {
//     func summary(for article: ArticleKey) async throws -> ReactionSummary
//     func set(_ reaction: Reaction, active: Bool, on article: ArticleKey) async throws -> ReactionSummary
//   }
//   + `toggle(_:on:) async throws -> ReactionSummary` usable on `any ReactionService`
//     (requirement or extension): tapping a pill toggles it.
// Keyed by `ArticleKey` (the number of `/<slug>-<number>/`, ADR-007), not by the article's URL.

@Suite struct ReactionTests {
    @Test func thereAreFiveReactionsInTheBarOrder() {
        #expect(Reaction.allCases == [.love, .fire, .clap, .wow, .insight])
    }

    @Test func eachReactionHasItsEmojiAndFrenchLabel() {
        let shown = Reaction.allCases.map { "\($0.emoji) \($0.label)" }

        #expect(shown == ["❤️ J'adore", "🔥 Ça chauffe", "👏 Bravo", "🤩 Waouh", "💡 Instructif"])
    }

    @Test func rawValuesAreStableForStorageAndTheAPI() {
        #expect(Reaction.allCases.map(\.rawValue) == ["love", "fire", "clap", "wow", "insight"])
        #expect(Reaction(rawValue: "fire") == .fire)
        #expect(Reaction(rawValue: "angry") == nil)
    }

    @Test func aReactionIsEncodedByItsKeyNotItsEmoji() throws {
        let json = try JSONEncoder().encode([Reaction.love, .insight])

        #expect(String(bytes: json, encoding: .utf8) == #"["love","insight"]"#)
        #expect(try JSONDecoder().decode([Reaction].self, from: json) == [.love, .insight])
    }

    @Test func theLabelVoiceOverReadsHasNoEmoji() {
        for reaction in Reaction.allCases {
            #expect(!reaction.label.contains(reaction.emoji))
            #expect(!reaction.label.unicodeScalars.contains { $0.properties.isEmojiPresentation })
            #expect(reaction.label.trimmingCharacters(in: .whitespaces) == reaction.label)
            #expect(!reaction.label.isEmpty)
        }
    }

    @Test func aSummaryKeepsMineCountsAndTheDemoFlag() {
        let summary = ReactionSummary(mine: [.love], counts: [.love: 12, .fire: 3], isDemo: true)

        #expect(summary.mine == [.love])
        #expect(summary.counts == [.love: 12, .fire: 3])
        #expect(summary.isDemo)
        #expect(summary != ReactionSummary(mine: [.love], counts: nil, isDemo: false))
    }
}

/// Another module must be able to implement the service and a caller use it through the protocol.
private actor OneArticleReactions: ReactionService {
    private var mine: Set<Reaction> = []

    func summary(for article: ArticleKey) async throws -> ReactionSummary {
        ReactionSummary(mine: mine, counts: nil, isDemo: false)
    }

    func set(_ reaction: Reaction, active: Bool, on article: ArticleKey) async throws -> ReactionSummary {
        if active { mine.insert(reaction) } else { mine.remove(reaction) }
        return try await summary(for: article)
    }
}

@Test func aReactionServiceCanBeUsedThroughItsProtocolAndToggles() async throws {
    let service: any ReactionService = OneArticleReactions()

    let article = ArticleKey(rawValue: "10675")

    #expect(try await service.summary(for: article).mine.isEmpty)
    #expect(try await service.toggle(.fire, on: article).mine == [.fire])
    #expect(try await service.toggle(.fire, on: article).mine.isEmpty)
}
