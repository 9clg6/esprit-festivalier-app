import Foundation
import Testing
import EFDomain

// Period specs of FestivalFilter (this weekend, this month, chosen dates); fixtures live in FestivalFilterTests.swift.

@Suite struct FestivalFilterPeriodTests: FestivalFilterFixtures {
    // MARK: This weekend (Friday 00:00 → Sunday 23:59, Paris)

    @Test func onAWeekdayThisWeekendIsTheComingOne() {
        // Wednesday 25 November 2026 → Friday 27 to Sunday 29 November.
        let all = [
            festival("endsThursday", from: "2026-11-24T00:00:00+01:00", to: "2026-11-26T23:59:00+01:00"),
            festival("fridayMorning", from: "2026-11-27T00:30:00+01:00", to: "2026-11-27T03:00:00+01:00"),
            festival("sundayNight", from: "2026-11-29T23:00:00+01:00", to: "2026-11-30T02:00:00+01:00"),
            festival("monday", from: "2026-11-30T00:30:00+01:00", to: "2026-11-30T23:00:00+01:00"),
            festival("nextWeekend", from: "2026-12-04T00:00:00+01:00", to: "2026-12-06T23:59:00+01:00")
        ]

        #expect(ids(period(.thisWeekend), all) == ["fridayMorning", "sundayNight"])
    }

    @Test func aFestivalSpanningTheWholeWeekendMatches() {
        let all = [festival("long", from: "2026-11-20T00:00:00+01:00", to: "2026-12-10T23:59:00+01:00")]

        #expect(ids(period(.thisWeekend), all) == ["long"])
    }

    @Test func onMondayThisWeekendIsTheNextOne() {
        let monday = date("2026-11-30T00:30:00+01:00")
        let all = [
            festival("past", from: "2026-11-28T00:00:00+01:00", to: "2026-11-29T23:00:00+01:00"),
            festival("coming", from: "2026-12-05T00:00:00+01:00", to: "2026-12-05T23:00:00+01:00")
        ]

        #expect(ids(period(.thisWeekend), all, now: monday) == ["coming"])
    }

    @Test func lateOnThursdayInParisThisWeekendIsTheComingOne() {
        // Thursday 26 November 23:30 in Paris.
        let thursdayNight = date("2026-11-26T23:30:00+01:00")
        let all = [
            festival("coming", from: "2026-11-28T12:00:00+01:00", to: "2026-11-28T23:00:00+01:00"),
            festival("following", from: "2026-12-05T12:00:00+01:00", to: "2026-12-05T23:00:00+01:00")
        ]

        #expect(ids(period(.thisWeekend), all, now: thursdayNight) == ["coming"])
    }

    @Test(arguments: [
        "2026-11-27T00:00:00+01:00", // Friday, first minute
        "2026-11-28T15:00:00+01:00", // Saturday
        "2026-11-29T23:30:00+01:00" // Sunday, late
    ])
    func fromFridayToSundayThisWeekendIsTheCurrentOne(_ now: String) {
        let all = [
            festival("current", from: "2026-11-27T18:00:00+01:00", to: "2026-11-29T23:59:00+01:00"),
            festival("following", from: "2026-12-04T18:00:00+01:00", to: "2026-12-06T20:00:00+01:00")
        ]

        #expect(ids(period(.thisWeekend), all, now: date(now)) == ["current"])
    }

    @Test func theWeekendOfTheClockChangeEndsOnSundayNightInParis() {
        // Summer time starts on Sunday 28 March 2027; the weekend is Friday 26 → Sunday 28.
        let thursday = date("2027-03-25T12:00:00+01:00")
        let all = [
            festival("sundayNight", from: "2027-03-28T23:00:00+02:00", to: "2027-03-28T23:50:00+02:00"),
            festival("monday", from: "2027-03-29T00:30:00+02:00", to: "2027-03-29T02:00:00+02:00")
        ]

        #expect(ids(period(.thisWeekend), all, now: thursday) == ["sundayNight"])
    }

    // Regression: the weekend ends at Monday 00:00, excluded. A festival starting then is next week's.
    @Test func aFestivalStartingAtMondayMidnightIsNotThisWeekend() {
        let all = [festival("mondayMidnight", from: "2026-11-30T00:00:00+01:00", to: "2026-11-30T23:00:00+01:00")]

        #expect(ids(period(.thisWeekend), all).isEmpty)
    }

