import Foundation

/// Where an address leads: a screen of the app for a page of the site, Safari for another site (ADR-007).
public enum SiteLink: Hashable, Codable, Sendable {
    case article(ArticleKey)
    case festival(slug: String)
    case author(slug: String)
    case artist(slug: String)
    case category(slug: String)
    case tag(slug: String)
    case page(URL)
    case external(URL)

    /// The site's host, without "www.".
    public static let siteHost = "esprit-festivalier.fr"

    /// `http://` and `www.` addresses of the site are read as the canonical `https://esprit-festivalier.fr/`.
    public init(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              var host = url.host()?.lowercased()
        else {
            self = .external(url)
            return
        }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        guard host == Self.siteHost else {
            self = .external(url)
            return
        }
        let path = url.path(percentEncoded: false)
        let segments = path.split(separator: "/").map(String.init)
        switch (segments.count, segments.first) {
        case (1, _) where ArticleKey.number(inLastSegmentOf: path) != nil: self = .article(ArticleKey(url: url))
        case (2, "festival"): self = .festival(slug: segments[1])
        case (2, "author"): self = .author(slug: segments[1])
        case (2, "artiste"): self = .artist(slug: segments[1])
        case (2, "category"): self = .category(slug: segments[1])
        case (2, "tag"): self = .tag(slug: segments[1])
        default: self = .page(Self.canonical(url))
        }
    }

    private static func canonical(_ url: URL) -> URL {
        guard url.scheme != "https" || url.host() != siteHost,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return url }
        components.scheme = "https"
        components.host = siteHost
        return components.url ?? url
    }
}
