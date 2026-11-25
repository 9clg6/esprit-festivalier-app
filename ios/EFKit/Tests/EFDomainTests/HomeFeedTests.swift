import Foundation
import Testing
import EFDomain

// STORY-028, UX E1 "Accueil": "À la une", "Programmations", "Ce week-end" (or "Ce mois-ci"),
// "Derniers articles". Goal: show what is new.
// Need:
// - À la une = the newest article; none without article;
// - Programmations = the first 5 cards of the E7 feed (Lineups.feed);
// - Ce week-end = up to 3 festivals still to come that overlap this weekend (FestivalFilter .thisWeekend),
//   soonest first; when there is none, "Ce mois-ci": up to 3 festivals of this month (.thisMonth);
//   the section says which period it shows so the screen picks its title and "Tout voir" its filter;
// - Derniers articles = up to 4 newest articles after the one "À la une", newest first;
// - no data → empty sections, no crash.
// Dates follow the calendar given by the caller (fr_FR, Europe/Paris); "now" is explicit.
//
// Assumed API (EFDomain):
//   struct HomeFeed: Sendable, Hashable
//     let featured: Article?
//     let latestLineups: [LineupAnnouncement]
//     let weekend: [Festival]
//     let weekendPeriod: FestivalFilter.Period   // .thisWeekend, or .thisMonth for the fallback
//     let latestArticles: [Article]
//     static func compose(festivals: [Festival], lineups: [Lineup], artists: [Artist], articles: [Article],
//                         now: Date, calendar: Calendar) -> HomeFeed

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

/// Wednesday 25 November 2026, noon in Paris. This weekend: Friday 27 to Sunday 29 November.
private let wednesday = date("2026-11-25T12:00:00+01:00")

private func festival(_ id: String, from start: String, to end: String) -> Festival {
    Festival(
        id: id, name: id, city: "Rennes", latitude: 48.11, longitude: -1.68,
        startDate: date(start), endDate: date(end),
        website: URL(string: "https://example.org")!, description: ""
    )
}

/// A festival from `day` 00:00 to `lastDay` 23:59 (Paris, winter time).
private func festival(_ id: String, _ day: Int, _ lastDay: Int, month: String = "11") -> Festival {
    festival(
        id, from: "2026-\(month)-\(String(format: "%02d", day))T00:00:00+01:00",
        to: "2026-\(month)-\(String(format: "%02d", lastDay))T23:59:00+01:00"
    )
}

private func article(_ id: String, at iso: String) -> Article {
    Article(
        id: id, title: id, link: URL(string: "https://esprit-festivalier.fr/\(id)")!, category: .actu,
        author: "Rédaction", publishedAt: date(iso), imageURL: nil
    )
}

private func home(
    festivals: [Festival] = [], lineups: [Lineup] = [], artists: [Artist] = [], articles: [Article] = [],
    now: Date = wednesday
) -> HomeFeed {
    HomeFeed.compose(
        festivals: festivals, lineups: lineups, artists: artists, articles: articles, now: now, calendar: paris
    )
}

@Suite struct HomeFeedTests {
    // MARK: Empty

    @Test func noDataGivesEmptySections() {
        let feed = home()

        #expect(feed.featured == nil)
        #expect(feed.latestLineups.isEmpty)
        #expect(feed.weekend.isEmpty)
        #expect(feed.latestArticles.isEmpty)
    }

    // MARK: À la une and Derniers articles

    @Test func theNewestArticleIsFeatured() {
        let articles = [
            article("older", at: "2026-11-24T08:00:00Z"),
            article("newest", at: "2026-11-25T09:00:00Z"),
            article("oldest", at: "2026-11-20T08:00:00Z")
        ]

        #expect(home(articles: articles).featured?.id == "newest")
    }

    @Test func theLatestArticlesAreTheFourNextNewestWithoutTheFeaturedOne() {
        let articles = (1...7).map { article("day\($0)", at: "2026-11-\(String(format: "%02d", 10 + $0))T08:00:00Z") }
            .shuffled()

        let feed = home(articles: articles)

        #expect(feed.featured?.id == "day7")
        #expect(feed.latestArticles.map(\.id) == ["day6", "day5", "day4", "day3"])
    }

