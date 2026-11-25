import Foundation
import Testing
import EFDomain

// STORY-012 (recherche et filtres) and STORY-013 (autour de moi); UX E2, E3, P1.
// Need:
// - search by name (and by city), case- and accent-insensitive;
// - place: none, a French region, or "autour de moi" with a radius of 25, 50 or 100 km;
// - period: any, "Ce week-end", "Ce mois-ci", or chosen dates; a festival matches when it overlaps;
// - genres: a festival matches when it has at least one selected genre; none selected = no constraint;
// - criteria combine (AND); the result keeps the order it was given (the FestivalList order);
// - the "Filtres · 2" button counts the sheet's criteria (place, period, genres);
//   the search text has its own field and is not counted. Several genres count as one criterion.
// Dates follow the calendar given by the caller (fr_FR, Europe/Paris); "now" is explicit.
//
// Assumed API (EFDomain):
//   struct Coordinate(latitude:longitude:), func kilometers(to: Coordinate) -> Double (great circle)
//   struct FestivalFilter(searchText:place:period:genres:) with defaults "", .anywhere, .any, []
//     enum Place { anywhere, region(String), around(Coordinate, radius: Radius) }
//     enum Radius: Int { km25 = 25, km50 = 50, km100 = 100 }
//     enum Period { any, thisWeekend, thisMonth, dates(DateInterval) }
//     var activeCount: Int
//     func apply(to: [Festival], now: Date, calendar: Calendar) -> [Festival]
//     static func availableGenres(in: [Festival]) -> [String]
//   Festival gains `region: String?` (init argument after `city`, default nil; absent in JSON = nil).

/// Shared by the FestivalFilter suites (members, so they cannot clash with other files' private helpers).
protocol FestivalFilterFixtures {}

extension FestivalFilterFixtures {
    var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.locale = Locale(identifier: "fr_FR")
        return calendar
    }

    func date(_ iso: String) -> Date {
        try! Date(iso, strategy: .iso8601)
    }

    /// Wednesday 25 November 2026, noon in Paris.
    var wednesday: Date { date("2026-11-25T12:00:00+01:00") }

    func festival(
        _ id: String, name: String? = nil, city: String = "Rennes", region: String? = nil,
        latitude: Double = 48.11, longitude: Double = -1.68,
        from start: String = "2027-06-17T00:00:00+02:00", to end: String = "2027-06-20T23:59:00+02:00",
        genres: [String] = []
    ) -> Festival {
        Festival(
            id: id, name: name ?? id, city: city, region: region, latitude: latitude, longitude: longitude,
            startDate: date(start), endDate: date(end),
            website: URL(string: "https://example.org")!, description: "", genres: genres
        )
    }

    func ids(_ filter: FestivalFilter, _ festivals: [Festival], now: Date? = nil) -> [String] {
        filter.apply(to: festivals, now: now ?? wednesday, calendar: paris).map(\.id)
    }

    func period(_ period: FestivalFilter.Period) -> FestivalFilter {
        FestivalFilter(period: period)
    }
}

@Suite struct FestivalFilterTests: FestivalFilterFixtures {
    // MARK: No filter

    @Test func theDefaultFilterKeepsEveryFestival() {
        let all = [festival("a"), festival("b", region: "Bretagne", genres: ["Rock"]), festival("c")]

        #expect(ids(FestivalFilter(), all) == ["a", "b", "c"])
    }

    @Test func noFestivalGivesNoResult() {
        #expect(ids(FestivalFilter(searchText: "hell", period: .thisMonth, genres: ["Rock"]), []).isEmpty)
    }

    // MARK: Search

    @Test func theSearchIgnoresAccentsAndCase() {
        let all = [festival("eurocks", name: "Les Eurockéennes", city: "Belfort"), festival("hellfest", name: "Hellfest")]

        #expect(ids(FestivalFilter(searchText: "eurockeennes"), all) == ["eurocks"])
        #expect(ids(FestivalFilter(searchText: "EUROCKÉENNES"), all) == ["eurocks"])
    }

    @Test func theSearchMatchesPartOfTheName() {
        let all = [festival("charrues", name: "Les Vieilles Charrues", city: "Carhaix-Plouguer"), festival("hellfest", name: "Hellfest", city: "Clisson")]

        #expect(ids(FestivalFilter(searchText: "charr"), all) == ["charrues"])
    }

