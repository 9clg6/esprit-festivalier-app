import Foundation

/// The size to ask the site for an image (`?w=`): the displayed width in pixels, rounded up to a size the
/// site serves, capped at the largest. Any other `w` returns the original (3–4 MB). Another host's image is left as is.
public enum SiteImage {
    public static let widths = [240, 320, 480, 720, 960, 1600]

    public static func url(_ url: URL, pointWidth: Double, scale: Double) -> URL {
        let pixels = pointWidth * scale
        return sized(url, width: widths.first { Double($0) >= pixels } ?? widths[widths.count - 1])
    }

    /// The full-screen photo: the largest size.
    public static func fullscreenURL(_ url: URL) -> URL { sized(url, width: widths[widths.count - 1]) }

    private static func sized(_ url: URL, width: Int) -> URL {
        guard SiteLink.site(url) != nil, var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return url }
        components.queryItems = (components.queryItems ?? []).filter { $0.name != "w" }
            + [URLQueryItem(name: "w", value: String(width))]
        return components.url ?? url
    }
}
