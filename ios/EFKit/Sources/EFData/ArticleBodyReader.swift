import EFDomain
import Foundation

/// Turns `div.article-body` into blocks (ADR-007 "Règles de lecture"). The body ends with its element or
/// at the end marker, whichever comes first. An unknown element keeps its text in a paragraph.
struct ArticleBodyReader {
    let page: PageContext
    let template: SiteTemplate
    private(set) var blocks: [ArticleBlock] = []
    /// Text met outside any block element, waiting for the next block to become a paragraph.
    private var loose = RunBuilder()
    private var looseImages: [ArticleImage] = []
    private var ended = false

    init(page: PageContext, template: SiteTemplate) {
        self.page = page
        self.template = template
    }

    mutating func read(_ body: Int) {
        readChildren(of: body)
        flush()
    }

    private var document: HTMLDocument { page.document }

    private mutating func readChildren(of root: Int) {
        for node in document[root].children where !ended {
            switch node {
            case let .text(text): loose.append(text, style: InlineStyle())
            case let .element(index): read(element: index)
            }
        }
    }

    private mutating func read(element index: Int) {
        let element = document[index]
        if element.hasClass(template.bodyEnd) {
            ended = true
        } else if HTMLDocument.inline.contains(element.name) {
            page.collect([.element(index)], style: InlineStyle(), into: &loose, images: &looseImages)
        } else if !HTMLDocument.skipped.contains(element.name) {
            flush()
            readBlock(index)
        }
    }

    private mutating func readBlock(_ index: Int) {
        let element = document[index]
        switch element.name {
        case "p":
            page.collect([.element(index)], style: InlineStyle(), into: &loose, images: &looseImages)
            flush()
        case "h1", "h2", "h3", "h4", "h5", "h6": appendHeading(index)
        case "ul", "ol": appendList(index, ordered: element.name == "ol")
        case "blockquote": appendQuote(index)
        case "hr": blocks.append(.separator)
        case "img": page.image(index, caption: nil).map { blocks.append(.image($0)) }
        case "iframe": page.embed(index).map { blocks.append(.embed($0)) }
        case "figure": appendFigure(index)
        case "aside" where element.hasClass(template.readAlso):
            page.summary(in: index).map { blocks.append(.readAlso($0)) }
        default:
            readChildren(of: index)
            flush()
        }
    }

    /// Ends the pending paragraph; a short bold-only one is a level 3 heading.
    private mutating func flush() {
        let runs = loose.finish()
        if !runs.isEmpty {
            let text = runs.map(\.text).joined()
            let boldOnly = runs.allSatisfy { $0.bold || $0.text.allSatisfy(HTMLDocument.isSpace) }
            if boldOnly && text.count < template.boldHeadingMaxLength {
                let plain = runs.map { InlineRun(text: $0.text, italic: $0.italic, link: $0.link) }
                blocks.append(.heading(level: 3, plain))
            } else {
                blocks.append(.paragraph(runs))
            }
        }
        blocks += looseImages.map(ArticleBlock.image)
        loose = RunBuilder()
        looseImages = []
    }

    // MARK: - Blocks

    private mutating func appendHeading(_ index: Int) {
        let level = min(max(Int(String(document[index].name.dropFirst())) ?? 3, 2), 4)
        appendRuns(of: [.element(index)]) { .heading(level: level, $0) }
    }

    private mutating func appendList(_ index: Int, ordered: Bool) {
        var images: [ArticleImage] = []
        let items = document[index].children.compactMap { node -> [InlineRun]? in
            guard case let .element(item) = node, document[item].name == "li" else { return nil }
            var runs = RunBuilder()
            page.collect([node], style: InlineStyle(), into: &runs, images: &images)
            let finished = runs.finish()
            return finished.isEmpty ? nil : finished
        }
        if !items.isEmpty { blocks.append(.list(ordered: ordered, items: items)) }
        blocks += images.map(ArticleBlock.image)
    }

    private mutating func appendQuote(_ index: Int) {
        let children = document[index].children
        func isCite(_ node: HTMLDocument.Node) -> Bool {
            if case let .element(child) = node { document[child].name == "cite" } else { false }
        }
        let source: String? = if case let .element(cite)? = children.first(where: isCite) {
            page.nonEmpty(document.text(of: cite))
        } else {
            nil
        }
        let said = children.filter { !isCite($0) }
        appendRuns(of: said) { .quote($0, source: source) }
    }

    private mutating func appendFigure(_ index: Int) {
        if let iframe = document.first(in: index, where: { $0.name == "iframe" }) {
            page.embed(iframe).map { blocks.append(.embed($0)) }
        } else if let img = document.first(in: index, where: { $0.name == "img" }) {
            let caption = document.first(in: index) { $0.name == "figcaption" }.map(document.text(of:))
            page.image(img, caption: caption).map { blocks.append(.image($0)) }
        } else {
            readChildren(of: index)
            flush()
        }
    }

    private mutating func appendRuns(of nodes: [HTMLDocument.Node], as block: ([InlineRun]) -> ArticleBlock) {
        var runs = RunBuilder()
        var images: [ArticleImage] = []
        page.collect(nodes, style: InlineStyle(), into: &runs, images: &images)
        let finished = runs.finish()
        if !finished.isEmpty { blocks.append(block(finished)) }
        blocks += images.map(ArticleBlock.image)
    }
}

struct InlineStyle: Equatable {
    var bold = false
    var italic = false
    var link: URL?
}

/// Collects runs with HTML whitespace collapsed across runs; a trailing space stays in the run it was
/// written in ("Une gourde " + "vide").
struct RunBuilder {
    private var runs: [InlineRun] = []
    private var afterSpace = true

