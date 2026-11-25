import Foundation
import Testing
import EFDomain
import EFData

// STORY-012 on the demo data: the region filter needs each demo festival's French region.

private let expectedRegions: [Festival.ID: String] = [
    "hellfest": "Pays de la Loire",
    "vieilles-charrues": "Bretagne",
    "eurockeennes": "Bourgogne-Franche-Comté",
    "francofolies": "Nouvelle-Aquitaine",
    "trans-musicales": "Bretagne"
]

@Suite struct MockFestivalRegionTests {
    @Test func everyDemoFestivalHasItsFrenchRegion() async throws {
        let festivals = try await MockFestivalSource().festivals(updatedSince: nil)
        try #require(Set(festivals.map(\.id)) == Set(expectedRegions.keys))

        for festival in festivals {
            #expect(festival.region == expectedRegions[festival.id], "\(festival.id)")
        }
    }

    @Test func theBretagneFilterKeepsTheTwoBretonDemoFestivals() async throws {
        var paris = Calendar(identifier: .gregorian)
        paris.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        paris.locale = Locale(identifier: "fr_FR")
        let festivals = try await MockFestivalSource().festivals(updatedSince: nil)

        let breton = FestivalFilter(place: .region("Bretagne"))
            .apply(to: festivals, now: try Date("2026-11-25T12:00:00+01:00", strategy: .iso8601), calendar: paris)

        #expect(Set(breton.map(\.id)) == ["vieilles-charrues", "trans-musicales"])
    }
}
