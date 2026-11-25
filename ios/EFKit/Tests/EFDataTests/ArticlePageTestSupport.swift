import Foundation
import Testing
import EFDomain
import EFData

// Shared by the "page du site" specs (STORY-053, STORY-054, ADR-007).
// Fixtures (Tests/EFDataTests/Fixtures), fetched from https://esprit-festivalier.fr on 2026-11-25 and
// trimmed to the NewsArticle (or ProfilePage) JSON-LD plus `main#contenu`:
// - article-10675-orelsan-nantes.html: live report; bold-only paragraphs used as headings, bold
//   italic quotes, YouTube links, link to /artiste/, « Lire aussi », initials avatar, cover credit;
// - article-10672-terres-du-son-2027.html: programmation; h3 with id, bold-only headings holding a
//   link, a.festival-tag, link to /festival/, absolute internal article link, a bare <img>, figures
//   with photo credits, empty <p></p>, photo avatar, a festival card among the related ones;
// - article-10556-festivals-politiques.html: décryptage; h2 headings, figures with credits;
// - author-mano-le-bris.html: an author page (no article body);
// - article-synthetic-blocks.html: hand-written on the same template for what no article of the
//   feed had (no JSON-LD, sponsored mark, h2/h4, quote, lists, embeds, separator).

enum ArticlePage {
    static let orelsan = URL(string: "https://esprit-festivalier.fr/je-le-connais-de-nom-mais-j-ai-jamais-ecoute-a-nantes-orelsan-seduit-meme-les-novices-10675/")!
    static let terresDuSon = URL(string: "https://esprit-festivalier.fr/terres-du-son-2027-orelsan-vald-et-christophe-mae-en-tetes-d-affiche-10672/")!
    static let politiques = URL(string: "https://esprit-festivalier.fr/les-festivals-peuvent-ils-encore-etre-politiques-10556/")!
    static let author = URL(string: "https://esprit-festivalier.fr/author/mano-le-bris/")!
    static let synthetic = URL(string: "https://esprit-festivalier.fr/hellfest-2027-le-guide-de-survie-99001/")!

    static func fixture(_ name: String) throws -> Data {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name)")
        return try Data(contentsOf: url)
    }

    static func orelsanPage() throws -> Data { try fixture("article-10675-orelsan-nantes.html") }
    static func terresDuSonPage() throws -> Data { try fixture("article-10672-terres-du-son-2027.html") }
    static func politiquesPage() throws -> Data { try fixture("article-10556-festivals-politiques.html") }
    static func authorPage() throws -> Data { try fixture("author-mano-le-bris.html") }
    static func syntheticPage() throws -> Data { try fixture("article-synthetic-blocks.html") }

    static let defaultHead = """
        <a class="cat" href="/category/actu/">Actu</a>
        <h1 class="article-title">Un titre</h1>
        <p class="article-chapo">Un chapô.</p>
        <div class="byline"><div class="dates">Par <a href="/author/chloe-magron/">Chloé Magron</a> · Actu<br>\
        Publié le <time datetime="2026-11-20T10:00:00.000Z">20 novembre 2026</time> · 2 min de lecture</div></div>
        """

    /// A page on the site's template (SiteTemplate.v1) around the given article body.
    static func page(jsonLD: String? = nil, head: String = defaultHead, body: String) -> Data {
        let script = jsonLD.map { "<script type=\"application/ld+json\">\($0)</script>" } ?? ""
        return Data("""
            <!doctype html><html lang="fr"><head><title>Esprit Festivalier</title>\(script)</head><body>
            <nav class="menu"><a href="/category/reports/">Live reports</a></nav>
            <main id="contenu"><div class="wrap article-layout"><div class="article-main"><article>
            <header class="article-head">\(head)</header>
            <div class="article-body">\(body)</div><div class="read-end" aria-hidden="true"></div>
            <aside class="author-box"><div><h2><a href="/author/chloe-magron/">Chloé Magron</a></h2>\
            <p>Rédactrice bénévole</p></div></aside>
            </article></div></div></main>
            <footer><p>© Esprit Festivalier</p></footer></body></html>
            """.utf8)
    }
}

