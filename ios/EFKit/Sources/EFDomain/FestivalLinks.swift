import Foundation

/// The ticket office link with the app's tracking parameters (FR-005).
public enum TicketLink {
    private static let trackingNames: Set<String> = ["utm_source", "utm_medium", "utm_campaign"]

    /// `nil` without a known ticket link: the screen shows no button.
    public static func url(for festival: Festival) -> URL? {
        guard let ticketURL = festival.ticketURL else { return nil }
        guard var components = URLComponents(url: ticketURL, resolvingAgainstBaseURL: false) else { return ticketURL }
        let kept = (components.queryItems ?? []).filter { !trackingNames.contains($0.name) }
        components.queryItems = kept + [
            URLQueryItem(name: "utm_source", value: "esprit-festivalier-app"),
            URLQueryItem(name: "utm_medium", value: "app"),
            URLQueryItem(name: "utm_campaign", value: "festival-\(festival.id)")
        ]
        return components.url ?? ticketURL
    }
}

public enum Directions {
    /// Apple Maps starts a route to the festival (`daddr`), labelled with its name.
    public static func appleMapsURL(for festival: Festival) -> URL {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=#")
        let name = festival.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        // ponytail: built from a fixed host and encoded parts, so this cannot be nil.
        return URL(string: "https://maps.apple.com/?daddr=\(festival.latitude),\(festival.longitude)&q=\(name)")!
    }
}