    @Test func festivalsEndingOnSundayNightOrAtMondayMidnightAreThisWeekend() {
        let all = [
            festival("endsSunday2359", from: "2026-11-29T20:00:00+01:00", to: "2026-11-29T23:59:00+01:00"),
            festival("endsMondayMidnight", from: "2026-11-29T22:00:00+01:00", to: "2026-11-30T00:00:00+01:00")
        ]

        #expect(ids(period(.thisWeekend), all) == ["endsSunday2359", "endsMondayMidnight"])
    }

    // MARK: This month (Paris calendar month)

    @Test func thisMonthKeepsTheFestivalsOverlappingTheCurrentMonth() {
        let all = [
            festival("startedInOctober", from: "2026-10-30T00:00:00+01:00", to: "2026-11-02T23:59:00+01:00"),
            festival("endsOnTheLastDay", from: "2026-11-30T20:00:00+01:00", to: "2026-12-02T23:59:00+01:00"),
            festival("october", from: "2026-10-20T00:00:00+02:00", to: "2026-10-22T23:59:00+02:00"),
            // 1 December 00:30 in Paris is still 30 November in UTC.
            festival("december", from: "2026-12-01T00:30:00+01:00", to: "2026-12-03T23:59:00+01:00"),
            festival("nextNovember", from: "2027-11-10T00:00:00+01:00", to: "2027-11-12T23:59:00+01:00")
        ]

        #expect(ids(period(.thisMonth), all) == ["startedInOctober", "endsOnTheLastDay"])
    }

    // Regression: the month ends at the 1st of next month 00:00, excluded. A festival starting then is next month's.
    @Test func aFestivalStartingOnTheFirstOfNextMonthAtMidnightIsNotThisMonth() {
        let all = [festival("decemberMidnight", from: "2026-12-01T00:00:00+01:00", to: "2026-12-03T23:59:00+01:00")]

        #expect(ids(period(.thisMonth), all).isEmpty)
    }

    @Test func festivalsEndingAtTheMonthsLastSecondOrStartedOnItsLastDayAreThisMonth() {
        let all = [
            festival("endsLastSecond", from: "2026-11-28T00:00:00+01:00", to: "2026-11-30T23:59:59+01:00"),
            festival("startsLastDay", from: "2026-11-30T23:00:00+01:00", to: "2026-12-01T02:00:00+01:00")
        ]

        #expect(ids(period(.thisMonth), all) == ["endsLastSecond", "startsLastDay"])
    }

    // MARK: Chosen dates

    @Test func chosenDatesKeepTheFestivalsOverlappingTheInterval() {
        let interval = DateInterval(start: date("2027-07-01T00:00:00+02:00"), end: date("2027-07-10T23:59:00+02:00"))
        let all = [
            festival("before", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00"),
            festival("straddlesStart", from: "2027-06-29T00:00:00+02:00", to: "2027-07-02T23:59:00+02:00"),
            festival("inside", from: "2027-07-04T00:00:00+02:00", to: "2027-07-05T23:59:00+02:00"),
            festival("straddlesEnd", from: "2027-07-10T12:00:00+02:00", to: "2027-07-14T23:59:00+02:00"),
            festival("after", from: "2027-07-15T00:00:00+02:00", to: "2027-07-18T23:59:00+02:00")
        ]

        #expect(ids(period(.dates(interval)), all) == ["straddlesStart", "inside", "straddlesEnd"])
    }

    // The sheet passes an interval ending at 23:59:59 of the last chosen day: that second is included.
    @Test func chosenDatesIncludeAFestivalStartingAtTheLastSecondOfTheLastDay() {
        let interval = DateInterval(start: date("2027-07-01T00:00:00+02:00"), end: date("2027-07-10T23:59:59+02:00"))
        let all = [festival("lastSecond", from: "2027-07-10T23:59:59+02:00", to: "2027-07-11T03:00:00+02:00")]

        #expect(ids(period(.dates(interval)), all) == ["lastSecond"])
    }

    @Test func chosenDatesExcludeAFestivalStartingAtMidnightAfterTheLastDay() {
        let interval = DateInterval(start: date("2027-07-01T00:00:00+02:00"), end: date("2027-07-10T23:59:59+02:00"))
        let all = [festival("nextDay", from: "2027-07-11T00:00:00+02:00", to: "2027-07-11T23:00:00+02:00")]

        #expect(ids(period(.dates(interval)), all).isEmpty)
    }
}
