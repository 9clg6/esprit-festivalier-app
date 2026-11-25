import Foundation
import Testing
import EFDomain
import EFData

// STORY-011 on the demo data: E2 groups the mock festivals by month of start.
// The expectation is derived from the mock data, so it survives a change of the demo.

@Test func theDemoFestivalsAreGroupedIntoOneSectionPerUpcomingStartMonth() async throws {
    var paris = Calendar(identifier: .gregorian)
    paris.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
    paris.locale = Locale(identifier: "fr_FR")
    let now = try Date("2026-11-25T12:00:00+01:00", strategy: .iso8601)

    let festivals = try await MockFestivalSource().festivals(updatedSince: nil)
    let upcoming = festivals.filter { $0.endDate >= now }
    try #require(!upcoming.isEmpty, "the demo has no upcoming festival")
    let startMonths = Set(upcoming.map { paris.dateComponents([.year, .month], from: $0.startDate) })

    let sections = FestivalList.sections(from: festivals, now: now, calendar: paris)

    #expect(sections.count == startMonths.count)
    #expect(sections.flatMap(\.festivals).map(\.id).sorted() == upcoming.map(\.id).sorted())
}
