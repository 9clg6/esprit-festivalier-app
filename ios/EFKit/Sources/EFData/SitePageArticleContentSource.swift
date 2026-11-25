import EFDomain
import Foundation

/// The full article, read from its page on the site (ADR-007). `load` returns the page and the response.
/// Metadata from the NewsArticle JSON-LD when present, the rest from the template; no title or an
/// empty body is `ArticleContentError.unreadable`, a loading error reaches the caller unchanged.
/// Only the site is fetched: an address is canonicalised first (`SiteLink.site`), and a page served
/// from another host or with a status outside 200…299 is a typed error.
public struct SitePageArticleContentSource: ArticleContentSource {
    private let template: SiteTemplate
    private let load: @Sendable (URL) async throws -> (Data, URLResponse)

    public init(
        template: SiteTemplate = .v1,
        load: @escaping @Sendable (URL) async throws -> (Data, URLResponse) = SitePageArticleContentSource.loadFromSite
    ) {
        self.template = template
        self.load = load
    }

    public func content(at url: URL) async throws -> ArticleContent {
        guard let url = SiteLink.site(url) else { throw ArticleContentError.notSiteAddress(url) }
        let (data, response) = try await load(url)
        let final = response.url ?? url
        guard SiteLink.site(final) != nil else { throw ArticleContentError.redirectedOffSite(final) }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw URLError(.badServerResponse) }
        guard (200...299).contains(status) else { throw ArticleContentError.httpStatus(status) }
        return try await Self.read(data, at: url, template: template)
    }

    /// Off the caller's actor: the reader runs on every article open.
    @concurrent
    private static func read(_ data: Data, at url: URL, template: SiteTemplate) async throws -> ArticleContent {
        try ArticlePageReader(data: data, url: url, template: template).content()
    }

    // MARK: - Default loader

    /// Gives up after 10 s without data.
    public static let siteSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        return URLSession(configuration: configuration)
    }()

    /// A redirect is followed only to an https address of the site.
    public static func followsRedirect(to url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && SiteLink.site(url) != nil
    }

    @Sendable public static func loadFromSite(_ url: URL) async throws -> (Data, URLResponse) {
        try await siteSession.data(from: url, delegate: SiteRedirects())
    }
}

/// Refuses a redirect off the site: the 3xx answer itself comes back, read as `httpStatus`.
private final class SiteRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        request.url.map(SitePageArticleContentSource.followsRedirect(to:)) == true ? request : nil
    }
}

struct ArticlePageReader {
    private let page: PageContext
    private let template: SiteTemplate
    private let url: URL

    init(data: Data, url: URL, template: SiteTemplate) {
        page = PageContext(document: HTMLDocument(data), base: url)
        self.template = template
        self.url = url
    }

    private var document: HTMLDocument { page.document }

    func content() throws -> ArticleContent {
        guard let main = document.first(where: { $0.attribute("id") == template.mainID }) else {
            throw ArticleContentError.unreadable
        }
        let jsonLD = JSONLD.newsArticle(in: document)
        let byline = classed(template.byline, in: main)
        guard let title = jsonLD?.text("headline") ?? classed(template.title, in: main).map(text),
              !title.isEmpty,
              let publishedAt = jsonLD?.date("datePublished") ?? byline.flatMap(time(in:)),
              let body = classed(template.body, in: main)
        else { throw ArticleContentError.unreadable }
        var reader = ArticleBodyReader(page: page, template: template)
        reader.read(body)
        guard !reader.blocks.isEmpty else { throw ArticleContentError.unreadable }
        return ArticleContent(
            key: ArticleKey(url: url), url: url, title: title,
            chapo: page.nonEmpty(classed(template.chapo, in: main).map(text)),
            category: category(jsonLD: jsonLD, main: main),
            author: author(jsonLD: jsonLD, byline: byline, main: main),
            festival: festival(in: main), publishedAt: publishedAt, modifiedAt: jsonLD?.date("dateModified"),
            readingMinutes: byline.flatMap(readingMinutes(in:)), cover: cover(in: main), blocks: reader.blocks,
            tags: tags(in: main), related: related(in: main),
            isSponsored: classed(template.sponsored, in: main) != nil, parserVersion: template.parserVersion)
    }

    // MARK: - Template

    private func classed(_ name: String, in root: Int) -> Int? { document.first(in: root) { $0.hasClass(name) } }

    private func text(_ index: Int) -> String { document.text(of: index) }

    private func href(_ index: Int) -> URL? { page.link(document[index].attribute("href")) }

    private func time(in root: Int) -> Date? {
        document.first(in: root) { $0.name == "time" }.flatMap { document[$0].attribute("datetime") }
            .flatMap(JSONLD.date)
    }

    private func readingMinutes(in byline: Int) -> Int? {
        let line = text(byline)
        guard let marker = line.range(of: template.readingTime) else { return nil }
        let before = line[..<marker.lowerBound].trimmingCharacters(in: .whitespaces)
        return Int(String(before.reversed().prefix(while: \.isNumber).reversed()))
    }

    private func category(jsonLD: JSONLD?, main: Int) -> Article.Category {
        let name = jsonLD?.text("articleSection") ?? classed(template.category, in: main).map(text)
        return page.nonEmpty(name).map(Article.Category.init(rawValue:)) ?? .actu
    }

