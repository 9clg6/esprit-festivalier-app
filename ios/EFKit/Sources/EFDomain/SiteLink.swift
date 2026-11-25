import Foundation

/// Where an address leads: a screen of the app for a page of the site, Safari for another site, Mail or
/// Phone for `mailto:` and `tel:`; any other scheme is `unsupported` and is never opened (ADR-007).
public enum SiteLink: Hashable, Codable, Sendable {
    case article(ArticleKey)
    case festival(slug: String)
    case author(slug: String)
    case artist(slug: String)
    case category(slug: String)
    case tag(slug: String)
    case page(URL)
    case external(URL)
    case mail(URL)
    case phone(URL)
    case unsupported(URL)

    /// The site's host, without "www.".
    public static let siteHost = "esprit-festivalier.fr"

    /// `http://` and `www.` addresses of the site are read as the canonical `https://esprit-festivalier.fr/`.
    public init(url: URL) {
        switch url.scheme?.lowercased() {
        case "mailto": self = .mail(url)
        case "tel": self = .phone(url)
        case "http", "https": self = Self.site(url).map(Self.init(siteAddress:)) ?? .external(url)
        default: self = .unsupported(url)
        }
    }

    private init(siteAddress url: URL) {
        let path = url.path(percentEncoded: false)
        let segments = path.split(separator: "/").map(String.init)
        switch (segments.count, segments.first) {
        case (1, _) where ArticleKey.number(inLastSegmentOf: path) != nil: self = .article(ArticleKey(url: url))
        case (2, "festival"): self = .festival(slug: segments[1])
        case (2, "author"): self = .author(slug: segments[1])
        case (2, "artiste"): self = .artist(slug: segments[1])
        case (2, "category"): self = .category(slug: segments[1])
        case (2, "tag"): self = .tag(slug: segments[1])
        default: self = .page(url)
        }
    }

    /// The canonical address (`https`, host lowercased, no `www.`) of an http(s) address of the site;
    /// nil for another host, a port or user info.
    public static func site(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.port == nil, components.user == nil, components.password == nil,
              var host = components.host?.lowercased()
        else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        guard host == siteHost else { return nil }
        guard scheme != "https" || components.host != siteHost else { return url }
        components.scheme = "https"
        components.host = siteHost
        return components.url
    }
}
