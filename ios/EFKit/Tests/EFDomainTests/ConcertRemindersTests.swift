import Foundation
import Testing
import EFDomain

// STORY-020 "Rappels de concerts" (UX P2 step 4, E6; architecture: notifications, iOS keeps at most
// 64 pending local notifications, so the 64 nearest are scheduled again at each app opening).
// Pure planning, no network, no UserNotifications.
// Assumed API (EFDomain):
//   enum ReminderLead: Int, CaseIterable { case five = 5, ten = 10, fifteen = 15, thirty = 30 }
//     static let `default`: ReminderLead  (.fifteen)
//   struct ConcertReminder: Hashable { id: String; performanceId: Performance.ID; fireDate: Date; body: String }
//   enum ConcertReminders {
//     static let limit: Int  (64)
//     static func plan(picks: [Performance], stageNames: [Stage.ID: String], artistNames: [Artist.ID: String],
//                      lead: ReminderLead = .default, now: Date, limit: Int = ConcertReminders.limit)
//       -> [ConcertReminder]
//   }
// Decisions specified here:
// - fire date = start - lead; only fire dates strictly after `now` (a set starting in 10 min gets no
//   15-min reminder: the moment has passed);
// - at most `limit`, the earliest fire dates kept, result sorted by fire date;
// - identifier depends on the performance id only: same id -> same identifier whatever the start
//   time or the lead (rescheduling replaces, never duplicates); two performances -> two identifiers;
// - body: "<Artiste> sur la scène <Scène> dans <lead> min".

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private let now = date("2027-07-02T18:00:00+02:00")

private func concert(_ id: String, starts start: Date, stage: Stage.ID = "grande-scene") -> Performance {
    Performance(id: id, festivalId: "fest", stageId: stage, artistId: id, start: start, end: start + 3600)
}

private func concert(_ id: String, startsInMinutes minutes: Double) -> Performance {
    concert(id, starts: now + minutes * 60)
}

private func plan(
    _ picks: [Performance], lead: ReminderLead = .fifteen, at now: Date = now, limit: Int = 64
) -> [ConcertReminder] {
    ConcertReminders.plan(
        picks: picks, stageNames: ["grande-scene": "Grande Scène", "chapiteau": "Chapiteau"],
        artistNames: Dictionary(uniqueKeysWithValues: picks.map { ($0.artistId, "Artiste \($0.artistId)") }),
        lead: lead, now: now, limit: limit
    )
}

@Suite struct ReminderLeadTests {
    @Test func theLeadCanBeFiveTenFifteenOrThirtyMinutes() {
        #expect(ReminderLead.allCases.map(\.rawValue) == [5, 10, 15, 30])
    }

    @Test func theDefaultLeadIsFifteenMinutes() {
        #expect(ReminderLead.default == .fifteen)
    }

    @Test func theDefaultCapIsTheIOSLimitOf64() {
        #expect(ConcertReminders.limit == 64)
    }
}

@Suite struct ConcertRemindersPlanTests {
    @Test func noPickGivesNoReminder() {
        #expect(plan([]).isEmpty)
    }

    @Test func aReminderFiresFifteenMinutesBeforeByDefault() {
        let start = date("2027-07-02T21:00:00+02:00")

        let reminders = ConcertReminders.plan(
            picks: [concert("artist-y", starts: start)], stageNames: ["grande-scene": "Grande Scène"],
            artistNames: ["artist-y": "Artiste Y"], now: now
        )

        #expect(reminders.map(\.fireDate) == [date("2027-07-02T20:45:00+02:00")])
    }

    @Test(arguments: ReminderLead.allCases)
    func theFireDateFollowsTheChosenLead(lead: ReminderLead) {
        let start = date("2027-07-02T21:00:00+02:00")

        let reminders = plan([concert("artist-y", starts: start)], lead: lead)

        #expect(reminders.map(\.fireDate) == [start - Double(lead.rawValue) * 60])
    }

    @Test func theBodyNamesTheArtistTheStageAndTheLead() {
        let reminders = ConcertReminders.plan(
            picks: [concert("artist-y", starts: date("2027-07-02T21:00:00+02:00"), stage: "chapiteau")],
            stageNames: ["chapiteau": "Chapiteau"], artistNames: ["artist-y": "Artiste Y"], now: now
        )

        #expect(reminders.map(\.body) == ["Artiste Y sur la scène Chapiteau dans 15 min"])
    }