/// Reads `data` as the page at `url`, offline (the loader hands back the bytes).
func readArticle(
    _ data: Data, at url: URL = ArticlePage.synthetic, template: SiteTemplate = .v1
) async throws -> ArticleContent {
    try await SitePageArticleContentSource(template: template, load: { _ in data }).content(at: url)
}

/// The blocks of an article whose body is `html`.
func blocks(ofBody html: String) async throws -> [ArticleBlock] {
    try await readArticle(ArticlePage.page(body: html)).blocks
}

/// Text of runs with HTML whitespace collapsed (spaces, tabs, new lines; not U+00A0) and trimmed.
func plain(_ runs: [InlineRun]) -> String {
    collapse(runs.map(\.text).joined())
}

func collapse(_ text: String) -> String {
    text.split(whereSeparator: { " \t\n\r".contains($0) }).joined(separator: " ")
}

/// The visible text of a block, whatever its kind.
func text(of block: ArticleBlock) -> String {
    switch block {
    case let .paragraph(runs), let .heading(_, runs): plain(runs)
    case let .image(image): image.caption ?? ""
    case let .quote(runs, source): plain(runs) + (source.map { " " + $0 } ?? "")
    case let .list(_, items): items.map(plain).joined(separator: " ")
    case let .embed(embed): embed.title ?? ""
    case let .readAlso(summary): summary.title
    case .separator: ""
    }
}

func paragraphs(_ blocks: [ArticleBlock]) -> [String] {
    blocks.compactMap { if case let .paragraph(runs) = $0 { plain(runs) } else { nil } }
}

func headings(_ blocks: [ArticleBlock]) -> [Heading] {
    blocks.compactMap { if case let .heading(level, runs) = $0 { Heading(level: level, text: plain(runs)) } else { nil } }
}

struct Heading: Equatable, CustomStringConvertible {
    let level: Int
    let text: String
    var description: String { "h\(level) \(text)" }
}

func images(_ blocks: [ArticleBlock]) -> [ArticleImage] {
    blocks.compactMap { if case let .image(image) = $0 { image } else { nil } }
}

/// Every run of every block (paragraphs, headings, quotes, list items).
func runs(_ blocks: [ArticleBlock]) -> [InlineRun] {
    blocks.flatMap { block -> [InlineRun] in
        switch block {
        case let .paragraph(runs), let .heading(_, runs), let .quote(runs, _): runs
        case let .list(_, items): items.flatMap { $0 }
        default: []
        }
    }
}

/// Adjacent runs with the same style and link merged, so an exact comparison does not depend on where
/// the reader splits text (entities, comments).
func merged(_ blocks: [ArticleBlock]) -> [ArticleBlock] {
    func merge(_ runs: [InlineRun]) -> [InlineRun] {
        var result: [InlineRun] = []
        for run in runs where !run.text.isEmpty {
            if let last = result.last, last.bold == run.bold, last.italic == run.italic, last.link == run.link {
                result[result.count - 1] = InlineRun(text: last.text + run.text, bold: run.bold, italic: run.italic, link: run.link)
            } else {
                result.append(run)
            }
        }
        return result
    }
    return blocks.map { block in
        switch block {
        case let .paragraph(runs): .paragraph(merge(runs))
        case let .heading(level, runs): .heading(level: level, merge(runs))
        case let .quote(runs, source): .quote(merge(runs), source: source)
        case let .list(ordered, items): .list(ordered: ordered, items: items.map(merge))
        default: block
        }
    }
}

func site(_ path: String) -> URL { URL(string: "https://esprit-festivalier.fr" + path)! }

func isoDate(_ text: String) -> Date {
    try! Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
}
