import Foundation
import Testing
import EFDomain

// The screens only see these protocols (STORY-003, NFR-008). This file pins the
// signatures of the architecture doc ("Composant : couche de sources"): another
// module must be able to implement every source and a caller must use it through
// `any …Source`. It stops compiling if a signature drifts.

private struct EmptyCatalog: FestivalSource, LineupSource, ArticleSource, ArtistSource {
    struct Missing: Error {}

    func festivals(updatedSince: Date?) async throws -> [Festival] { [] }
    func festival(id: Festival.ID) async throws -> FestivalDetail { throw Missing() }
    func lineups() async throws -> [Lineup] { [] }
    func articles(category: Article.Category?) async throws -> [Article] { [] }
    func artists(ids: [Artist.ID]) async throws -> [Artist] { [] }
}

@Test func aSourceWrittenOutsideTheDomainCanBeUsedThroughItsProtocol() async throws {
    let festivals: any FestivalSource = EmptyCatalog()
    let lineups: any LineupSource = EmptyCatalog()
    let articles: any ArticleSource = EmptyCatalog()
    let artists: any ArtistSource = EmptyCatalog()

    #expect(try await festivals.festivals(updatedSince: nil).isEmpty)
    #expect(try await lineups.lineups().isEmpty)
    #expect(try await articles.articles(category: nil).isEmpty)
    #expect(try await artists.artists(ids: []).isEmpty)
}
