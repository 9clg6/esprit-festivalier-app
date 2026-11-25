import EFDomain
import Foundation

/// An article block with its text already built: one `AttributedString` per paragraph (UX `ArticleBlockView`).
/// The underline of links is a SwiftUI attribute, added by the view.
public struct RenderedBlock: Identifiable, Sendable {
    public enum Kind: Sendable {
        case paragraph(AttributedString)
        case heading(level: Int, AttributedString)
        case image(ArticleImage)
        case quote(AttributedString, source: String?)
        case list(ordered: Bool, items: [AttributedString])
        case embed(Embed)
        case readAlso(ArticleSummary)
        case separator
    }

    /// The position of the block in the article.
    public let id: Int
    public let kind: Kind

    static func make(_ blocks: [ArticleBlock]) -> [RenderedBlock] {
        blocks.enumerated().map { RenderedBlock(id: $0.offset, kind: kind(of: $0.element)) }
    }

    private static func kind(of block: ArticleBlock) -> Kind {
        switch block {
        case .paragraph(let runs): .paragraph(text(runs))
        case .heading(let level, let runs): .heading(level: level, text(runs))
        case .image(let image): .image(image)
        case .quote(let runs, let source): .quote(text(runs), source: source)
        case .list(let ordered, let items): .list(ordered: ordered, items: items.map(text))
        case .embed(let embed): .embed(embed)
        case .readAlso(let summary): .readAlso(summary)
        case .separator: .separator
        }
    }

    /// Bold, italic and links.
    private static func text(_ runs: [InlineRun]) -> AttributedString {
        runs.reduce(into: AttributedString()) { text, run in
            var piece = AttributedString(run.text)
            var intent: InlinePresentationIntent = []
            if run.bold { intent.insert(.stronglyEmphasized) }
            if run.italic { intent.insert(.emphasized) }
            if !intent.isEmpty { piece.inlinePresentationIntent = intent }
            if let link = run.link { piece.link = link }
            text += piece
        }
    }
}
