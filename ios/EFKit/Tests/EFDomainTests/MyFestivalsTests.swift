import Foundation
import Testing
import EFDomain

// STORY-018, E9 "Mes festivals" (UX principle 1 "Le jour J d'abord").
// Decisions specified here:
// - finished = ended before `now` (a festival ending exactly now is not finished, as in FestivalList);
// - "Prochain": at most one favorite, in progress or starting within 48 h (start <= now + 48 h);
//   among several candidates, the earliest start wins (then name); the others go to "À venir";
// - label: started -> "En cours"; otherwise by calendar day of the start in the caller's calendar:
//   same day -> "Aujourd'hui", next day -> "Demain", the day after -> "Après-demain"
//   (48 h can reach the day after tomorrow: now Mon 23:00, start Wed 10:00);
// - "À venir": the other non-finished favorites, by start then name;
// - "Passés": finished favorites, most recent end first, then name;
// - empty state only when there is no favorite at all.

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private func festival(_ name: String, from start: String, to end: String) -> Festival {
    Festival(
        id: name, name: name, city: "Rennes", latitude: 48.11, longitude: -1.68,
        startDate: date(start), endDate: date(end),
        website: URL(string: "https://example.org")!, description: ""
    )
}

/// Wednesday 25 November 2026, noon in Paris.
private let now = date("2026-11-25T12:00:00+01:00")

private func sections(_ favorites: [Festival], at now: Date = now) -> MyFestivalsSections {
    MyFestivals.sections(favorites: favorites, now: now, calendar: paris)
}

@Suite struct MyFestivalsEmptyStateTests {
    @Test func noFavoriteShowsTheEmptyState() {
        let result = sections([])

        #expect(result.isEmpty)
        #expect(result.next == nil)
        #expect(result.upcoming.isEmpty)
        #expect(result.past.isEmpty)
    }

    @Test func onlyPastFavoritesIsNotTheEmptyState() {
        let result = sections([festival("Old", from: "2026-07-01T00:00:00+02:00", to: "2026-07-03T23:59:00+02:00")])

        #expect(!result.isEmpty)
        #expect(result.past.map(\.name) == ["Old"])
    }