    @Test func theBodySaysTheChosenLead() {
        let reminders = plan([concert("artist-y", startsInMinutes: 120)], lead: .five)

        #expect(reminders.map(\.body) == ["Artiste artist-y sur la scène Grande Scène dans 5 min"])
    }

    @Test func aReminderKnowsItsPerformance() {
        #expect(plan([concert("artist-y", startsInMinutes: 120)]).map(\.performanceId) == ["artist-y"])
    }

    @Test func aPastConcertGetsNoReminder() {
        #expect(plan([concert("over", startsInMinutes: -60)]).isEmpty)
    }

    @Test func aConcertStartingSoonerThanTheLeadGetsNoReminder() {
        #expect(plan([concert("soon", startsInMinutes: 10)], lead: .fifteen).isEmpty)
    }

    @Test func aFireDateExactlyNowIsNotScheduled() {
        #expect(plan([concert("now", startsInMinutes: 15)], lead: .fifteen).isEmpty)
    }

    @Test func aFireDateOneSecondAheadIsScheduled() {
        let start = now + 15 * 60 + 1

        #expect(plan([concert("just", starts: start)], lead: .fifteen).map(\.performanceId) == ["just"])
    }

    @Test func remindersComeByFireDate() {
        let reminders = plan([
            concert("third", startsInMinutes: 300),
            concert("first", startsInMinutes: 60),
            concert("second", startsInMinutes: 120)
        ])

        #expect(reminders.map(\.performanceId) == ["first", "second", "third"])
    }
}

@Suite struct ConcertRemindersCapTests {
    private let seventy = (1...70).reversed().map { concert("set-\($0)", startsInMinutes: Double($0) * 60) }

    @Test func atMost64RemindersAreScheduled() {
        #expect(plan(seventy).count == 64)
    }

    @Test func theNearest64AreKept() {
        let kept = plan(seventy).map(\.performanceId)

        #expect(kept == (1...64).map { "set-\($0)" })
    }

    @Test func pastConcertsDoNotTakeAPlaceUnderTheCap() {
        let past = (1...10).map { concert("past-\($0)", startsInMinutes: Double(-$0) * 60) }
        let future = (1...64).map { concert("future-\($0)", startsInMinutes: Double($0) * 60) }

        let kept = plan(past + future)

        #expect(kept.count == 64)
        #expect(kept.allSatisfy { $0.performanceId.hasPrefix("future-") })
    }

    @Test func theCapCanBeLowered() {
        #expect(plan(seventy, limit: 3).map(\.performanceId) == ["set-1", "set-2", "set-3"])
    }

    @Test func reopeningLaterSchedulesTheNextOnes() {
        let later = now + 10 * 3600 + 60

        let kept = plan(seventy, at: later).map(\.performanceId)

        #expect(kept.first == "set-11")
        #expect(kept.count == 60)
    }
}

@Suite struct ConcertRemindersIdentifierTests {
    @Test func planningTwiceGivesTheSameReminders() {
        let picks = [concert("artist-a", startsInMinutes: 60), concert("artist-b", startsInMinutes: 120)]

        #expect(plan(picks) == plan(picks))
    }

    @Test func twoPerformancesGetTwoIdentifiers() {
        let reminders = plan([concert("artist-a", startsInMinutes: 60), concert("artist-b", startsInMinutes: 60)])

        #expect(Set(reminders.map(\.id)).count == 2)
    }

    @Test func aChangedStartTimeMovesTheFireDateButKeepsTheIdentifier() throws {
        let before = try #require(plan([concert("artist-a", startsInMinutes: 60)]).first)
        let after = try #require(plan([concert("artist-a", startsInMinutes: 90)]).first)

        #expect(after.id == before.id)
        #expect(after.fireDate == before.fireDate + 30 * 60)
    }

    @Test func aChangedLeadKeepsTheIdentifier() throws {
        let fifteen = try #require(plan([concert("artist-a", startsInMinutes: 60)], lead: .fifteen).first)
        let thirty = try #require(plan([concert("artist-a", startsInMinutes: 60)], lead: .thirty).first)

        #expect(thirty.id == fifteen.id)
    }
}
