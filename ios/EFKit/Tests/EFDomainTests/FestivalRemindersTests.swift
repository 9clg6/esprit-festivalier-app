import Foundation
import Testing
import EFDomain

// STORY-025 / FR-010 "Notifications des favoris", mock-first: no server push. J-7 and J-1 reminders
// are planned on the device as local notifications, next to the concert reminders (STORY-020).
// Need:
// - for each favorite festival, a J-7 and a J-1 notification at 10:00 Paris time, counted in
//   calendar days from the festival's first day in the caller's calendar (fr_FR, Europe/Paris),
//   so a daylight-saving change between the two does not move the hour;
// - only fire dates strictly after `now`;
// - stable identifiers per festival and kind: "fav-<id>-j7", "fav-<id>-j1" (planning again replaces);
// - French text: "Hellfest commence dans 7 jours", "Hellfest commence demain !";
// - each kind can be switched off in the Profil (NotificationPreferences.festivalJ7 / festivalJ1);
// - result sorted by fire date.
//
// Assumed API (EFDomain):
//   enum FestivalReminderKind: String, CaseIterable, Sendable { case j7, j1 }
//   struct FestivalReminder: Sendable, Hashable {
//     id: String; festivalId: Festival.ID; kind: FestivalReminderKind; fireDate: Date; body: String }
//   enum FestivalReminders {
//     static let identifierPrefix: String  ("fav-")
//     static func plan(favorites: [Festival], preferences: NotificationPreferences, now: Date,
//                      calendar: Calendar) -> [FestivalReminder]
//   }

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

/// Wednesday 25 November 2026, noon in Paris.
private let now = date("2026-11-25T12:00:00+01:00")

private func festival(_ id: String, name: String? = nil, starts start: String) -> Festival {
    let startDate = date(start)
    return Festival(
        id: id, name: name ?? id, city: "Clisson", latitude: 47.09, longitude: -1.28,
        startDate: startDate, endDate: startDate + 3 * 86400,
        website: URL(string: "https://example.org")!, description: ""
    )
}

private let hellfest = festival("hellfest", name: "Hellfest", starts: "2027-06-17T00:00:00+02:00")

private func plan(
    _ favorites: [Festival], preferences: NotificationPreferences = NotificationPreferences(), at now: Date = now
) -> [FestivalReminder] {
    FestivalReminders.plan(favorites: favorites, preferences: preferences, now: now, calendar: paris)
}

@Suite struct FestivalRemindersPlanTests {
    @Test func noFavoriteGivesNoReminder() {
        #expect(plan([]).isEmpty)
    }

    @Test func aFavoriteGetsAJ7AndAJ1Reminder() {
        #expect(plan([hellfest]).map(\.kind) == [.j7, .j1])
    }

    @Test func theJ7ReminderFiresSevenDaysBeforeAt10ParisTime() throws {
        let j7 = try #require(plan([hellfest]).first { $0.kind == .j7 })

        #expect(j7.fireDate == date("2027-06-10T10:00:00+02:00"))
    }

    @Test func theJ1ReminderFiresTheDayBeforeAt10ParisTime() throws {
        let j1 = try #require(plan([hellfest]).first { $0.kind == .j1 })

        #expect(j1.fireDate == date("2027-06-16T10:00:00+02:00"))
    }

    @Test func theHourDoesNotDependOnTheFestivalStartTime() {
        let evening = festival("evening", starts: "2027-06-17T18:30:00+02:00")

        #expect(plan([evening]).map(\.fireDate) == [
            date("2027-06-10T10:00:00+02:00"), date("2027-06-16T10:00:00+02:00")
        ])
    }

    @Test func aDaylightSavingChangeDoesNotMoveTheHour() {
        // Summer time starts on Sunday 28 March 2027: J-7 is in winter time, the start in summer time.
        let spring = festival("spring", starts: "2027-03-31T00:00:00+02:00")

        #expect(plan([spring]).map(\.fireDate) == [
            date("2027-03-24T10:00:00+01:00"), date("2027-03-30T10:00:00+02:00")
        ])
    }

    @Test func theJ7BodySaysSevenDays() throws {
        let j7 = try #require(plan([hellfest]).first { $0.kind == .j7 })

        #expect(j7.body == "Hellfest commence dans 7 jours")
    }

    @Test func theJ1BodySaysTomorrow() throws {
        let j1 = try #require(plan([hellfest]).first { $0.kind == .j1 })

        #expect(j1.body == "Hellfest commence demain !")
    }

    @Test func aReminderKnowsItsFestival() {
        #expect(plan([hellfest]).map(\.festivalId) == ["hellfest", "hellfest"])
    }

    @Test func remindersComeByFireDateAcrossFestivals() {
        let early = festival("early", starts: "2027-06-02T00:00:00+02:00")
        let late = festival("late", starts: "2027-07-01T00:00:00+02:00")

        let ids = plan([late, early, hellfest]).map(\.id)

        #expect(ids == [
            "fav-early-j7", "fav-early-j1", "fav-hellfest-j7", "fav-hellfest-j1", "fav-late-j7", "fav-late-j1"
        ])
    }

    @Test func closeFestivalsInterleaveTheirReminders() {
        // J-7 of Hellfest (10 June) comes before J-1 of a festival starting on 12 June (11 June).
        let close = festival("close", starts: "2027-06-12T00:00:00+02:00")

        let ids = plan([hellfest, close]).map(\.id)

        #expect(ids == ["fav-close-j7", "fav-hellfest-j7", "fav-close-j1", "fav-hellfest-j1"])
    }
}

