import Foundation
import Testing
import EFDomain

// STORY-019 "Timetable et conflits" (UX E6, P2 step 3; PerformanceCell "maintenant", "conflit").
// Assumed API (EFDomain):
//   Timetable(_ detail: FestivalDetail, calendar: Calendar)
//   .days: [TimetableDay]                      TimetableDay { date: Date; stages: [TimetableStage] }
//                                              TimetableStage { stage: Stage; performances: [Performance] }
//   .conflicts(in picks: Set<Performance.ID>) -> [Performance.ID: [Performance]]
//   .nowPlaying(at now: Date) -> [Performance]
// Decisions specified here:
// - a festival day runs from 06:00 to 06:00 the next morning (calendar given by the caller): a set
//   starting at 01:30 or 05:59 belongs to the previous day, one at 06:00 opens a new day;
//   `TimetableDay.date` is the midnight that starts that calendar day;
// - days in order; inside a day, stages in the festival's order (`detail.stages`), a stage with
//   nothing that day is left out; sets by start;
// - conflict = two picked sets on different stages whose times overlap; end == start is not a
//   conflict; same stage is never a conflict; overlap is by time, even across a 06:00 day boundary;
//   a picked set without conflict has no entry (or an empty one); the others are sorted by start;
// - now playing: start <= now < end, every stage, in start order.

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private let mainStage = Stage(id: "grande-scene", festivalId: "fest", name: "Grande Scène")
private let tentStage = Stage(id: "chapiteau", festivalId: "fest", name: "Chapiteau")
private let clubStage = Stage(id: "club", festivalId: "fest", name: "Club")

/// Times are Paris summer time (+02:00).
private func set(_ id: String, on stage: Stage, _ start: String, _ end: String) -> Performance {
    Performance(
        id: id, festivalId: "fest", stageId: stage.id, artistId: id,
        start: date(start + ":00+02:00"), end: date(end + ":00+02:00")
    )
}

private func timetable(_ performances: [Performance], stages: [Stage] = [mainStage, tentStage, clubStage]) -> Timetable {
    let festival = Festival(
        id: "fest", name: "Fest", city: "Rennes", latitude: 48.11, longitude: -1.68,
        startDate: date("2027-07-02T00:00:00+02:00"), endDate: date("2027-07-04T23:59:00+02:00"),
        website: URL(string: "https://example.org")!, description: ""
    )
    return Timetable(FestivalDetail(festival: festival, stages: stages, performances: performances), calendar: paris)
}

private func conflictIDs(_ result: [Performance.ID: [Performance]], for id: Performance.ID) -> [Performance.ID] {
    (result[id] ?? []).map(\.id)
}

@Suite struct TimetableDaysTests {
    @Test func noPerformanceGivesNoDay() {
        #expect(timetable([]).days.isEmpty)
    }

    @Test func setsAreGroupedByDayInOrder() {
        let days = timetable([
            set("sat", on: mainStage, "2027-07-03T20:00", "2027-07-03T21:00"),
            set("fri", on: mainStage, "2027-07-02T20:00", "2027-07-02T21:00")
        ]).days

        #expect(days.map(\.date) == [date("2027-07-02T00:00:00+02:00"), date("2027-07-03T00:00:00+02:00")])
        #expect(days.map { $0.stages.flatMap(\.performances).map(\.id) } == [["fri"], ["sat"]])
    }

    @Test func aSetAtHalfPastOneBelongsToThePreviousDay() {
        let days = timetable([
            set("evening", on: mainStage, "2027-07-02T22:00", "2027-07-02T23:30"),
            set("late", on: tentStage, "2027-07-03T01:30", "2027-07-03T03:00")
        ]).days

        #expect(days.count == 1)
        #expect(days.first?.date == date("2027-07-02T00:00:00+02:00"))
        #expect(days.first?.stages.flatMap(\.performances).map(\.id).sorted() == ["evening", "late"])
    }

    @Test func aSetAtFiveFiftyNineStillBelongsToThePreviousDay() {
        let days = timetable([set("dawn", on: clubStage, "2027-07-03T05:59", "2027-07-03T07:00")]).days

        #expect(days.map(\.date) == [date("2027-07-02T00:00:00+02:00")])
    }

