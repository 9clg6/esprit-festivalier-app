import Foundation
import Testing
import EFDomain
import EFData

// Review of PR #26 (E11, STORY-055, FR-036): the screen built its `AttributedString`s after the state
// had become `.loaded`, so `fullTextDisplayed` (the read counting signal) could be true while nothing
// of the text was on screen yet, and the text was rebuilt by the view. Need: the model builds the
// rendered blocks once, and `.loaded` is set only when they are ready (same main-actor step).
// Assumed API (EFData), moved from the app's ArticleBlockView.swift:
//   public struct RenderedBlock: Identifiable, Sendable {
//     public enum Kind: Sendable {
//       case paragraph(AttributedString), heading(level: Int, AttributedString), image(ArticleImage)
//       case quote(AttributedString, source: String?), list(ordered: Bool, items: [AttributedString])
//       case embed(Embed), readAlso(ArticleSummary), separator
//     }
//     public let id: Int        // position of the block in the article
//     public let kind: Kind
//   }
//   ArticleReaderModel.rendered: [RenderedBlock] { get }   // one per ArticleBlock; empty unless .loaded
// Bold → inlinePresentationIntent .stronglyEmphasized, italic → .emphasized, link → `.link`. The
// underline of links is a SwiftUI attribute: left to the view, not spec'd here.

private let article = Article(
    id: "10675", title: "Orelsan enflamme le Zénith",
    link: URL(string: "https://esprit-festivalier.fr/orelsan-zenith-nantes-10675/")!, category: .liveReport,
    author: "Mano Le Bris", publishedAt: Date(timeIntervalSince1970: 1_794_000_000), imageURL: nil,
    excerpt: "Deux heures de show.")

private let nantes = URL(string: "https://esprit-festivalier.fr/festival/zenith-nantes/")!
private let photo = ArticleImage(
    url: URL(string: "https://esprit-festivalier.fr/media/2026/11/vald.jpg")!, width: 1600, height: 1067, alt: nil,
    caption: "Vald @odieuxboby")

private let blocks: [ArticleBlock] = [
    .paragraph([
        InlineRun(text: "Le "), InlineRun(text: "Zénith", bold: true), InlineRun(text: " de "),
        InlineRun(text: "Nantes", link: nantes), InlineRun(text: " était "), InlineRun(text: "plein", italic: true),
        InlineRun(text: ".")
    ]),
    .heading(level: 3, [InlineRun(text: "Un show millimétré")]),
    .image(photo),
    .list(ordered: false, items: [[InlineRun(text: "Yoroï")], [InlineRun(text: "La fuite en avant")]]),
    .separator
]

private func content(_ blocks: [ArticleBlock]) -> ArticleContent {
    ArticleContent(
        key: ArticleKey(url: article.link), url: article.link, title: article.title, chapo: nil, category: .liveReport,
        author: nil, festival: nil, publishedAt: article.publishedAt, modifiedAt: nil, readingMinutes: 3, cover: nil,
        blocks: blocks, tags: [], related: [], isSponsored: false, parserVersion: 1)
}

/// Answers in order; the last answer repeats.
private actor Answers: ArticleContentSource {
    private var answers: [Result<ArticleContent, any Error>]

    init(_ answers: Result<ArticleContent, any Error>...) { self.answers = answers }

    func content(at url: URL) async throws -> ArticleContent {
        try (answers.count > 1 ? answers.removeFirst() : answers[0]).get()
    }
}

private func kindName(_ kind: RenderedBlock.Kind) -> String {
    switch kind {
    case .paragraph: "paragraph"
    case .heading(let level, _): "h\(level)"
    case .image: "image"
    case .quote: "quote"
    case .list: "list"
    case .embed: "embed"
    case .readAlso: "readAlso"
    case .separator: "separator"
    }
}

@MainActor @Suite struct ArticleReaderRenderingTests {
    @Test func theLoadedArticleComesWithOneRenderedBlockPerBlockInOrder() async {
        let model = ArticleReaderModel(article: article, source: Answers(.success(content(blocks))))

        await model.load()

        #expect(model.state == .loaded(content(blocks)))
        #expect(model.rendered.map { kindName($0.kind) } == ["paragraph", "h3", "image", "list", "separator"])
        #expect(Set(model.rendered.map(\.id)).count == blocks.count, "each block has its own identity")
    }

    @Test func aParagraphIsRenderedWithItsBoldItalicAndLinks() async throws {
        let model = ArticleReaderModel(article: article, source: Answers(.success(content(blocks))))

        await model.load()

        let first = try #require(model.rendered.first)
        guard case .paragraph(let text) = first.kind else {
            Issue.record("first block is \(kindName(first.kind))")
            return
        }
        #expect(String(text.characters) == "Le Zénith de Nantes était plein.")
        let linked = text.runs.filter { $0.link != nil }.map { (String(text[$0.range].characters), $0.link) }
        #expect(linked.count == 1)
        #expect(linked.first?.0 == "Nantes")
        #expect(linked.first?.1 == nantes)
        #expect(text.runs.contains {
            String(text[$0.range].characters) == "Zénith" && $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
        })
        #expect(text.runs.contains {
            String(text[$0.range].characters) == "plein" && $0.inlinePresentationIntent?.contains(.emphasized) == true
        })
    }

    @Test func listItemsAndImagesAreRenderedAsTheyAre() async throws {
        let model = ArticleReaderModel(article: article, source: Answers(.success(content(blocks))))

        await model.load()

        let rendered = model.rendered.map(\.kind)
        try #require(rendered.count == blocks.count)
        guard case .image(let image) = rendered[2], case .list(let ordered, let items) = rendered[3] else {
            Issue.record("blocks are \(rendered.map(kindName))")
            return
        }
        #expect(image == photo)
        #expect(!ordered)
        #expect(items.map { String($0.characters) } == ["Yoroï", "La fuite en avant"])
    }

    @Test func nothingIsRenderedWhileLoadingOrAfterAFailure() async {
        let model = ArticleReaderModel(article: article, source: Answers(.failure(ArticleContentError.unreadable)))

        #expect(model.rendered.isEmpty)

        await model.load()

        #expect(model.state == .failed(.unreadable))
        #expect(model.rendered.isEmpty)
    }

    @Test func aSuccessfulRetryRendersTheArticle() async {
        let source = Answers(.failure(URLError(.notConnectedToInternet)), .success(content(blocks)))
        let model = ArticleReaderModel(article: article, source: source)
        await model.load()

        await model.retry()

        #expect(model.rendered.count == blocks.count)
    }

    // The signal read counting listens to: never before the text can be shown. Watches the model on the
    // main actor while it loads; at the first sight of `.loaded`, the blocks must already be there.
    @Test func theFullTextIsNeverSignalledBeforeItsBlocksAreReady() async {
        let model = ArticleReaderModel(article: article, source: Answers(.success(content(blocks))))
        let loading = Task { await model.load() }

        var seenLoaded = false
        var tries = 0
        while !seenLoaded, tries < 10_000 {
            if model.state != .loading || model.fullTextDisplayed {
                seenLoaded = true
                #expect(model.rendered.count == blocks.count, "loaded while \(model.rendered.count) blocks are rendered")
            }
            tries += 1
            await Task.yield()
        }
        await loading.value

        #expect(seenLoaded)
        #expect(model.fullTextDisplayed)
        #expect(model.rendered.count == blocks.count)
    }
}
