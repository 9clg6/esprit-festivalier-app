import Foundation

/// Loads the site's feed. A good answer is kept in Application Support; when the site cannot be
/// reached the kept copy is used and `offlineSince` says when it was fetched.
public actor SiteFeed {
    public static let feedURL = URL(string: "https://esprit-festivalier.fr/feed/")!

    public private(set) var offlineSince: Date?
    private let cacheURL: URL
    private let fetch: @Sendable () async throws -> Data

    public init(
        cacheURL: URL = URL.applicationSupportDirectory.appending(path: "feed.xml"),
        fetch: @escaping @Sendable () async throws -> Data = SiteFeed.fetchFromSite
    ) {
        self.cacheURL = cacheURL
        self.fetch = fetch
    }

    public func data() async throws -> Data {
        do {
            let data = try await fetch()
            _ = try RSSArticleSource.parse(data)  // never keep a captive-portal page
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
            offlineSince = nil
            return data
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let cached = try? Data(contentsOf: cacheURL),
                  let date = (try? cacheURL.resourceValues(forKeys: [.contentModificationDateKey]))?
                      .contentModificationDate
            else { throw error }
            offlineSince = date
            return cached
        }
    }

    @Sendable public static func fetchFromSite() async throws -> Data {
        var request = URLRequest(url: feedURL, timeoutInterval: 10)
        request.setValue("application/rss+xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