    private func author(jsonLD: JSONLD?, byline: Int?, main: Int) -> AuthorRef? {
        let link = byline.flatMap { line in document.first(in: line) { $0.name == "a" && authorSlug(of: $0) != nil } }
        guard let name = jsonLD?.authorName ?? link.map(text), !name.isEmpty,
              let slug = jsonLD?.authorURL.flatMap(Self.authorSlug) ?? link.flatMap({ authorSlug(of: document[$0]) })
        else { return nil }
        let avatar = byline.flatMap { line in
            document.first(in: line) { $0.name == "img" && $0.hasClass(template.avatar) }
        }
        let avatarURL = avatar.flatMap { page.link(document[$0].attribute("src")).flatMap(PageContext.siteImage) }
        return AuthorRef(
            slug: slug, name: name, avatarURL: avatarURL,
            bio: bio(of: slug, in: main))
    }

    /// The line of the author box, when the box is this author's.
    private func bio(of slug: String, in main: Int) -> String? {
        guard let box = classed(template.authorBox, in: main) else { return nil }
        let boxAuthor = document.first(in: box) { $0.name == "a" }.flatMap { authorSlug(of: document[$0]) }
        guard boxAuthor == nil || boxAuthor == slug else { return nil }
        return page.nonEmpty(document.first(in: box) { $0.name == "p" }.map(text))
    }

    private func authorSlug(of element: HTMLDocument.Element) -> String? {
        page.link(element.attribute("href")).flatMap(Self.authorSlug)
    }

    private static func authorSlug(_ url: URL) -> String? {
        if case let .author(slug) = SiteLink(url: url) { slug } else { nil }
    }

    private func festival(in main: Int) -> FestivalRef? {
        guard let tag = classed(template.festival, in: main), let url = href(tag),
              case let .festival(slug) = SiteLink(url: url), let name = page.nonEmpty(text(tag))
        else { return nil }
        return FestivalRef(slug: slug, name: name)
    }

    private func cover(in main: Int) -> ArticleImage? {
        guard let figure = classed(template.cover, in: main),
              let img = document.first(in: figure, where: { $0.name == "img" })
        else { return nil }
        return page.image(img, caption: document.first(in: figure) { $0.name == "figcaption" }.map(text))
    }

    private func tags(in main: Int) -> [SiteLink] {
        guard let tags = classed(template.tags, in: main) else { return [] }
        return document.all(in: tags) { $0.name == "a" }.compactMap(href).map(SiteLink.init(url:))
    }

    /// The cards of the related section that are articles.
    private func related(in main: Int) -> [ArticleSummary] {
        guard let section = classed(template.related, in: main) else { return [] }
        return document.all(in: section) { $0.name == "article" && $0.hasClass(template.card) }.compactMap { card in
            let heading = document.first(in: card) { $0.name == "h2" || $0.name == "h3" }
            guard let summary = heading.flatMap(page.summary(in:)),
                  SiteLink(url: summary.url) == .article(summary.key)
            else { return nil }
            return summary
        }
    }
}

/// The NewsArticle of the page's JSON-LD (the most stable source of metadata, ADR-007).
struct JSONLD {
    private let object: [String: Any]

    static func newsArticle(in document: HTMLDocument) -> JSONLD? {
        let scripts = document.all(in: 0) { $0.name == "script" && $0.attribute("type") == "application/ld+json" }
        for script in scripts {
            guard case let .text(raw)? = document[script].children.first,
                  let parsed = try? JSONSerialization.jsonObject(with: Data(raw.utf8))
            else { continue }
            let candidates = (parsed as? [[String: Any]]) ?? (parsed as? [String: Any]).map { [$0] + graph($0) } ?? []
            if let article = candidates.first(where: isArticle) { return JSONLD(object: article) }
        }
        return nil
    }

    private static func graph(_ object: [String: Any]) -> [[String: Any]] { object["@graph"] as? [[String: Any]] ?? [] }

    private static func isArticle(_ object: [String: Any]) -> Bool {
        let types = (object["@type"] as? [String]) ?? [(object["@type"] as? String) ?? ""]
        return types.contains { $0.hasSuffix("Article") }
    }

    /// A string (or the first of a list), entities decoded, whitespace collapsed; nil when empty.
    func text(_ key: String) -> String? { Self.clean(object[key]) }

    func date(_ key: String) -> Date? { text(key).flatMap(Self.date) }

    private var author: [String: Any]? {
        (object["author"] as? [String: Any]) ?? (object["author"] as? [[String: Any]])?.first
    }

    var authorName: String? { Self.clean(author?["name"]) }
    var authorURL: URL? { Self.clean(author?["url"]).flatMap(URL.init(string:)) }

    private static func clean(_ value: Any?) -> String? {
        guard let raw = (value as? String) ?? (value as? [String])?.first else { return nil }
        let text = HTMLEntity.decode(raw).split(whereSeparator: HTMLDocument.isSpace).joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    static func date(_ text: String) -> Date? {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        return (try? Date(text, strategy: style)) ?? (try? Date(text, strategy: Date.ISO8601FormatStyle()))
    }
}
