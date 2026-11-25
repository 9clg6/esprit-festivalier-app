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
    /// Picked sets of the timetables and their reminders.
    let picks: PicksModel
    /// Favorite sheets and images kept on the device (STORY-008).
    let offline: OfflineCache
    /// The account and the data export (STORY-022, STORY-032).
    let account: AccountModel
    /// Lineups and artists are demo data: the screens say so.
    let isDemo: Bool

    @MainActor init(kind: DataSourceKind) {
        // Articles always come from the live site feed, whatever the data source.
        let feed = SiteFeed()
        articleFeed = feed
        articles = RSSArticleSource(load: { try await feed.data() })
        let directory = URL.applicationSupportDirectory.appending(path: "EspritFestivalier")
        let offline = OfflineCache(directory: directory.appending(path: "Offline"), fetchImage: OfflineImage.fetch)
        self.offline = offline
        let catalog: any FestivalSource
        let auth: any AuthService
        let sync: any SyncService
        switch kind {
        case .mock, .snapshot, .backoffice:
            // ponytail: only mock exists; snapshot and backoffice fall back to it until STORY-007.
            catalog = MockFestivalSource()
            lineups = MockLineupSource()
            artists = MockArtistSource()
            isDemo = true
            // ponytail: mock account for every kind until the Better Auth client (STORY-021) and the
            // `/v1/me/sync` client (STORY-023) replace them. The deletion erases this whole folder.
            auth = MockAuthService(directory: directory.appending(path: "Account"), userDataDirectories: [directory])
            sync = NoopSyncService()
        }
        // Every screen reads a favorite's sheet through the offline copy (STORY-008).
        festivals = OfflineFestivalSource(source: catalog, cache: offline)
        favorites = FavoritesModel(store: FavoritesStore(directory: directory), offline: offline, festivals: festivals)
        picks = PicksModel(
            store: PicksStore(directory: directory),
            reminders: ConcertReminderScheduler(festivals: festivals, artists: artists)
        )
        account = AccountModel(auth: auth, sync: sync, favorites: favorites, picks: picks)
    }

    /// Festival dates are read on the Paris calendar, in French.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    /// Mes festivals: the catalogue, or offline the stored favorites. Other screens keep their error
    /// state, so they never pass the favorites off as the whole catalogue.
    func myFestivals() async throws -> [Festival] {
        do {
            return try await festivals.festivals(updatedSince: nil)
        } catch {
            let stored = await offline.storedFestivals()
            if stored.isEmpty { throw error }
            return stored
        }
    }

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

/// A festival source whose detail falls back to the offline copy of a favorite.
struct OfflineFestivalSource: FestivalSource {
    let source: any FestivalSource
    let cache: OfflineCache

    func festivals(updatedSince: Date?) async throws -> [Festival] {
        try await source.festivals(updatedSince: updatedSince)
    }

    func festival(id: Festival.ID) async throws -> FestivalDetail {
        try await cache.festival(id: id, from: source)
    }
}

/// Now, or in debug builds `-fakeNow 2026-12-02T18:30:00+01:00` (simulator runs, screenshots).
func appNow(_ date: Date = Date()) -> Date {
    #if DEBUG
    if let text = UserDefaults.standard.string(forKey: "fakeNow"), let fake = try? Date(text, strategy: .iso8601) {
        return fake
    }
    #endif
    return date
}

struct LineupData {
    let festivals: [Festival]
    let lineups: [Lineup]
    let artists: [Artist]
}
