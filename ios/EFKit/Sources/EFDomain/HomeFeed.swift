import Foundation

/// E1 "Accueil": what is new. Empty sections are hidden by the screen.
public struct HomeFeed: Sendable, Hashable {
    /// "À la une": the newest article.
    public let featured: Article?
    /// "Programmations": the first 5 cards of `Lineups.feed`.
    public let latestLineups: [LineupAnnouncement]
    /// "Ce week-end" (or "Ce mois-ci"): up to 3 festivals still to come, soonest first.
    public let weekend: [Festival]
    /// `.thisWeekend`, or `.thisMonth` when nothing happens this weekend: the title and the "Tout voir" filter.
    public let weekendPeriod: FestivalFilter.Period
    /// "Derniers articles": up to 4 newest articles after the featured one.
    public let latestArticles: [Article]

    // swiftlint:disable:next function_parameter_count
    public static func compose(
        festivals: [Festival], lineups: [Lineup], artists: [Artist], articles: [Article],
        now: Date, calendar: Calendar
    ) -> HomeFeed {
        let newest = articles.sorted { $0.publishedAt > $1.publishedAt }
        func upcoming(_ period: FestivalFilter.Period) -> [Festival] {
            FestivalFilter(period: period).apply(to: festivals, now: now, calendar: calendar)
                .filter { $0.endDate >= now }
                .sorted { ($0.startDate, $0.name) < ($1.startDate, $1.name) }
        }
        let thisWeekend = upcoming(.thisWeekend)
        let period: FestivalFilter.Period = thisWeekend.isEmpty ? .thisMonth : .thisWeekend
        let lineupFeed = Lineups.feed(lineups: lineups, festivals: festivals, artists: artists, now: now)
        return HomeFeed(
            featured: newest.first,
            latestLineups: Array(lineupFeed.prefix(5)),
            weekend: Array((thisWeekend.isEmpty ? upcoming(.thisMonth) : thisWeekend).prefix(3)),
            weekendPeriod: period,
            latestArticles: Array(newest.dropFirst().prefix(4))
        )
    }
}
