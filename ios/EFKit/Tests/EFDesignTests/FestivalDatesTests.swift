import Foundation
import Testing
import EFDesign

// E2 FestivalRow and E5 header: "13–15 juin 2027 · Rennes". One text for row and detail,
// always fr_FR, Europe/Paris, whatever the device settings.
// Format (Foundation's fr_FR interval, kept as is):
//   same month   "17–20 juin 2027"                          (en dash, no spaces)
//   two months   "30 juin – 2 juillet 2027"                 (thin spaces U+2009 around the en dash)
//   two years    "30 décembre 2027 – 2 janvier 2028"
//   one day      "17 juin 2027"

private let thin = "\u{2009}"

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private func text(_ start: String, _ end: String) -> String {
    FestivalDates.text(from: date(start), to: date(end))
}

@Suite struct FestivalDatesTests {
    @Test func daysOfOneMonthShareTheMonthAndYear() {
        #expect(text("2027-06-17T00:00:00+02:00", "2027-06-20T23:59:00+02:00") == "17–20 juin 2027")
    }

    @Test func twoMonthsOfOneYearShareTheYear() {
        #expect(text("2027-06-30T00:00:00+02:00", "2027-07-02T23:59:00+02:00")
            == "30 juin\(thin)–\(thin)2 juillet 2027")
    }

    @Test func twoYearsAreBothWritten() {
        #expect(text("2027-12-30T00:00:00+01:00", "2028-01-02T23:59:00+01:00")
            == "30 décembre 2027\(thin)–\(thin)2 janvier 2028")
    }

    @Test func aOneDayFestivalShowsOneDate() {
        #expect(text("2027-06-17T00:00:00+02:00", "2027-06-17T23:59:00+02:00") == "17 juin 2027")
    }

    @Test func daysAreTheOnesOfParisNotOfUTC() {
        // 22:30 UTC on 30 June is 00:30 on 1 July in Paris.
        #expect(text("2027-06-30T22:30:00Z", "2027-07-02T21:59:00Z") == "1–2 juillet 2027")
    }

    @Test func anEndBeforeTheStartShowsTheStartDay() {
        #expect(text("2027-06-17T00:00:00+02:00", "2027-06-15T23:59:00+02:00") == "17 juin 2027")
    }
}
