import Foundation
import Testing
import EFDomain
import EFData

// STORY-017 and STORY-028 on the demo data ("mock d'abord"): E7 and E1 must not be empty in the demo.
// Expectations are derived from the mock data, so they survive a change of the demo.
// The demo's own integrity (a lineup per festival, known artists) is in MockLineupSourceTests.

private let paris: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
    calendar.locale = Locale(identifier: "fr_FR")
    return calendar
}()

/// The demo is dated 25 November 2026.
private let now = try! Date("2026-11-25T12:00:00+01:00", strategy: .iso8601)

private struct Demo {
    let festivals: [Festival]
    let lineups: [Lineup]
    let artists: [Artist]
    let articles: [Article]

    static func load() async throws -> Demo {
        let lineups = try await MockLineupSource().lineups()
        return Demo(
            festivals: try await MockFestivalSource().festivals(updatedSince: nil),
            lineups: lineups,
            artists: try await MockArtistSource().artists(ids: Array(Set(lineups.flatMap(\.artistIds)))),
            articles: try await MockArticleSource().articles(category: nil)
        )
    }
}

@Suite struct MockLineupsFeedTests {
    @Test func theDemoFeedHasACardPerUpcomingDemoFestival() async throws {
        let demo = try await Demo.load()
        let upcoming = demo.festivals.filter { $0.endDate >= now }.map(\.id)
        try #require(!upcoming.isEmpty, "the demo has no upcoming festival")

        let feed = Lineups.feed(lineups: demo.lineups, festivals: demo.festivals, artists: demo.artists, now: now)

        #expect(feed.map(\.festival.id).sorted() == upcoming.sorted())
    }

    @Test func eachDemoCardShowsFiveArtistsAndCountsTheRest() async throws {
        let demo = try await Demo.load()

        let feed = Lineups.feed(lineups: demo.lineups, festivals: demo.festivals, artists: demo.artists, now: now)

        try #require(!feed.isEmpty)
        for card in feed {
            let lineup = try #require(demo.lineups.first { $0.festivalId == card.festival.id })
            #expect(card.artistNames.count == min(5, lineup.artistIds.count), "\(card.festival.id)")
            #expect(card.remainingCount == max(0, lineup.artistIds.count - 5), "\(card.festival.id)")
        }
    }

    @Test func everyDemoLineupArtistHasAnUpcomingFestivalOnTheirPage() async throws {
        let demo = try await Demo.load()

        for artist in demo.artists {
            let festivals = Lineups.upcomingFestivals(
                of: artist.id, lineups: demo.lineups, festivals: demo.festivals, now: now
            )
            #expect(!festivals.isEmpty, "\(artist.id) has no festival")
        }
    }

    @Test func theDemoHomeHasAFeaturedArticleLineupsAndLatestArticles() async throws {
        let demo = try await Demo.load()
        try #require(demo.articles.count >= 2, "the demo needs at least two articles")

        let home = HomeFeed.compose(
            festivals: demo.festivals, lineups: demo.lineups, artists: demo.artists, articles: demo.articles,
            now: now, calendar: paris
        )

        #expect(home.featured != nil)
        #expect(home.latestLineups.count == min(5, demo.lineups.count))
        #expect(home.latestArticles.count == min(4, demo.articles.count - 1))
    }
}