@Suite struct FestivalRemindersFutureOnlyTests {
    @Test func aFestivalInThreeDaysOnlyGetsItsJ1Reminder() {
        let soon = festival("soon", starts: "2026-11-28T00:00:00+01:00")

        #expect(plan([soon]).map(\.kind) == [.j1])
    }

    @Test func aFestivalTomorrowAfter10GetsNoReminder() {
        // J-1 was today at 10:00, two hours ago.
        let tomorrow = festival("tomorrow", starts: "2026-11-26T00:00:00+01:00")

        #expect(plan([tomorrow]).isEmpty)
    }

    @Test func aFestivalTomorrowBefore10StillGetsItsJ1Reminder() {
        let tomorrow = festival("tomorrow", starts: "2026-11-26T00:00:00+01:00")

        let reminders = plan([tomorrow], at: date("2026-11-25T09:59:00+01:00"))

        #expect(reminders.map(\.fireDate) == [date("2026-11-25T10:00:00+01:00")])
    }

    @Test func aFireDateExactlyNowIsNotScheduled() {
        let tomorrow = festival("tomorrow", starts: "2026-11-26T00:00:00+01:00")

        #expect(plan([tomorrow], at: date("2026-11-25T10:00:00+01:00")).isEmpty)
    }

    @Test func aFestivalAlreadyStartedGetsNoReminder() {
        let started = festival("started", starts: "2026-11-24T00:00:00+01:00")

        #expect(plan([started]).isEmpty)
    }
}

@Suite struct FestivalRemindersToggleTests {
    @Test func j7OffKeepsOnlyJ1() {
        let reminders = plan([hellfest], preferences: NotificationPreferences(festivalJ7: false))

        #expect(reminders.map(\.kind) == [.j1])
    }

    @Test func j1OffKeepsOnlyJ7() {
        let reminders = plan([hellfest], preferences: NotificationPreferences(festivalJ1: false))

        #expect(reminders.map(\.kind) == [.j7])
    }

    @Test func bothOffGivesNoReminder() {
        let reminders = plan([hellfest], preferences: NotificationPreferences(festivalJ7: false, festivalJ1: false))

        #expect(reminders.isEmpty)
    }

    @Test func articleCategoriesDoNotChangeFestivalReminders() {
        let none = NotificationPreferences(articleCategories: [])

        #expect(plan([hellfest], preferences: none) == plan([hellfest]))
    }
}

@Suite struct FestivalRemindersIdentifierTests {
    @Test func identifiersAreFavIdAndKind() {
        #expect(plan([hellfest]).map(\.id) == ["fav-hellfest-j7", "fav-hellfest-j1"])
    }

    @Test func everyIdentifierStartsWithThePrefix() {
        #expect(FestivalReminders.identifierPrefix == "fav-")
        #expect(plan([hellfest]).allSatisfy { $0.id.hasPrefix(FestivalReminders.identifierPrefix) })
    }

    @Test func thePrefixIsNotTheConcertOne() {
        #expect(!FestivalReminders.identifierPrefix.hasPrefix(ConcertReminders.identifierPrefix))
        #expect(!ConcertReminders.identifierPrefix.hasPrefix(FestivalReminders.identifierPrefix))
    }

    @Test func planningTwiceGivesTheSameReminders() {
        #expect(plan([hellfest]) == plan([hellfest]))
    }

    @Test func aMovedFestivalKeepsItsIdentifiers() {
        let moved = festival("hellfest", name: "Hellfest", starts: "2027-06-24T00:00:00+02:00")

        #expect(plan([moved]).map(\.id) == plan([hellfest]).map(\.id))
        #expect(plan([moved]).map(\.fireDate) == [
            date("2027-06-17T10:00:00+02:00"), date("2027-06-23T10:00:00+02:00")
        ])
    }
}