    @Test func aSetAtSixOpensANewDay() {
        let days = timetable([
            set("night", on: clubStage, "2027-07-03T04:00", "2027-07-03T05:30"),
            set("morning", on: clubStage, "2027-07-03T06:00", "2027-07-03T07:00")
        ]).days

        #expect(days.map(\.date) == [date("2027-07-02T00:00:00+02:00"), date("2027-07-03T00:00:00+02:00")])
        #expect(days.last?.stages.flatMap(\.performances).map(\.id) == ["morning"])
    }

    @Test func stagesFollowTheFestivalOrderAndEmptyOnesAreLeftOut() {
        let days = timetable([
            set("club-act", on: clubStage, "2027-07-02T19:00", "2027-07-02T20:00"),
            set("main-act", on: mainStage, "2027-07-02T21:00", "2027-07-02T22:00")
        ]).days

        #expect(days.count == 1)
        #expect(days.first?.stages.map(\.stage) == [mainStage, clubStage])
    }

    @Test func setsOnAStageAreSortedByStartAcrossMidnight() {
        let days = timetable([
            set("after-midnight", on: mainStage, "2027-07-03T00:30", "2027-07-03T01:30"),
            set("late", on: mainStage, "2027-07-02T23:00", "2027-07-03T00:15"),
            set("early", on: mainStage, "2027-07-02T19:00", "2027-07-02T20:00")
        ]).days

        #expect(days.first?.stages.first?.performances.map(\.id) == ["early", "late", "after-midnight"])
    }
}

@Suite struct TimetableConflictTests {
    private let artistB = set("artist-b", on: mainStage, "2027-07-02T20:30", "2027-07-02T21:30")
    private let artistD = set("artist-d", on: tentStage, "2027-07-02T20:45", "2027-07-02T22:00")

    @Test func twoPickedSetsThatOverlapOnTwoStagesConflictBothWays() {
        let result = timetable([artistB, artistD]).conflicts(in: ["artist-b", "artist-d"])

        #expect(conflictIDs(result, for: "artist-b") == ["artist-d"])
        #expect(conflictIDs(result, for: "artist-d") == ["artist-b"])
    }

    @Test func noPickGivesNoConflict() {
        let result = timetable([artistB, artistD]).conflicts(in: [])

        #expect(result.values.allSatisfy { $0.isEmpty })
    }

    @Test func anOverlappingSetThatIsNotPickedIsNoConflict() {
        let result = timetable([artistB, artistD]).conflicts(in: ["artist-b"])

        #expect(conflictIDs(result, for: "artist-b").isEmpty)
        #expect(conflictIDs(result, for: "artist-d").isEmpty)
    }

    @Test func aSetEndingWhenTheOtherStartsIsNoConflict() {
        let first = set("first", on: mainStage, "2027-07-02T20:00", "2027-07-02T21:00")
        let second = set("second", on: tentStage, "2027-07-02T21:00", "2027-07-02T22:00")

        let result = timetable([first, second]).conflicts(in: ["first", "second"])

        #expect(conflictIDs(result, for: "first").isEmpty)
        #expect(conflictIDs(result, for: "second").isEmpty)
    }

    @Test func oneMinuteOfOverlapIsAConflict() {
        let first = set("first", on: mainStage, "2027-07-02T20:00", "2027-07-02T21:01")
        let second = set("second", on: tentStage, "2027-07-02T21:00", "2027-07-02T22:00")

        let result = timetable([first, second]).conflicts(in: ["first", "second"])

        #expect(conflictIDs(result, for: "first") == ["second"])
    }

    @Test func aSetInsideAnotherIsAConflict() {
        let long = set("long", on: mainStage, "2027-07-02T19:00", "2027-07-02T23:00")
        let short = set("short", on: tentStage, "2027-07-02T20:00", "2027-07-02T20:30")

        let result = timetable([long, short]).conflicts(in: ["long", "short"])

        #expect(conflictIDs(result, for: "long") == ["short"])
        #expect(conflictIDs(result, for: "short") == ["long"])
    }

    @Test func overlappingSetsOnTheSameStageAreNoConflict() {
        let first = set("first", on: mainStage, "2027-07-02T20:00", "2027-07-02T21:00")
        let second = set("second", on: mainStage, "2027-07-02T20:30", "2027-07-02T21:30")

        let result = timetable([first, second]).conflicts(in: ["first", "second"])

        #expect(conflictIDs(result, for: "first").isEmpty)
        #expect(conflictIDs(result, for: "second").isEmpty)
    }

