import EFDomain
import Foundation

public struct MockFestivalSource: FestivalSource {
    public init() {}

    // ponytail: the demo is static, so `updatedSince` is ignored.
    public func festivals(updatedSince: Date?) async throws -> [Festival] {
        MockCatalog.shared.festivals.map(\.festival)
    }

    public func festival(id: Festival.ID) async throws -> FestivalDetail {
        guard let detail = MockCatalog.shared.festivals.first(where: { $0.festival.id == id }) else {
            throw SourceError.festivalNotFound(id)
        }
        return detail
    }
}

public struct MockLineupSource: LineupSource {
    public init() {}

    public func lineups() async throws -> [Lineup] {
        MockCatalog.shared.lineups
    }
}

public struct MockArticleSource: ArticleSource {
    public init() {}

    public func articles(category: Article.Category?) async throws -> [Article] {
        let all = MockCatalog.shared.articles
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}

public struct MockArtistSource: ArtistSource {
    public init() {}

    /// Unknown ids are ignored.
    public func artists(ids: [Artist.ID]) async throws -> [Artist] {
        let wanted = Set(ids)
        return MockCatalog.shared.artists.filter { wanted.contains($0.id) }
    }
}

// ponytail: the bundled demo articles have no body yet; a demo line stands in until they do.
/// The demo articles' text without network: the listed article's body, or its excerpt.
public struct MockArticleContentSource: ArticleContentSource {
    public init() {}

    public func content(at url: URL) async throws -> ArticleContent {
        let key = ArticleKey(url: url)
        guard let article = MockCatalog.shared.articles.first(where: { ArticleKey(url: $0.link) == key }) else {
            throw ArticleContentError.unreadable
        }
        let paragraphs = article.body.isEmpty ? [article.excerpt] : article.body
        let text = paragraphs.filter { !$0.isEmpty }
        return ArticleContent(
            key: key, url: article.link, title: article.title, chapo: nil, category: article.category,
            author: nil, festival: nil, publishedAt: article.publishedAt, modifiedAt: nil, readingMinutes: nil,
            cover: article.imageURL.map { ArticleImage(url: $0, width: nil, height: nil, alt: nil, caption: nil) },
            blocks: (text.isEmpty ? ["Texte de démonstration."] : text).map { .paragraph([InlineRun(text: $0)]) },
            tags: [], related: [], isSponsored: article.isSponsored, parserVersion: SiteTemplate.v1.parserVersion)
    }
}
