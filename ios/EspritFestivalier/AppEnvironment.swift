import EFData
import EFDomain
import Foundation

/// The sources the screens depend on, chosen by the `EF_DATA_SOURCE` Info.plist value.
struct AppEnvironment: Sendable {
    let festivals: any FestivalSource
    let lineups: any LineupSource
    let articles: any ArticleSource
    let articleFeed: SiteFeed
    let artists: any ArtistSource
    /// Favorites, kept in Application Support (not Caches: the system may empty Caches).
    let favorites: FavoritesModel

    @MainActor init(kind: DataSourceKind) {
        // Articles always come from the live site feed, whatever the data source.
        let feed = SiteFeed()
        articleFeed = feed
        articles = RSSArticleSource(load: { try await feed.data() })
        switch kind {
        case .mock, .snapshot, .backoffice:
            // ponytail: only mock exists; snapshot and backoffice fall back to it until STORY-007.
            festivals = MockFestivalSource()
            lineups = MockLineupSource()
            artists = MockArtistSource()
        }
        favorites = FavoritesModel(
            store: FavoritesStore(directory: .applicationSupportDirectory.appending(path: "EspritFestivalier"))
        )
    }

    /// Reads `EF_DATA_SOURCE`; a missing or unknown value means `mock`.
    @MainActor init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "EF_DATA_SOURCE") as? String ?? ""
        self.init(kind: DataSourceKind(rawValue: value) ?? .mock)
    }
}