    @Test func theSearchMatchesTheCity() {
        let all = [
            festival("trans", name: "Les Rencontres Trans Musicales", city: "Rennes"),
            festival("eurocks", name: "Les Eurockéennes", city: "Belfort")
        ]

        #expect(ids(FestivalFilter(searchText: "rennes"), all) == ["trans"])
    }

    @Test func aSearchWithSurroundingSpacesStillMatches() {
        let all = [festival("hellfest", name: "Hellfest", city: "Clisson"), festival("other", name: "Other", city: "Lyon")]

        #expect(ids(FestivalFilter(searchText: "  hellfest "), all) == ["hellfest"])
    }

    @Test func aBlankSearchIsNoConstraint() {
        let all = [festival("a", name: "Alpha"), festival("b", name: "Bravo")]

        #expect(ids(FestivalFilter(searchText: "   "), all) == ["a", "b"])
    }

    @Test func aSearchMatchingNothingGivesNoResult() {
        let all = [festival("hellfest", name: "Hellfest", city: "Clisson")]

        #expect(ids(FestivalFilter(searchText: "jazz à vienne"), all).isEmpty)
    }

    // MARK: Genres

    @Test func aFestivalMatchesWhenItHasOneOfTheSelectedGenres() {
        let all = [
            festival("rock", genres: ["Rock / Metal"]),
            festival("electro", genres: ["Électro", "Pop"]),
            festival("jazz", genres: ["Jazz"]),
            festival("none")
        ]

        #expect(ids(FestivalFilter(genres: ["Électro", "Rock / Metal"]), all) == ["rock", "electro"])
    }

    @Test func noSelectedGenreIsNoConstraint() {
        let all = [festival("rock", genres: ["Rock / Metal"]), festival("none")]

        #expect(ids(FestivalFilter(genres: []), all) == ["rock", "none"])
    }

    // MARK: Region

    @Test func aRegionKeepsOnlyTheFestivalsOfThatRegion() {
        let all = [
            festival("charrues", region: "Bretagne"),
            festival("hellfest", region: "Pays de la Loire"),
            festival("trans", region: "Bretagne"),
            festival("unknown", region: nil)
        ]

        #expect(ids(FestivalFilter(place: .region("Bretagne")), all) == ["charrues", "trans"])
    }

    @Test func aRegionWithNoFestivalGivesNoResult() {
        let all = [festival("charrues", region: "Bretagne")]

        #expect(ids(FestivalFilter(place: .region("Corse")), all).isEmpty)
    }

    // MARK: Around me

    @Test func theRadiusesAre25_50And100Kilometers() {
        #expect(FestivalFilter.Radius.allCases.map(\.rawValue) == [25, 50, 100])
    }

    @Test func aroundMeKeepsTheFestivalsWithinTheRadius() {
        // Along a meridian, 0.2° ≈ 22 km, 0.4° ≈ 44 km, 0.8° ≈ 89 km, 1.0° ≈ 111 km.
        let me = Coordinate(latitude: 47, longitude: -1.5)
        let all = [
            festival("here", latitude: 47, longitude: -1.5),
            festival("22km", latitude: 47.2, longitude: -1.5),
            festival("44km", latitude: 47.4, longitude: -1.5),
            festival("89km", latitude: 47.8, longitude: -1.5),
            festival("111km", latitude: 48.0, longitude: -1.5)
        ]

        #expect(ids(FestivalFilter(place: .around(me, radius: .km25)), all) == ["here", "22km"])
        #expect(ids(FestivalFilter(place: .around(me, radius: .km50)), all) == ["here", "22km", "44km"])
        #expect(ids(FestivalFilter(place: .around(me, radius: .km100)), all) == ["here", "22km", "44km", "89km"])
    }

    @Test func aroundMeIgnoresTheRegion() {
        let me = Coordinate(latitude: 47, longitude: -1.5)
        let all = [festival("near", region: "Bretagne", latitude: 47.1, longitude: -1.5)]

        #expect(ids(FestivalFilter(place: .around(me, radius: .km25)), all) == ["near"])
    }

    // MARK: Combination and order

