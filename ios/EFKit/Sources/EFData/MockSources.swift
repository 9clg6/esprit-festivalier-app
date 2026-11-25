import EFDomain
import Foundation

public struct MockFestivalSource: FestivalSource {
    public init() {}

    // ponytail: the demo is static, so `updatedSince` is ignored.
    public func festivals(updatedSince: Date?) async throws -> [Festival] {
        MockCatalog.shared.festivals.map(\.festival)
    }

    public func festival(id: Festival.ID) async throws -> FestivalDetail {
        guard let detail = MockCatalog.shared.festivals.first(where: { $0.festival.id == id }) else {
            throw SourceError.festivalNotFound(id)
        }
        return detail
    }
}

public struct MockLineupSource: LineupSource {
    public init() {}

    public func lineups() async throws -> [Lineup] {
        MockCatalog.shared.lineups
    }
}

public struct MockArticleSource: ArticleSource {
    public init() {}

    public func articles(category: Article.Category?) async throws -> [Article] {
        let all = MockCatalog.shared.articles
        guard let category else { return all }
        return all.filter { $0.category == category }
    }
}

public struct MockArtistSource: ArtistSource {
    public init() {}

    /// Unknown ids are ignored.
    public func artists(ids: [Artist.ID]) async throws -> [Artist] {
        let wanted = Set(ids)
        return MockCatalog.shared.artists.filter { wanted.contains($0.id) }
    }
}
