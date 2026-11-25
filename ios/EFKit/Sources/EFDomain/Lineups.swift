import Foundation

/// One E7 card: a festival's lineup announcement, with the first 5 known artists and the count of the rest.
public struct LineupAnnouncement: Sendable, Hashable, Identifiable {
    public var id: Festival.ID { festival.id }
    public let festival: Festival
    public let announcedOn: Date
    /// The first 5 known artists, in lineup order.
    public let artistNames: [String]
    /// The other known artists ("+ 19"); 0 when none.
    public let remainingCount: Int
}

public enum Lineups {
    static let shownArtists = 5

    /// E7: lineups of festivals not ended before `now`, newest announcement first, then soonest festival.
    /// Unknown festivals and artists are skipped; a lineup with no known artist is dropped.
    public static func feed(
        lineups: [Lineup], festivals: [Festival], artists: [Artist], now: Date
    ) -> [LineupAnnouncement] {
        let festivalsById = upcomingById(festivals, now: now)
        let names = Dictionary(artists.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return lineups.compactMap { lineup -> LineupAnnouncement? in
            guard let festival = festivalsById[lineup.festivalId] else { return nil }
            let known = lineup.artistIds.compactMap { names[$0] }
            guard !known.isEmpty else { return nil }
            return LineupAnnouncement(
                festival: festival, announcedOn: lineup.announcedOn,
                artistNames: Array(known.prefix(shownArtists)), remainingCount: max(0, known.count - shownArtists)
            )
        }
        .sorted { lhs, rhs in
            (rhs.announcedOn, lhs.festival.startDate, lhs.festival.name)
                < (lhs.announcedOn, rhs.festival.startDate, rhs.festival.name)
        }
    }

    /// E8 "En festival": festivals not ended before `now` whose lineup has the artist, soonest first.
    public static func upcomingFestivals(
        of artistId: Artist.ID, lineups: [Lineup], festivals: [Festival], now: Date
    ) -> [Festival] {
        let festivalIds = Set(lineups.filter { $0.artistIds.contains(artistId) }.map(\.festivalId))
        return upcomingById(festivals, now: now).values
            .filter { festivalIds.contains($0.id) }
            .sorted { ($0.startDate, $0.name) < ($1.startDate, $1.name) }
    }

    private static func upcomingById(_ festivals: [Festival], now: Date) -> [Festival.ID: Festival] {
        Dictionary(festivals.filter { $0.endDate >= now }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
