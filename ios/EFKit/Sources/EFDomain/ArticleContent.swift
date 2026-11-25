import Foundation

/// Identifies an article whatever the address it was reached by: the number at the end of its
/// address ("…-10675/" → "10675"), otherwise its path (ADR-007).
public struct ArticleKey: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public init(url: URL) {
        let path = url.path(percentEncoded: false)
        self.init(rawValue: Self.number(inLastSegmentOf: path) ?? path)
    }

    /// "…-10675" or "…-10675/" → "10675"; nil when the last segment does not end with "-<digits>".
    static func number(inLastSegmentOf path: String) -> String? {
        guard let last = path.split(separator: "/").last else { return nil }
        let digits = last.reversed().prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, last.dropLast(digits.count).last == "-" else { return nil }
        return String(digits.reversed())
    }
}

/// A piece of text with one style. A paragraph is a list of runs.
public struct InlineRun: Sendable, Codable, Hashable {
    public let text: String
    public var bold = false
    public var italic = false
    public var link: URL?

    public init(text: String, bold: Bool = false, italic: Bool = false, link: URL? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.link = link
    }
}

public struct ArticleImage: Sendable, Codable, Hashable {
    public let url: URL
    public let width: Int?
    public let height: Int?
    public let alt: String?
    /// The whole legend, photo credit included (the markup does not separate them).
    public let caption: String?

    public init(url: URL, width: Int?, height: Int?, alt: String?, caption: String?) {
        self.url = url
        self.width = width
        self.height = height
        self.alt = alt
        self.caption = caption
    }
}

/// Third-party content (video, playlist…): never loaded inside the article (NFR-005).
public struct Embed: Sendable, Codable, Hashable {
    public enum Provider: String, Sendable, Codable, Hashable { case youtube, spotify, instagram, other }

    public let provider: Provider
    public let url: URL
    public let title: String?

    public init(provider: Provider, url: URL, title: String?) {
        self.provider = provider
        self.url = url
        self.title = title
    }
}

public struct ArticleSummary: Sendable, Codable, Hashable {
    public let key: ArticleKey
    public let url: URL
    public let title: String

    public init(key: ArticleKey, url: URL, title: String) {
        self.key = key
        self.url = url
        self.title = title
    }
}

public struct AuthorRef: Sendable, Codable, Hashable {
    public let slug: String
    public let name: String
    public let avatarURL: URL?
    /// The line of presentation of the author box at the end of the article.
    public let bio: String?

    public init(slug: String, name: String, avatarURL: URL?, bio: String?) {
        self.slug = slug
        self.name = name
        self.avatarURL = avatarURL
        self.bio = bio
    }
}

public struct FestivalRef: Sendable, Codable, Hashable {
    public let slug: String
    public let name: String

    public init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }
}

public enum ArticleBlock: Sendable, Codable, Hashable {
    case paragraph([InlineRun])
    case heading(level: Int, [InlineRun])
    case image(ArticleImage)
    case quote([InlineRun], source: String?)
    case list(ordered: Bool, items: [[InlineRun]])
    case embed(Embed)
    case readAlso(ArticleSummary)
    case separator
}

/// The full article, as the native reader shows it and the offline cache stores it (ADR-007).
public struct ArticleContent: Sendable, Codable, Hashable {
    public let key: ArticleKey
    public let url: URL
    public let title: String
    public let chapo: String?
    public let category: Article.Category
    public let author: AuthorRef?
    public let festival: FestivalRef?
    public let publishedAt: Date
    public let modifiedAt: Date?
    public let readingMinutes: Int?
    public let cover: ArticleImage?
    public let blocks: [ArticleBlock]
    /// Keywords and artists of the article.
    public let tags: [SiteLink]
    public let related: [ArticleSummary]
    public let isSponsored: Bool
    /// The reader that produced it: a copy of another version is reloaded when possible.
    public let parserVersion: Int

    public init(
        key: ArticleKey, url: URL, title: String, chapo: String?, category: Article.Category, author: AuthorRef?,
        festival: FestivalRef?, publishedAt: Date, modifiedAt: Date?, readingMinutes: Int?, cover: ArticleImage?,
        blocks: [ArticleBlock], tags: [SiteLink], related: [ArticleSummary], isSponsored: Bool, parserVersion: Int
    ) {
        self.key = key
        self.url = url
        self.title = title
        self.chapo = chapo
        self.category = category
        self.author = author
        self.festival = festival
        self.publishedAt = publishedAt
        self.modifiedAt = modifiedAt
        self.readingMinutes = readingMinutes
        self.cover = cover
        self.blocks = blocks
        self.tags = tags
        self.related = related
        self.isSponsored = isSponsored
        self.parserVersion = parserVersion
    }
}

public protocol ArticleContentSource: Sendable {
    /// `url`: the address of the article on the site (feed, internal link, notification).
    func content(at url: URL) async throws -> ArticleContent
}

public enum ArticleContentError: Error, Equatable {
    /// The page is not an article the reader understands (no title, empty body, not HTML).
    case unreadable
    /// Only https://esprit-festivalier.fr/ addresses are downloaded.
    case notSiteAddress(URL)
    /// The site answered outside 200…299.
    case httpStatus(Int)
    /// The page was served from another host than the site (after a redirect).
    case redirectedOffSite(URL)
}
