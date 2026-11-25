import EFData
import EFDomain
import Foundation

/// The sources the screens depend on, chosen by the `EF_DATA_SOURCE` Info.plist value.
struct AppEnvironment: Sendable {
    let festivals: any FestivalSource
    let lineups: any LineupSource
    let articles: any ArticleSource
    let artists: any ArtistSource

    init(kind: DataSourceKind) {
        switch kind {
        case .mock, .snapshot, .backoffice:
            // ponytail: only mock exists; snapshot and backoffice fall back to it until STORY-007.
            festivals = MockFestivalSource()
            lineups = MockLineupSource()
            articles = MockArticleSource()
            artists = MockArtistSource()
        }
    }

    /// Reads `EF_DATA_SOURCE`; a missing or unknown value means `mock`.
    init(bundle: Bundle = .main) {
        let value = bundle.object(forInfoDictionaryKey: "EF_DATA_SOURCE") as? String ?? ""
        self.init(kind: DataSourceKind(rawValue: value) ?? .mock)
    }
}
