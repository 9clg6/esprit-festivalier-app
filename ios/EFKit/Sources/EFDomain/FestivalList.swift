import Foundation

/// One month of the festival list: the title is "JUIN 2027".
public struct FestivalListSection: Sendable, Hashable, Identifiable {
    public var id: String { title }
    public let title: String
    public let festivals: [Festival]
}

public enum FestivalList {
    /// Upcoming festivals (not ended before `now`), sorted by start then name, one section per start month.
    public static func sections(from festivals: [Festival], now: Date, calendar: Calendar) -> [FestivalListSection] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale
        formatter.dateFormat = "LLLL yyyy"

        let upcoming = festivals
            .filter { $0.endDate >= now }
            .sorted { ($0.startDate, $0.name) < ($1.startDate, $1.name) }
        // Sorted by start, so festivals of one month are adjacent.
        var sections: [FestivalListSection] = []
        for festival in upcoming {
            let title = formatter.string(from: festival.startDate).uppercased(with: calendar.locale)
            if let last = sections.last, last.title == title {
                sections[sections.count - 1] = FestivalListSection(title: title, festivals: last.festivals + [festival])
            } else {
                sections.append(FestivalListSection(title: title, festivals: [festival]))
            }
        }
        return sections
    }
}
