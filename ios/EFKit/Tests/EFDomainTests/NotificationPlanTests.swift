import Foundation
import Testing
import EFDomain

// STORY-020 + STORY-025: concert reminders and favorite festival reminders share the iOS limit of
// 64 pending local notifications. Need: given both planned lists, keep the 64 earliest fire dates
// overall, whatever their kind; each list stays sorted by fire date.
//
// Assumed API (EFDomain):
//   struct NotificationPlan: Sendable, Hashable {
//     let concerts: [ConcertReminder]
//     let festivals: [FestivalReminder]
//     static func earliest(concerts: [ConcertReminder], festivals: [FestivalReminder],
//                          limit: Int = ConcertReminders.limit) -> NotificationPlan
//   }
//   (ConcertReminder and FestivalReminder get public memberwise initializers.)

private let now = try! Date("2027-06-01T12:00:00+02:00", strategy: .iso8601)

private func concert(_ id: String, inHours hours: Double) -> ConcertReminder {
    ConcertReminder(id: "concert-\(id)", performanceId: id, fireDate: now + hours * 3600, body: "")
}

private func festival(_ id: String, inHours hours: Double) -> FestivalReminder {
    FestivalReminder(id: "fav-\(id)-j1", festivalId: id, kind: .j1, fireDate: now + hours * 3600, body: "")
}

@Suite struct NotificationPlanTests {
    @Test func nothingPlannedGivesAnEmptyPlan() {
        let plan = NotificationPlan.earliest(concerts: [], festivals: [])

        #expect(plan.concerts.isEmpty)
        #expect(plan.festivals.isEmpty)
    }

    @Test func underTheCapEverythingIsKept() {
        let concerts = [concert("a", inHours: 1), concert("b", inHours: 2)]
        let festivals = [festival("x", inHours: 3)]

        let plan = NotificationPlan.earliest(concerts: concerts, festivals: festivals)

        #expect(plan.concerts == concerts)
        #expect(plan.festivals == festivals)
    }

    @Test func theDefaultCapIs64Overall() {
        let concerts = (1...40).map { concert("c\($0)", inHours: Double($0)) }
        let festivals = (1...40).map { festival("f\($0)", inHours: Double($0) + 0.5) }

        let plan = NotificationPlan.earliest(concerts: concerts, festivals: festivals)

        #expect(plan.concerts.count + plan.festivals.count == 64)
    }

    @Test func theEarliestAreKeptWhateverTheirKind() {
        // Concerts at 1 h ... 70 h, festivals at 0.5 h, 30.5 h, 100 h, 200 h: 74 planned, 64 kept.
        let concerts = (1...70).map { concert("c\($0)", inHours: Double($0)) }
        let festivals = [
            festival("f1", inHours: 0.5), festival("f2", inHours: 30.5),
            festival("f3", inHours: 100), festival("f4", inHours: 200)
        ]

        let plan = NotificationPlan.earliest(concerts: concerts, festivals: festivals)

        #expect(plan.festivals.map(\.festivalId) == ["f1", "f2"])
        #expect(plan.concerts.map(\.performanceId) == (1...62).map { "c\($0)" })
    }

    @Test func aFullConcertListGivesWayToAnEarlierFestivalReminder() {
        let concerts = (1...64).map { concert("c\($0)", inHours: Double($0)) }
        let festivals = [festival("hellfest", inHours: 0.5)]

        let plan = NotificationPlan.earliest(concerts: concerts, festivals: festivals)

        #expect(plan.festivals.map(\.festivalId) == ["hellfest"])
        #expect(plan.concerts.map(\.performanceId) == (1...63).map { "c\($0)" })
    }

    @Test func aLaterFestivalReminderDoesNotPushOutConcerts() {
        let concerts = (1...64).map { concert("c\($0)", inHours: Double($0)) }
        let festivals = [festival("hellfest", inHours: 100)]

        let plan = NotificationPlan.earliest(concerts: concerts, festivals: festivals)

        #expect(plan.festivals.isEmpty)
        #expect(plan.concerts.count == 64)
    }

    @Test func unsortedInputComesOutSortedByFireDate() {
        let plan = NotificationPlan.earliest(
            concerts: [concert("late", inHours: 5), concert("early", inHours: 1)],
            festivals: [festival("late", inHours: 6), festival("early", inHours: 2)]
        )

        #expect(plan.concerts.map(\.performanceId) == ["early", "late"])
        #expect(plan.festivals.map(\.festivalId) == ["early", "late"])
    }

    @Test func theCapCanBeLowered() {
        let plan = NotificationPlan.earliest(
            concerts: [concert("a", inHours: 1), concert("b", inHours: 3)],
            festivals: [festival("x", inHours: 2), festival("y", inHours: 4)],
            limit: 2
        )

        #expect(plan.concerts.map(\.performanceId) == ["a"])
        #expect(plan.festivals.map(\.festivalId) == ["x"])
    }

    @Test func aZeroCapKeepsNothing() {
        let plan = NotificationPlan.earliest(
            concerts: [concert("a", inHours: 1)], festivals: [festival("x", inHours: 2)], limit: 0
        )

        #expect(plan.concerts.isEmpty)
        #expect(plan.festivals.isEmpty)
    }
}
