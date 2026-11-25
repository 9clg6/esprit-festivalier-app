import Foundation

public protocol FestivalSource: Sendable {
    func festivals(updatedSince: Date?) async throws -> [Festival]
    func festival(id: Festival.ID) async throws -> FestivalDetail
}

public protocol LineupSource: Sendable {
    func lineups() async throws -> [Lineup]
}

public protocol ArticleSource: Sendable {
    func articles(category: Article.Category?) async throws -> [Article]
}

public protocol ArtistSource: Sendable {
    func artists(ids: [Artist.ID]) async throws -> [Artist]
}

public enum SourceError: Error, Equatable {
    case festivalNotFound(Festival.ID)
}