    @Test func setsCrossingMidnightConflict() {
        let headliner = set("headliner", on: mainStage, "2027-07-02T23:30", "2027-07-03T01:00")
        let dj = set("dj", on: clubStage, "2027-07-03T00:30", "2027-07-03T02:00")

        let result = timetable([headliner, dj]).conflicts(in: ["headliner", "dj"])

        #expect(conflictIDs(result, for: "headliner") == ["dj"])
        #expect(conflictIDs(result, for: "dj") == ["headliner"])
    }

    @Test func aMidnightSetDoesNotConflictWithTheSameHourTheNextEvening() {
        let night = set("night", on: mainStage, "2027-07-02T23:30", "2027-07-03T00:30")
        let nextEvening = set("next-evening", on: tentStage, "2027-07-03T23:30", "2027-07-04T00:30")

        let result = timetable([night, nextEvening]).conflicts(in: ["night", "next-evening"])

        #expect(conflictIDs(result, for: "night").isEmpty)
    }

    @Test func overlapAcrossTheSixOClockBoundaryIsStillAConflict() {
        let closing = set("closing", on: clubStage, "2027-07-03T05:00", "2027-07-03T06:30")
        let sunrise = set("sunrise", on: mainStage, "2027-07-03T06:00", "2027-07-03T07:00")

        let result = timetable([closing, sunrise]).conflicts(in: ["closing", "sunrise"])

        #expect(conflictIDs(result, for: "closing") == ["sunrise"])
    }

    @Test func eachPickedSetListsAllItsConflictsByStart() {
        let long = set("long", on: mainStage, "2027-07-02T20:00", "2027-07-02T23:00")
        let later = set("later", on: clubStage, "2027-07-02T22:00", "2027-07-02T23:00")
        let earlier = set("earlier", on: tentStage, "2027-07-02T20:30", "2027-07-02T21:30")

        let result = timetable([long, later, earlier]).conflicts(in: ["long", "later", "earlier"])

        #expect(conflictIDs(result, for: "long") == ["earlier", "later"])
        #expect(conflictIDs(result, for: "earlier") == ["long"])
        #expect(conflictIDs(result, for: "later") == ["long"])
    }

    @Test func aPickedIDThatIsNotInTheTimetableIsIgnored() {
        let result = timetable([artistB, artistD]).conflicts(in: ["artist-b", "elsewhere"])

        #expect(conflictIDs(result, for: "artist-b").isEmpty)
        #expect(conflictIDs(result, for: "elsewhere").isEmpty)
    }
}

@Suite struct TimetableNowPlayingTests {
    private let early = set("early", on: mainStage, "2027-07-02T20:00", "2027-07-02T21:00")
    private let overlapping = set("overlapping", on: tentStage, "2027-07-02T20:30", "2027-07-02T21:30")
    private let late = set("late", on: clubStage, "2027-07-02T23:30", "2027-07-03T01:00")

    private var festival: Timetable { timetable([late, overlapping, early]) }

    @Test func nothingPlaysBeforeTheFirstSet() {
        #expect(festival.nowPlaying(at: date("2027-07-02T19:59:00+02:00")).isEmpty)
    }

    @Test func aSetPlaysFromItsStart() {
        #expect(festival.nowPlaying(at: date("2027-07-02T20:00:00+02:00")).map(\.id) == ["early"])
    }

    @Test func aSetNoLongerPlaysAtItsEnd() {
        #expect(festival.nowPlaying(at: date("2027-07-02T21:00:00+02:00")).map(\.id) == ["overlapping"])
    }

    @Test func setsOnSeveralStagesPlayTogetherInStartOrder() {
        #expect(festival.nowPlaying(at: date("2027-07-02T20:45:00+02:00")).map(\.id) == ["early", "overlapping"])
    }

    @Test func aSetCrossingMidnightPlaysAfterMidnight() {
        #expect(festival.nowPlaying(at: date("2027-07-03T00:30:00+02:00")).map(\.id) == ["late"])
    }

    @Test func nothingPlaysBetweenSets() {
        #expect(festival.nowPlaying(at: date("2027-07-02T22:00:00+02:00")).isEmpty)
    }
}
