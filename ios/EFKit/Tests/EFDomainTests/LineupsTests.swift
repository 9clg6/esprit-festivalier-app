import Foundation
import Testing
import EFDomain

// STORY-017, UX E7 "Programmations" and E8 "Artiste", parcours P3.
// Need (E7): a list of cards, newest announcement first; each card shows the festival, the
// announcement date, the first 5 artists and "+ 19" for the rest. Only festivals still to come
// (or in progress): a finished festival's lineup is no longer news. Data referring to an unknown
// festival or artist is skipped, never a crash; a lineup with no known artist is dropped.
// Need (E8): the artist's "En festival" list = the upcoming festivals whose lineup has the artist,
// soonest first. An unknown artist has none.
// "now" is explicit. A festival is finished when it ended before `now` (as in FestivalList).
//
// Assumed API (EFDomain):
//   struct LineupAnnouncement: Sendable, Hashable, Identifiable (id = festival.id)
//     let festival: Festival
//     let announcedOn: Date
//     let artistNames: [String]   // the first 5 known artists, lineup order
//     let remainingCount: Int     // the other known artists ("+ 19"); 0 when none
//   enum Lineups
//     static func feed(lineups: [Lineup], festivals: [Festival], artists: [Artist], now: Date) -> [LineupAnnouncement]
//     static func upcomingFestivals(of artistId: Artist.ID, lineups: [Lineup], festivals: [Festival], now: Date) -> [Festival]

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

/// Wednesday 25 November 2026, noon in Paris.
private let now = date("2026-11-25T12:00:00+01:00")

private func festival(
    _ id: String, from start: String = "2027-06-17T00:00:00+02:00", to end: String = "2027-06-20T23:59:00+02:00"
) -> Festival {
    Festival(
        id: id, name: id, city: "Rennes", latitude: 48.11, longitude: -1.68,
        startDate: date(start), endDate: date(end),
        website: URL(string: "https://example.org")!, description: ""
    )
}

private func lineup(_ festivalId: String, on day: String = "2026-11-20T10:00:00Z", _ artistIds: [String]) -> Lineup {
    Lineup(festivalId: festivalId, announcedOn: date(day), artistIds: artistIds)
}

/// Artists "a1" ... "a30", named "Artist 1" ... "Artist 30".
private let artists = (1...30).map { Artist(id: "a\($0)", name: "Artist \($0)") }
private func artistIds(_ range: ClosedRange<Int>) -> [String] { range.map { "a\($0)" } }

private func feed(_ lineups: [Lineup], _ festivals: [Festival], at now: Date = now) -> [LineupAnnouncement] {
    Lineups.feed(lineups: lineups, festivals: festivals, artists: artists, now: now)
}

@Suite struct LineupsFeedTests {
    @Test func noLineupGivesAnEmptyFeed() {
        #expect(feed([], [festival("hellfest")]).isEmpty)
        #expect(Lineups.feed(lineups: [], festivals: [], artists: [], now: now).isEmpty)
    }

    @Test func theNewestAnnouncementComesFirst() {
        let festivals = [festival("old"), festival("newest"), festival("middle")]
        let lineups = [
            lineup("old", on: "2026-10-01T10:00:00Z", ["a1"]),
            lineup("newest", on: "2026-11-24T10:00:00Z", ["a1"]),
            lineup("middle", on: "2026-11-02T10:00:00Z", ["a1"])
        ]

        #expect(feed(lineups, festivals).map(\.festival.id) == ["newest", "middle", "old"])
    }