    @Test func allCriteriaMustMatch() {
        let all = [
            festival("all", name: "Trans", region: "Bretagne", from: "2026-11-27T20:00:00+01:00", to: "2026-11-28T04:00:00+01:00", genres: ["Électro"]),
            festival("wrongGenre", name: "Trans Rock", region: "Bretagne", from: "2026-11-27T20:00:00+01:00", to: "2026-11-28T04:00:00+01:00", genres: ["Rock"]),
            festival("wrongRegion", name: "Trans Sud", region: "Occitanie", from: "2026-11-27T20:00:00+01:00", to: "2026-11-28T04:00:00+01:00", genres: ["Électro"]),
            festival("wrongDate", name: "Trans Hiver", region: "Bretagne", from: "2027-01-15T20:00:00+01:00", to: "2027-01-16T04:00:00+01:00", genres: ["Électro"]),
            festival("wrongName", name: "Astropolis", region: "Bretagne", from: "2026-11-27T20:00:00+01:00", to: "2026-11-28T04:00:00+01:00", genres: ["Électro"])
        ]
        let filter = FestivalFilter(searchText: "trans", place: .region("Bretagne"), period: .thisWeekend, genres: ["Électro"])

        #expect(ids(filter, all) == ["all"])
    }

    @Test func theResultKeepsTheOrderItWasGiven() {
        let all = [festival("c", genres: ["Rock"]), festival("a", genres: ["Rock"]), festival("x"), festival("b", genres: ["Rock"])]

        #expect(ids(FestivalFilter(genres: ["Rock"]), all) == ["c", "a", "b"])
    }

    @Test func theFilteredFestivalsStayGroupedByMonthInTheList() {
        let all = [
            festival("eurocks", from: "2027-07-02T00:00:00+02:00", to: "2027-07-05T23:59:00+02:00", genres: ["Rock"]),
            festival("hellfest", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00", genres: ["Rock"]),
            festival("jazz", from: "2027-06-10T00:00:00+02:00", to: "2027-06-12T23:59:00+02:00", genres: ["Jazz"])
        ]
        let filtered = FestivalFilter(genres: ["Rock"]).apply(to: all, now: wednesday, calendar: paris)

        let sections = FestivalList.sections(from: filtered, now: wednesday, calendar: paris)

        #expect(sections.map(\.title) == ["JUIN 2027", "JUILLET 2027"])
        #expect(sections.map { $0.festivals.map(\.id) } == [["hellfest"], ["eurocks"]])
    }

    // MARK: "Filtres · N"

    @Test func noCriterionCountsZero() {
        #expect(FestivalFilter().activeCount == 0)
    }

    @Test func theSearchTextIsNotCounted() {
        #expect(FestivalFilter(searchText: "hellfest").activeCount == 0)
    }

    @Test(arguments: [
        FestivalFilter(place: .region("Bretagne")),
        FestivalFilter(place: .around(Coordinate(latitude: 47, longitude: -1.5), radius: .km50)),
        FestivalFilter(period: .thisWeekend),
        FestivalFilter(period: .thisMonth),
        FestivalFilter(period: .dates(DateInterval(start: try! Date("2027-07-01T00:00:00+02:00", strategy: .iso8601), duration: 86_400))),
        FestivalFilter(genres: ["Rock / Metal"]),
        FestivalFilter(genres: ["Rock / Metal", "Électro", "Pop"])
    ])
    func eachActiveCriterionCountsOne(_ filter: FestivalFilter) {
        #expect(filter.activeCount == 1)
    }

    @Test func aroundMeAndAGenreCountTwo() {
        let filter = FestivalFilter(place: .around(Coordinate(latitude: 47, longitude: -1.5), radius: .km50), genres: ["Électro"])

        #expect(filter.activeCount == 2)
    }

    @Test func placePeriodAndGenresCountThree() {
        let filter = FestivalFilter(searchText: "rock", place: .region("Bretagne"), period: .thisMonth, genres: ["Rock", "Pop"])

        #expect(filter.activeCount == 3)
    }

    // MARK: Genres offered in the sheet

    @Test func theOfferedGenresAreDistinctAndInFrenchOrder() {
        let all = [
            festival("a", genres: ["Rock", "Électro"]),
            festival("b", genres: ["Pop", "Éclectique", "Rock"]),
            festival("c", genres: ["Jazz", "Electronica"]),
            festival("d")
        ]

        // French collation: É sorts with E, not after Z.
        #expect(FestivalFilter.availableGenres(in: all) == ["Éclectique", "Électro", "Electronica", "Jazz", "Pop", "Rock"])
    }

    @Test func noFestivalOffersNoGenre() {
        #expect(FestivalFilter.availableGenres(in: []).isEmpty)
        #expect(FestivalFilter.availableGenres(in: [festival("none")]).isEmpty)
    }
}
