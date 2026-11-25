import Testing
import EFDomain
import EFData

@Suite struct MockLineupSourceTests {
    private let lineupSource: any LineupSource = MockLineupSource()

    private func demoLineups() async throws -> [Lineup] {
        let lineups = try await lineupSource.lineups()
        try #require(!lineups.isEmpty, "the demo has no lineup")
        return lineups
    }

    @Test func everyDemoFestivalHasALineup() async throws {
        let festivalIds = Set(try await MockFestivalSource().festivals(updatedSince: nil).map(\.id))
        let lineups = try await demoLineups()

        #expect(festivalIds.isSubset(of: Set(lineups.map(\.festivalId))))
        for lineup in lineups {
            #expect(!lineup.artistIds.isEmpty, "lineup of \(lineup.festivalId) is empty")
        }
    }

    @Test func everyLineupRefersToAnExistingFestival() async throws {
        let festivalIds = Set(try await MockFestivalSource().festivals(updatedSince: nil).map(\.id))

        for lineup in try await demoLineups() {
            #expect(festivalIds.contains(lineup.festivalId), "unknown festival \(lineup.festivalId)")
        }
    }

    @Test func everyLineupRefersToExistingArtists() async throws {
        let wanted = try await demoLineups().flatMap(\.artistIds)
        try #require(!wanted.isEmpty, "the lineups name no artist")
        let known = Set(try await MockArtistSource().artists(ids: Array(Set(wanted))).map(\.id))

        for artistId in wanted {
            #expect(known.contains(artistId), "unknown artist \(artistId)")
        }
    }
}
