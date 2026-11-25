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
    /// Lineups and artists are demo data: the screens say so.
    let isDemo: Bool

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
            isDemo = true
        }
        favorites = FavoritesModel(
            store: FavoritesStore(directory: .applicationSupportDirectory.appending(path: "EspritFestivalier"))
        )
    }

    /// Festival dates are read on the Paris calendar, in French.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    /// Festivals, lineups and the artists the lineups name: what E1, E7 and E8 are built from.
    func lineupData() async throws -> LineupData {
        async let festivals = festivals.festivals(updatedSince: nil)
        let lineups = try await lineups.lineups()
        let artists = try await artists.artists(ids: Array(Set(lineups.flatMap(\.artistIds))))
        return LineupData(festivals: try await festivals, lineups: lineups, artists: artists)
    }

    /// Reads `EF_DATA_SOURCE`; a missing or unknown value means `mock`.
    @MainActor init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "EF_DATA_SOURCE") as? String ?? ""
        self.init(kind: DataSourceKind(rawValue: value) ?? .mock)
    }
}

struct LineupData {
    let festivals: [Festival]
    let lineups: [Lineup]
    let artists: [Artist]
}
