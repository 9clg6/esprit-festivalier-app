import Foundation
import Testing
import EFDomain
import EFData

// STORY-019 on the demo data ("mock first"): UX P2 step 3 shows "2 concerts en même temps", so at
// least one demo festival has two sets on different stages that overlap, and one set after
// midnight that the timetable files under the previous evening. Uses the Timetable of EFDomain.

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func demoTimetables() async throws -> [Timetable] {
    let source = MockFestivalSource()
    var timetables: [Timetable] = []
    for festival in try await source.festivals(updatedSince: nil) {
        timetables.append(Timetable(try await source.festival(id: festival.id), calendar: paris))
    }
    return timetables
}

@Suite struct MockTimetableTests {
    @Test func aDemoFestivalHasTwoOverlappingSetsOnDifferentStages() async throws {
        let withConflict = try await demoTimetables().filter { timetable in
            let all = Set(timetable.days.flatMap { $0.stages.flatMap(\.performances) }.map(\.id))
            return timetable.conflicts(in: all).values.contains { !$0.isEmpty }
        }

        #expect(!withConflict.isEmpty)
    }

    @Test func aDemoFestivalHasASetAfterMidnight() async throws {
        let late = try await demoTimetables().flatMap { timetable in
            timetable.days.flatMap { day in
                day.stages.flatMap(\.performances).filter { paris.component(.hour, from: $0.start) < 6 }
            }
        }

        #expect(!late.isEmpty)
    }
}