    @Test func lineupsAnnouncedTheSameDayShowTheSoonestFestivalFirst() {
        let festivals = [
            festival("july", from: "2027-07-10T00:00:00+02:00", to: "2027-07-14T23:59:00+02:00"),
            festival("june", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")
        ]
        let lineups = [lineup("july", on: "2026-11-25T00:00:00Z", ["a1"]), lineup("june", on: "2026-11-25T00:00:00Z", ["a1"])]

        #expect(feed(lineups, festivals).map(\.festival.id) == ["june", "july"])
    }

    @Test func aCardShowsTheFestivalAndItsAnnouncementDate() throws {
        let hellfest = festival("hellfest")

        let card = try #require(feed([lineup("hellfest", on: "2026-11-24T10:00:00Z", ["a1"])], [hellfest]).first)

        #expect(card.festival == hellfest)
        #expect(card.announcedOn == date("2026-11-24T10:00:00Z"))
    }

    @Test func aCardShowsTheFirstFiveArtistsInLineupOrderAndCountsTheRest() throws {
        // 24 artists: 5 names and "+ 19".
        let card = try #require(feed([lineup("hellfest", artistIds(1...24))], [festival("hellfest")]).first)

        #expect(card.artistNames == ["Artist 1", "Artist 2", "Artist 3", "Artist 4", "Artist 5"])
        #expect(card.remainingCount == 19)
    }

    @Test func aLineupOfFiveArtistsShowsThemAllWithNothingLeft() throws {
        let card = try #require(feed([lineup("hellfest", artistIds(1...5))], [festival("hellfest")]).first)

        #expect(card.artistNames.count == 5)
        #expect(card.remainingCount == 0)
    }

    @Test func aShortLineupShowsWhatItHas() throws {
        let card = try #require(feed([lineup("hellfest", ["a7", "a2"])], [festival("hellfest")]).first)

        #expect(card.artistNames == ["Artist 7", "Artist 2"])
        #expect(card.remainingCount == 0)
    }

    @Test func theLineupOfAFinishedFestivalIsNotShown() {
        let festivals = [
            festival("finished", from: "2026-11-20T00:00:00+01:00", to: "2026-11-22T23:59:00+01:00"),
            festival("coming")
        ]
        let lineups = [lineup("finished", ["a1"]), lineup("coming", ["a1"])]

        #expect(feed(lineups, festivals).map(\.festival.id) == ["coming"])
    }

    @Test func theLineupOfAFestivalInProgressIsShown() {
        let inProgress = festival("now", from: "2026-11-24T00:00:00+01:00", to: "2026-11-26T23:59:00+01:00")

        #expect(feed([lineup("now", ["a1"])], [inProgress]).map(\.festival.id) == ["now"])
    }

    @Test func aLineupOfAnUnknownFestivalIsSkipped() {
        let lineups = [lineup("ghost", on: "2026-11-24T10:00:00Z", ["a1"]), lineup("hellfest", ["a1"])]

        #expect(feed(lineups, [festival("hellfest")]).map(\.festival.id) == ["hellfest"])
    }

    @Test func unknownArtistsAreLeftOutOfTheNamesAndTheCount() throws {
        let ids = ["ghost1", "a1", "a2", "ghost2", "a3", "a4", "a5", "a6", "ghost3"]

        let card = try #require(feed([lineup("hellfest", ids)], [festival("hellfest")]).first)

        #expect(card.artistNames == ["Artist 1", "Artist 2", "Artist 3", "Artist 4", "Artist 5"])
        #expect(card.remainingCount == 1)
    }

    @Test func aLineupWhoseArtistsAreAllUnknownIsDropped() {
        let lineups = [lineup("ghosts", on: "2026-11-24T10:00:00Z", ["ghost1", "ghost2"]), lineup("hellfest", ["a1"])]

        #expect(feed(lineups, [festival("ghosts"), festival("hellfest")]).map(\.festival.id) == ["hellfest"])
    }
}

@Suite struct ArtistFestivalsTests {
    private func upcoming(_ artistId: String, _ lineups: [Lineup], _ festivals: [Festival]) -> [String] {
        Lineups.upcomingFestivals(of: artistId, lineups: lineups, festivals: festivals, now: now).map(\.id)
    }

    @Test func theArtistsUpcomingFestivalsComeSoonestFirst() {
        let festivals = [
            festival("july", from: "2027-07-10T00:00:00+02:00", to: "2027-07-14T23:59:00+02:00"),
            festival("december", from: "2026-12-02T00:00:00+01:00", to: "2026-12-06T23:59:00+01:00"),
            festival("june", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")
        ]
        let lineups = [lineup("july", ["a1", "a2"]), lineup("december", ["a3", "a1"]), lineup("june", ["a1"])]

        #expect(upcoming("a1", lineups, festivals) == ["december", "june", "july"])
    }

    @Test func festivalsWithoutTheArtistAreNotListed() {
        let festivals = [festival("with"), festival("without")]
        let lineups = [lineup("with", ["a1", "a2"]), lineup("without", ["a2", "a3"])]

        #expect(upcoming("a1", lineups, festivals) == ["with"])
    }

    @Test func aFinishedFestivalIsNotListed() {
        let festivals = [
            festival("finished", from: "2026-11-20T00:00:00+01:00", to: "2026-11-22T23:59:00+01:00"),
            festival("coming")
        ]
        let lineups = [lineup("finished", ["a1"]), lineup("coming", ["a1"])]

        #expect(upcoming("a1", lineups, festivals) == ["coming"])
    }

    @Test func aFestivalInProgressIsListed() {
        let inProgress = festival("now", from: "2026-11-24T00:00:00+01:00", to: "2026-11-26T23:59:00+01:00")

        #expect(upcoming("a1", [lineup("now", ["a1"])], [inProgress]) == ["now"])
    }

    @Test func anUnknownArtistHasNoFestival() {
        #expect(upcoming("nobody", [lineup("hellfest", ["a1"])], [festival("hellfest")]).isEmpty)
    }

    @Test func aLineupOfAnUnknownFestivalIsSkipped() {
        #expect(upcoming("a1", [lineup("ghost", ["a1"]), lineup("hellfest", ["a1"])], [festival("hellfest")]) == ["hellfest"])
    }

    @Test func noDataGivesNoFestival() {
        #expect(upcoming("a1", [], []).isEmpty)
    }
}
