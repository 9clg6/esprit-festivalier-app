import Foundation

/// The favorite shown on top of "Mes festivals": in progress or starting within 48 hours.
public struct NextFestival: Sendable, Hashable {
    public enum When: Sendable, Hashable {
        case inProgress, today, tomorrow, dayAfterTomorrow

        public var title: String {
            switch self {
            case .inProgress: "En cours"
            case .today: "Aujourd'hui"
            case .tomorrow: "Demain"
            case .dayAfterTomorrow: "Après-demain"
            }
        }
    }

    public let festival: Festival
    public let when: When
}

public struct MyFestivalsSections: Sendable, Hashable {
    public let next: NextFestival?
    public let upcoming: [Festival]
    public let past: [Festival]

    public var isEmpty: Bool { next == nil && upcoming.isEmpty && past.isEmpty }
}

public enum MyFestivals {
    private static let nextWindow: TimeInterval = 48 * 3600

    public static func sections(favorites: [Festival], now: Date, calendar: Calendar) -> MyFestivalsSections {
        let (past, notFinished) = favorites.partitioned { $0.endDate < now }
        let ordered = notFinished.sorted { ($0.startDate, $0.name) < ($1.startDate, $1.name) }
        // Earliest start first: a festival in progress always beats one that has not started.
        let candidate = ordered.first.flatMap { $0.startDate <= now.addingTimeInterval(nextWindow) ? $0 : nil }
        let next = candidate.map { NextFestival(festival: $0, when: when($0, now: now, calendar: calendar)) }
        return MyFestivalsSections(
            next: next,
            upcoming: ordered.filter { $0.id != candidate?.id },
            past: past.sorted { ($1.endDate, $0.name) < ($0.endDate, $1.name) }
        )
    }

    private static func when(_ festival: Festival, now: Date, calendar: Calendar) -> NextFestival.When {
        if festival.startDate <= now { return .inProgress }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: festival.startDate)
        ).day ?? 0
        return switch days {
        case ...0: .today
        case 1: .tomorrow
        default: .dayAfterTomorrow
        }
    }
}

private extension Array {
    func partitioned(by belongsToFirst: (Element) -> Bool) -> ([Element], [Element]) {
        (filter(belongsToFirst), filter { !belongsToFirst($0) })
    }
}