    @Test func fewArticlesFillTheLatestArticlesWithWhatIsLeft() {
        let articles = [
            article("a", at: "2026-11-23T08:00:00Z"), article("b", at: "2026-11-25T08:00:00Z"),
            article("c", at: "2026-11-24T08:00:00Z")
        ]

        let feed = home(articles: articles)

        #expect(feed.featured?.id == "b")
        #expect(feed.latestArticles.map(\.id) == ["c", "a"])
    }

    @Test func aSingleArticleIsFeaturedAndLeavesNoLatestArticle() {
        let feed = home(articles: [article("only", at: "2026-11-25T08:00:00Z")])

        #expect(feed.featured?.id == "only")
        #expect(feed.latestArticles.isEmpty)
    }

    // MARK: Programmations

    @Test func theLineupsSectionShowsTheFiveNewestCardsOfTheFeed() {
        let festivals = (1...7).map { festival("f\($0)", from: "2027-06-17T00:00:00+02:00", to: "2027-06-20T23:59:00+02:00") }
        let lineups = (1...7).map {
            Lineup(festivalId: "f\($0)", announcedOn: date("2026-11-\(String(format: "%02d", 10 + $0))T10:00:00Z"), artistIds: ["a"])
        }
        let artists = [Artist(id: "a", name: "Artist")]

        let feed = home(festivals: festivals, lineups: lineups, artists: artists)

        let expected = Lineups.feed(lineups: lineups, festivals: festivals, artists: artists, now: wednesday)
        #expect(feed.latestLineups == Array(expected.prefix(5)))
        #expect(feed.latestLineups.map(\.festival.id) == ["f7", "f6", "f5", "f4", "f3"])
    }

    // MARK: Ce week-end

    @Test func theWeekendSectionShowsTheFestivalsOfThisWeekendSoonestFirst() {
        let festivals = [festival("saturday", 28, 28), festival("thursday", 26, 26), festival("friday", 27, 29)]

        let feed = home(festivals: festivals)

        #expect(feed.weekendPeriod == .thisWeekend)
        #expect(feed.weekend.map(\.id) == ["friday", "saturday"])
    }

    @Test func aFestivalInProgressOverTheWeekendIsShown() {
        let feed = home(festivals: [festival("long", 20, 29)])

        #expect(feed.weekendPeriod == .thisWeekend)
        #expect(feed.weekend.map(\.id) == ["long"])
    }

    @Test func theWeekendSectionShowsAtMostThree() {
        let festivals = [
            festival("sun", 29, 29), festival("sat", 28, 28), festival("fri", 27, 27), festival("fri-sun", 27, 29)
        ]

        let feed = home(festivals: festivals)

        #expect(feed.weekend.count == 3)
        #expect(!feed.weekend.map(\.id).contains("sun"))
    }

    @Test func withoutAFestivalThisWeekendTheSectionFallsBackToThisMonth() {
        let festivals = [
            festival("december", 2, 6, month: "12"),
            festival("monday30", from: "2026-11-30T18:00:00+01:00", to: "2026-11-30T23:59:00+01:00"),
            festival("thursday26", 26, 26),
            festival("finished", 10, 12)
        ]

        let feed = home(festivals: festivals)

        #expect(feed.weekendPeriod == .thisMonth)
        #expect(feed.weekend.map(\.id) == ["thursday26", "monday30"])
    }

    @Test func theMonthFallbackShowsAtMostThree() {
        let festivals = [
            festival("d", from: "2026-11-30T18:00:00+01:00", to: "2026-11-30T23:59:00+01:00"), festival("c", 26, 26), festival("b", 25, 26),
            festival("a", 23, 25)
        ]

        let feed = home(festivals: festivals)

        #expect(feed.weekendPeriod == .thisMonth)
        #expect(feed.weekend.map(\.id) == ["a", "b", "c"])
    }

    @Test func withoutAFestivalThisWeekendNorThisMonthTheSectionIsEmpty() {
        #expect(home(festivals: [festival("december", 2, 6, month: "12")]).weekend.isEmpty)
    }

    @Test func onSundayEveningAFestivalThatEndedSaturdayIsNoLongerShown() {
        let sundayEvening = date("2026-11-29T20:00:00+01:00")
        let festivals = [festival("ended-saturday", 27, 28), festival("ends-sunday", 28, 29)]

        let feed = home(festivals: festivals, now: sundayEvening)

        #expect(feed.weekendPeriod == .thisWeekend)
        #expect(feed.weekend.map(\.id) == ["ends-sunday"])
    }
}
