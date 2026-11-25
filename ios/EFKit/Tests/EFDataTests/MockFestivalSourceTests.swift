import Foundation
import Testing
import EFDomain
import EFData

// STORY-003: the mock sources read JSON bundled in EFData and hold
// 5 complete demo festivals (dates, lineup, timetable).

private let festivalSource: any FestivalSource = MockFestivalSource()
private let artistSource: any ArtistSource = MockArtistSource()

// Each helper requires data, so that no test passes on an empty demo.
private func demoFestivals() async throws -> [Festival] {
    let festivals = try await festivalSource.festivals(updatedSince: nil)
    try #require(!festivals.isEmpty, "the demo has no festival")
    return festivals
}

private func demoDetails() async throws -> [FestivalDetail] {
    var details: [FestivalDetail] = []
    for festival in try await demoFestivals() {
        let detail = try await festivalSource.festival(id: festival.id)
        try #require(!detail.performances.isEmpty, "\(festival.id) has no performance")
        details.append(detail)
    }
    return details
}

@Suite struct MockFestivalSourceTests {
    @Test func theDemoHoldsFiveFestivalsWithDistinctIds() async throws {
        let festivals = try await demoFestivals()

        #expect(festivals.count == 5)
        #expect(Set(festivals.map(\.id)).count == festivals.count)
    }

    @Test func everyDemoFestivalHasANameAndACity() async throws {
        for festival in try await demoFestivals() {
            #expect(!festival.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(festival.id)")
            #expect(!festival.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(festival.id)")
        }
    }

    @Test func everyDemoFestivalIsLocatedInMetropolitanFrance() async throws {
        // Bounding box of metropolitan France, Corsica included.
        let latitudes = 41.3...51.1
        let longitudes = -5.2...9.6
        for festival in try await demoFestivals() {
            #expect(latitudes.contains(festival.latitude), "\(festival.id) latitude \(festival.latitude)")
            #expect(longitudes.contains(festival.longitude), "\(festival.id) longitude \(festival.longitude)")
        }
    }

    @Test func noDemoFestivalEndsBeforeItStarts() async throws {
        for festival in try await demoFestivals() {
            #expect(festival.startDate <= festival.endDate, "\(festival.id)")
        }
    }

    @Test func aKnownIdGivesTheDetailOfThatFestival() async throws {
        for festival in try await demoFestivals() {
            let detail = try await festivalSource.festival(id: festival.id)
            #expect(detail.festival.id == festival.id)
            #expect(detail.festival.name == festival.name)
        }
    }

    @Test func anUnknownIdThrows() async {
        await #expect(throws: (any Error).self) {
            _ = try await festivalSource.festival(id: "no-such-festival")
        }
    }

    @Test func everyDemoFestivalHasATimetable() async throws {
        for detail in try await demoDetails() {
            #expect(!detail.stages.isEmpty, "\(detail.festival.id) has no stage")
            #expect(!detail.performances.isEmpty, "\(detail.festival.id) has no performance")
        }
    }

    @Test func everyStageBelongsToItsFestival() async throws {
        for detail in try await demoDetails() {
            for stage in detail.stages {
                #expect(stage.festivalId == detail.festival.id, "stage \(stage.id)")
            }
        }
    }

    @Test func everyPerformanceTakesPlaceOnAStageOfItsFestival() async throws {
        for detail in try await demoDetails() {
            let stageIds = Set(detail.stages.map(\.id))
            for performance in detail.performances {
                #expect(performance.festivalId == detail.festival.id, "performance \(performance.id)")
                #expect(stageIds.contains(performance.stageId), "performance \(performance.id) on unknown stage")
            }
        }
    }

    @Test func everyPerformanceIsGivenByAKnownArtist() async throws {
        let wanted = try await demoDetails().flatMap { $0.performances.map(\.artistId) }
        let known = Set(try await artistSource.artists(ids: Array(Set(wanted))).map(\.id))

        for artistId in wanted {
            #expect(known.contains(artistId), "unknown artist \(artistId)")
        }
    }

    @Test func noPerformanceEndsBeforeItStarts() async throws {
        for detail in try await demoDetails() {
            for performance in detail.performances {
                #expect(performance.start <= performance.end, "performance \(performance.id)")
            }
        }
    }
}

@Suite struct MockArtistSourceTests {
    @Test func askingForSomeArtistsReturnsThoseArtistsOnly() async throws {
        let performers = try await demoDetails().flatMap { $0.performances.map(\.artistId) }
        let asked = Array(Set(performers).prefix(2))
        try #require(asked.count == 2)

        let artists = try await artistSource.artists(ids: asked)

        #expect(Set(artists.map(\.id)) == Set(asked))
    }
}