    mutating func append(_ text: String, style: InlineStyle) {
        var kept = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar == " " || scalar == "\n" || scalar == "\t" || scalar == "\r" || scalar == "\u{C}" {
                if !afterSpace { kept.append(" ") }
                afterSpace = true
            } else {
                kept.append(scalar)
                afterSpace = false
            }
        }
        add(String(kept), style: style)
    }

    mutating func lineBreak(style: InlineStyle) {
        guard !runs.isEmpty else { return }
        add("\n", style: style)
        afterSpace = true
    }

    /// The runs, trailing whitespace removed; empty when there is no visible text.
    mutating func finish() -> [InlineRun] {
        while let last = runs.last, last.text.last?.isWhitespace ?? true {
            var trimmed = Substring(last.text)
            while trimmed.last?.isWhitespace == true { trimmed.removeLast() }
            if trimmed.isEmpty {
                runs.removeLast()
            } else {
                runs[runs.count - 1] = InlineRun(
                    text: String(trimmed), bold: last.bold, italic: last.italic, link: last.link)
            }
        }
        return runs
    }

    private mutating func add(_ text: String, style: InlineStyle) {
        guard !text.isEmpty else { return }
        if let last = runs.last, last.bold == style.bold, last.italic == style.italic, last.link == style.link {
            runs[runs.count - 1] = InlineRun(
                text: last.text + text, bold: style.bold, italic: style.italic, link: style.link)
        } else {
            runs.append(InlineRun(text: text, bold: style.bold, italic: style.italic, link: style.link))
        }
    }
}

/// The page being read and the addresses it resolves against.
struct PageContext {
    let document: HTMLDocument
    let base: URL

    /// An absolute address for `href`, relative ones resolved on the page's address. As browsers do,
    /// spaces around it and tabs or new lines inside it are removed.
    func link(_ href: String?) -> URL? {
        guard let href = href?.trimmingCharacters(in: .whitespacesAndNewlines).filter({ !$0.isNewline && $0 != "\t" }),
              !href.isEmpty
        else { return nil }
        return URL(string: href, relativeTo: base)?.absoluteURL
    }

    /// Only images of the site are loaded (NFR-005), at their canonical https address.
    static func siteImage(_ url: URL) -> URL? { SiteLink.site(url) }

    func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    /// Text, styles, links; images met on the way are handed back in `images`.
    func collect(
        _ nodes: [HTMLDocument.Node], style: InlineStyle, into runs: inout RunBuilder, images: inout [ArticleImage]
    ) {
        for node in nodes {
            switch node {
            case let .text(text): runs.append(text, style: style)
            case let .element(index):
                let element = document[index]
                switch element.name {
                case "br": runs.lineBreak(style: style)
                case "img": image(index, caption: nil).map { images.append($0) }
                case _ where HTMLDocument.skipped.contains(element.name): break
                default:
                    let isBlock = !HTMLDocument.inline.contains(element.name)
                    if isBlock { runs.append(" ", style: style) }
                    collect(element.children, style: entering(element, from: style), into: &runs, images: &images)
                    if isBlock { runs.append(" ", style: style) }
                }
            }
        }
    }

    private func entering(_ element: HTMLDocument.Element, from style: InlineStyle) -> InlineStyle {
        var style = style
        switch element.name {
        case "strong", "b": style.bold = true
        case "em", "i": style.italic = true
        case "a": style.link = openable(link(element.attribute("href"))) ?? style.link
        default: break
        }
        return style
    }

    /// Web, mail and phone addresses; javascript:, file:, data:… are no link.
    private func openable(_ url: URL?) -> URL? {
        guard let url else { return nil }
        if case .unsupported = SiteLink(url: url) { return nil }
        return url
    }

    /// The image without the site's `?w=` size: the reader asks the size it shows.
    func image(_ index: Int, caption: String?) -> ArticleImage? {
        let element = document[index]
        guard let url = link(element.attribute("src")).flatMap(Self.siteImage),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return nil }
        components.query = nil
        components.fragment = nil
        return ArticleImage(
            url: components.url ?? url, width: element.attribute("width").flatMap { Int($0) },
            height: element.attribute("height").flatMap { Int($0) }, alt: nonEmpty(element.attribute("alt")),
            caption: nonEmpty(caption).flatMap { Self.isFileName($0, of: url) ? nil : $0 })
    }

    /// An editor's leftover file name (« deryck 650.png ») is no caption, cover and body alike.
    static func isFileName(_ caption: String, of url: URL) -> Bool {
        let name = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return name == url.lastPathComponent
            || ["png", "jpg", "jpeg", "webp", "gif", "avif"].contains { name.lowercased().hasSuffix("." + $0) }
    }

    func embed(_ index: Int) -> Embed? {
        let element = document[index]
        guard let url = link(element.attribute("src")) else { return nil }
        let host = url.host()?.lowercased() ?? ""
        func on(_ domains: String...) -> Bool { domains.contains { host == $0 || host.hasSuffix("." + $0) } }
        let provider: Embed.Provider = if on("youtube.com", "youtube-nocookie.com", "youtu.be") {
            .youtube
        } else if on("spotify.com") {
            .spotify
        } else if on("instagram.com") {
            .instagram
        } else {
            .other
        }
        return Embed(provider: provider, url: url, title: nonEmpty(element.attribute("title")))
    }

    /// The first link under `root`, as an article summary titled by the link's text.
    func summary(in root: Int) -> ArticleSummary? {
        guard let anchor = document.first(in: root, where: { $0.name == "a" && $0.attribute("href") != nil }),
              let url = link(document[anchor].attribute("href")),
              let title = nonEmpty(document.text(of: anchor))
        else { return nil }
        return ArticleSummary(key: ArticleKey(url: url), url: url, title: title)
    }
}
