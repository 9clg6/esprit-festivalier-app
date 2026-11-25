import Foundation
import Testing
import EFDomain

// STORY-011, E2 "Festivals (liste)": the upcoming festivals, month by month.
// - a festival that ended before `now` is hidden; one in progress stays;
// - sorted by start date, then by name;
// - one section per month of start date, in order, titled like "JUIN 2027".
// Months and titles follow the calendar given by the caller (here fr_FR, Europe/Paris).

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

private let now = date("2026-11-25T12:00:00+01:00")

private func sections(_ festivals: [Festival], at now: Date = now) -> [FestivalListSection] {
    FestivalList.sections(from: festivals, now: now, calendar: paris)
}

@Suite struct FestivalListTests {
    @Test func noFestivalGivesNoSection() {
        #expect(sections([]).isEmpty)
    }

    @Test func onlyPastFestivalsGiveNoSection() {
        let past = [
            festival("Old", from: "2026-07-01T00:00:00+02:00", to: "2026-07-03T23:59:00+02:00"),
            festival("Yesterday", from: "2026-11-20T00:00:00+01:00", to: "2026-11-24T23:59:00+01:00")
        ]

        #expect(sections(past).isEmpty)
    }

    @Test func aFestivalThatEndedBeforeNowIsHidden() {
        let list = sections([
            festival("Ended", from: "2026-11-01T00:00:00+01:00", to: "2026-11-25T11:59:00+01:00"),
            festival("Coming", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00")
        ])

        #expect(list.flatMap(\.festivals).map(\.name) == ["Coming"])
    }

    @Test func aFestivalInProgressIsShownInTheMonthItStarted() {
        let list = sections([
            festival("Running", from: "2026-10-30T00:00:00+01:00", to: "2026-11-30T23:59:00+01:00")
        ])

        #expect(list.map(\.title) == ["OCTOBRE 2026"])
        #expect(list.first?.festivals.map(\.name) == ["Running"])
    }

    @Test func aFestivalEndingExactlyNowIsStillShown() {
        let list = sections([
            festival("Last minute", from: "2026-11-25T00:00:00+01:00", to: "2026-11-25T12:00:00+01:00")
        ])

        #expect(list.flatMap(\.festivals).map(\.name) == ["Last minute"])
    }

    @Test func aFestivalStartingNowIsShown() {
        let list = sections([
            festival("Starting", from: "2026-11-25T12:00:00+01:00", to: "2026-11-27T23:59:00+01:00")
        ])

        #expect(list.flatMap(\.festivals).map(\.name) == ["Starting"])
    }

    @Test func festivalsAreSortedByStartDate() {
        let list = sections([
            festival("Third", from: "2027-06-20T00:00:00+02:00", to: "2027-06-22T23:59:00+02:00"),
            festival("First", from: "2027-06-05T00:00:00+02:00", to: "2027-06-07T23:59:00+02:00"),
            festival("Second", from: "2027-06-13T00:00:00+02:00", to: "2027-06-15T23:59:00+02:00")
        ])

        #expect(list.flatMap(\.festivals).map(\.name) == ["First", "Second", "Third"])
    }

    @Test func festivalsStartingTogetherAreSortedByName() {
        let list = sections([
            festival("Charlie", from: "2027-06-13T00:00:00+02:00", to: "2027-06-15T23:59:00+02:00"),
            festival("Alpha", from: "2027-06-13T00:00:00+02:00", to: "2027-06-14T23:59:00+02:00"),
            festival("Bravo", from: "2027-06-13T00:00:00+02:00", to: "2027-06-16T23:59:00+02:00")
        ])

        #expect(list.flatMap(\.festivals).map(\.name) == ["Alpha", "Bravo", "Charlie"])
    }

    @Test func festivalsAreGroupedByMonthOfStartInChronologicalOrder() {
        let list = sections([
            festival("Trans", from: "2027-12-01T00:00:00+01:00", to: "2027-12-05T23:59:00+01:00"),
            festival("Eurocks", from: "2027-07-02T00:00:00+02:00", to: "2027-07-05T23:59:00+02:00"),
            festival("Hellfest", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00"),
            festival("Charrues", from: "2027-07-15T00:00:00+02:00", to: "2027-07-18T23:59:00+02:00")
        ])

        #expect(list.map(\.title) == ["JUIN 2027", "JUILLET 2027", "DÉCEMBRE 2027"])
        #expect(list.map { $0.festivals.map(\.name) } == [["Hellfest"], ["Eurocks", "Charrues"], ["Trans"]])
    }

    @Test func theSameMonthOfTwoYearsGivesTwoSections() {
        let list = sections([
            festival("Next year", from: "2027-12-03T00:00:00+01:00", to: "2027-12-05T23:59:00+01:00"),
            festival("This year", from: "2026-12-03T00:00:00+01:00", to: "2026-12-05T23:59:00+01:00")
        ])

        #expect(list.map(\.title) == ["DÉCEMBRE 2026", "DÉCEMBRE 2027"])
    }

    @Test func theMonthIsTheOneOfParisNotOfUTC() {
        // 2027-07-01 00:30 in Paris is still 2027-06-30 in UTC.
        let list = sections([
            festival("Midnight", from: "2027-07-01T00:30:00+02:00", to: "2027-07-02T23:59:00+02:00")
        ])

        #expect(list.map(\.title) == ["JUILLET 2027"])
    }

    @Test func monthTitlesAreFrenchUppercaseWithAccents() {
        let list = sections([
            festival("Feb", from: "2027-02-10T00:00:00+01:00", to: "2027-02-11T23:59:00+01:00"),
            festival("Aug", from: "2027-08-10T00:00:00+02:00", to: "2027-08-11T23:59:00+02:00")
        ])

        #expect(list.map(\.title) == ["FÉVRIER 2027", "AOÛT 2027"])
    }

    @Test func everyShownFestivalAppearsOnce() {
        let input = (1...12).map { month in
            festival(
                "F\(month)",
                from: String(format: "2027-%02d-10T00:00:00+01:00", month),
                to: String(format: "2027-%02d-12T23:59:00+01:00", month)
            )
        }

        let list = sections(input)

        #expect(list.count == 12)
        #expect(list.flatMap(\.festivals).map(\.id).sorted() == input.map(\.id).sorted())
        #expect(list.allSatisfy { !$0.festivals.isEmpty })
    }
}
