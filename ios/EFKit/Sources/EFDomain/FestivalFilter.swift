import Foundation

/// The search text and the criteria of the filter sheet (UX E2, E3). Criteria combine with AND.
public struct FestivalFilter: Sendable, Hashable {
    public enum Radius: Int, Sendable, CaseIterable, Hashable {
        case km25 = 25, km50 = 50, km100 = 100
    }

    public enum Place: Sendable, Hashable {
        case anywhere
        case region(String)
        case around(Coordinate, radius: Radius)
    }

    public enum Period: Sendable, Hashable {
        case any
        /// Friday 00:00 to Sunday 23:59 (the current one from Friday, the coming one before).
        case thisWeekend
        case thisMonth
        case dates(DateInterval)
    }

    public var searchText: String
    public var place: Place
    public var period: Period
    /// A festival matches when it has at least one of them; empty means no constraint.
    public var genres: Set<String>

    public init(searchText: String = "", place: Place = .anywhere, period: Period = .any, genres: Set<String> = []) {
        self.searchText = searchText
        self.place = place
        self.period = period
        self.genres = genres
    }

    /// The "Filtres · N" count: place, period and genres (several genres are one). Not the search text.
    public var activeCount: Int {
        [place != .anywhere, period != .any, !genres.isEmpty].filter { $0 }.count
    }

    /// Keeps the order of `festivals`. `now` and `calendar` (fr_FR, Europe/Paris) decide the periods.
    public func apply(to festivals: [Festival], now: Date, calendar: Calendar) -> [Festival] {
        let query = Self.fold(searchText)
        let window = periodWindow(now: now, calendar: calendar)
        return festivals.filter { festival in
            (query.isEmpty || Self.fold(festival.name).contains(query) || Self.fold(festival.city).contains(query))
                && matches(place: festival)
                && (window.map { festival.startDate <= $0.end && festival.endDate >= $0.start } ?? true)
                && (genres.isEmpty || !genres.isDisjoint(with: festival.genres))
        }
    }

    /// The distinct genres of `festivals`, in French order ("É" sorts with "E").
    public static func availableGenres(in festivals: [Festival]) -> [String] {
        let french = Locale(identifier: "fr_FR")
        return Set(festivals.flatMap(\.genres)).sorted { $0.compare($1, locale: french) == .orderedAscending }
    }

    private func matches(place festival: Festival) -> Bool {
        switch place {
        case .anywhere: true
        case .region(let name): festival.region == name
        case .around(let center, let radius):
            center.kilometers(to: Coordinate(latitude: festival.latitude, longitude: festival.longitude))
                <= Double(radius.rawValue)
        }
    }

    private func periodWindow(now: Date, calendar: Calendar) -> DateInterval? {
        switch period {
        case .any: return nil
        case .thisMonth: return calendar.dateInterval(of: .month, for: now)
        case .dates(let interval): return interval
        case .thisWeekend:
            let today = calendar.startOfDay(for: now)
            let weekday = calendar.component(.weekday, from: now) // 1 = Sunday ... 7 = Saturday
            let sinceFriday = (weekday + 1) % 7 // Friday 0, Saturday 1, Sunday 2, Monday 3 ... Thursday 6
            let friday = sinceFriday <= 2 ? -sinceFriday : 7 - sinceFriday
            guard let start = calendar.date(byAdding: .day, value: friday, to: today),
                  let end = calendar.date(byAdding: .day, value: 3, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