    @Test func onlyFarFavoritesIsNotTheEmptyState() {
        let result = sections([festival("Far", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")])

        #expect(!result.isEmpty)
        #expect(result.next == nil)
        #expect(result.upcoming.map(\.name) == ["Far"])
    }
}

@Suite struct MyFestivalsNextTests {
    @Test func aFestivalInProgressIsNextAndLabelledEnCours() {
        let result = sections([festival("Running", from: "2026-11-24T18:00:00+01:00", to: "2026-11-27T23:59:00+01:00")])

        #expect(result.next?.festival.name == "Running")
        #expect(result.next?.when == .inProgress)
        #expect(result.upcoming.isEmpty)
    }

    @Test func aFestivalStartingExactlyNowIsInProgress() {
        let result = sections([festival("Now", from: "2026-11-25T12:00:00+01:00", to: "2026-11-25T23:00:00+01:00")])

        #expect(result.next?.when == .inProgress)
    }

    @Test func aFestivalEndingExactlyNowIsStillInProgress() {
        let result = sections([festival("Last minute", from: "2026-11-24T12:00:00+01:00", to: "2026-11-25T12:00:00+01:00")])

        #expect(result.next?.festival.name == "Last minute")
        #expect(result.next?.when == .inProgress)
        #expect(result.past.isEmpty)
    }

    @Test func aFestivalStartingLaterTodayIsLabelledAujourdhui() {
        let result = sections([festival("Tonight", from: "2026-11-25T20:00:00+01:00", to: "2026-11-26T02:00:00+01:00")])

        #expect(result.next?.festival.name == "Tonight")
        #expect(result.next?.when == .today)
    }

    @Test func aFestivalStartingTomorrowIsLabelledDemain() {
        let result = sections([festival("Tomorrow", from: "2026-11-26T18:00:00+01:00", to: "2026-11-28T23:59:00+01:00")])

        #expect(result.next?.festival.name == "Tomorrow")
        #expect(result.next?.when == .tomorrow)
    }

    @Test func justAfterMidnightInParisIsTomorrowEvenWithinAnHour() {
        let lateEvening = date("2026-11-25T23:30:00+01:00")
        let result = sections(
            [festival("Early", from: "2026-11-26T00:30:00+01:00", to: "2026-11-26T06:00:00+01:00")], at: lateEvening
        )

        #expect(result.next?.when == .tomorrow)
    }

    @Test func theDayAfterTomorrowWithin48HoursIsLabelledApresDemain() {
        let lateEvening = date("2026-11-25T23:00:00+01:00")
        let result = sections(
            [festival("Friday", from: "2026-11-27T10:00:00+01:00", to: "2026-11-29T23:59:00+01:00")], at: lateEvening
        )

        #expect(result.next?.festival.name == "Friday")
        #expect(result.next?.when == .dayAfterTomorrow)
    }

    @Test func aFestivalStartingExactlyIn48HoursIsNext() {
        let result = sections([festival("Edge", from: "2026-11-27T12:00:00+01:00", to: "2026-11-28T12:00:00+01:00")])

        #expect(result.next?.festival.name == "Edge")
        #expect(result.next?.when == .dayAfterTomorrow)
    }

    @Test func aFestivalStartingJustAfter48HoursIsOnlyUpcoming() {
        let result = sections([festival("Later", from: "2026-11-27T12:00:01+01:00", to: "2026-11-28T12:00:00+01:00")])

        #expect(result.next == nil)
        #expect(result.upcoming.map(\.name) == ["Later"])
    }

    @Test func atMostOneNextTheEarliestStartTheOthersAreUpcoming() {
        let result = sections([
            festival("Tomorrow", from: "2026-11-26T18:00:00+01:00", to: "2026-11-28T23:59:00+01:00"),
            festival("Running", from: "2026-11-24T18:00:00+01:00", to: "2026-11-27T23:59:00+01:00"),
            festival("Tonight", from: "2026-11-25T20:00:00+01:00", to: "2026-11-26T02:00:00+01:00")
        ])

        #expect(result.next?.festival.name == "Running")
        #expect(result.upcoming.map(\.name) == ["Tonight", "Tomorrow"])
    }

    @Test func twoCandidatesStartingTogetherAreDecidedByName() {
        let result = sections([
            festival("Zebra", from: "2026-11-26T18:00:00+01:00", to: "2026-11-27T23:59:00+01:00"),
            festival("Alpha", from: "2026-11-26T18:00:00+01:00", to: "2026-11-27T23:59:00+01:00")
        ])

        #expect(result.next?.festival.name == "Alpha")
        #expect(result.upcoming.map(\.name) == ["Zebra"])
    }

    @Test func theNextFestivalIsNotRepeatedInUpcoming() {
        let result = sections([festival("Tomorrow", from: "2026-11-26T18:00:00+01:00", to: "2026-11-28T23:59:00+01:00")])

        #expect(result.upcoming.isEmpty)
        #expect(result.past.isEmpty)
    }

    @Test func labelsReadInFrench() {
        #expect(NextFestival.When.inProgress.title == "En cours")
        #expect(NextFestival.When.today.title == "Aujourd'hui")
        #expect(NextFestival.When.tomorrow.title == "Demain")
        #expect(NextFestival.When.dayAfterTomorrow.title == "Après-demain")
    }
}

@Suite struct MyFestivalsUpcomingAndPastTests {
    @Test func upcomingAreSortedByStartThenName() {
        let result = sections([
            festival("Trans", from: "2026-12-02T00:00:00+01:00", to: "2026-12-06T23:59:00+01:00"),
            festival("Hellfest", from: "2027-06-18T00:00:00+02:00", to: "2027-06-21T23:59:00+02:00"),
            festival("Charrues", from: "2027-07-15T00:00:00+02:00", to: "2027-07-18T23:59:00+02:00"),
            festival("Bravo", from: "2027-06-18T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")
        ])

        #expect(result.next == nil)
        #expect(result.upcoming.map(\.name) == ["Trans", "Bravo", "Hellfest", "Charrues"])
    }

    @Test func aFestivalThatEndedBeforeNowIsPast() {
        let result = sections([festival("Ended", from: "2026-11-20T00:00:00+01:00", to: "2026-11-25T11:59:59+01:00")])

        #expect(result.next == nil)
        #expect(result.upcoming.isEmpty)
        #expect(result.past.map(\.name) == ["Ended"])
    }

    @Test func pastAreMostRecentFirstThenName() {
        let result = sections([
            festival("July", from: "2026-07-01T00:00:00+02:00", to: "2026-07-03T23:59:00+02:00"),
            festival("October", from: "2026-10-01T00:00:00+02:00", to: "2026-10-04T23:59:00+02:00"),
            festival("Beta", from: "2026-08-01T00:00:00+02:00", to: "2026-08-10T23:59:00+02:00"),
            festival("Alpha", from: "2026-08-05T00:00:00+02:00", to: "2026-08-10T23:59:00+02:00")
        ])

        #expect(result.past.map(\.name) == ["October", "Alpha", "Beta", "July"])
    }

    @Test func everyFavoriteLandsInExactlyOneSection() {
        let favorites = [
            festival("Past", from: "2026-07-01T00:00:00+02:00", to: "2026-07-03T23:59:00+02:00"),
            festival("Running", from: "2026-11-24T18:00:00+01:00", to: "2026-11-27T23:59:00+01:00"),
            festival("Tomorrow", from: "2026-11-26T18:00:00+01:00", to: "2026-11-28T23:59:00+01:00"),
            festival("Far", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")
        ]
        let result = sections(favorites)
        let placed = [result.next?.festival].compactMap { $0 } + result.upcoming + result.past

        #expect(placed.map(\.name).sorted() == favorites.map(\.name).sorted())
        #expect(result.next?.festival.name == "Running")
        #expect(result.upcoming.map(\.name) == ["Tomorrow", "Far"])
        #expect(result.past.map(\.name) == ["Past"])
    }
}
