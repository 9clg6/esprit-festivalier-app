import Foundation

public struct TimetableStage: Sendable, Hashable {
    public let stage: Stage
    /// By start.
    public let performances: [Performance]
}

public struct TimetableDay: Sendable, Hashable {
    /// Midnight starting the calendar day; the festival day runs from 06:00 to 06:00 the next morning.
    public let date: Date
    /// In the festival's stage order; a stage with nothing that day is left out.
    public let stages: [TimetableStage]
}

/// A festival's sets by day and stage (E6), with conflicts between picked sets.
public struct Timetable: Sendable {
    public let days: [TimetableDay]
    /// Every set on a known stage, by start.
    private let performances: [Performance]

    private static let dayStartHour = 6

    public init(_ detail: FestivalDetail, calendar: Calendar) {
        let stageIds = Set(detail.stages.map(\.id))
        performances = detail.performances
            .filter { stageIds.contains($0.stageId) }
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
        let byDay = Dictionary(grouping: performances) { Self.festivalDay(of: $0.start, calendar: calendar) }
        days = byDay.keys.sorted().map { date in
            let sets = byDay[date] ?? []
            return TimetableDay(date: date, stages: detail.stages.compactMap { stage in
                let onStage = sets.filter { $0.stageId == stage.id }
                return onStage.isEmpty ? nil : TimetableStage(stage: stage, performances: onStage)
            })
        }
    }

    /// For each picked set, the other picked sets on another stage whose times overlap, by start.
    /// A picked set without conflict has no entry.
    public func conflicts(in picks: Set<Performance.ID>) -> [Performance.ID: [Performance]] {
        let picked = performances.filter { picks.contains($0.id) }
        var result: [Performance.ID: [Performance]] = [:]
        for performance in picked {
            let overlapping = picked.filter {
                $0.stageId != performance.stageId && $0.start < performance.end && performance.start < $0.end
            }
            if !overlapping.isEmpty { result[performance.id] = overlapping }
        }
        return result
    }

    /// Sets playing at `now` (start included, end excluded), every stage, by start.
    public func nowPlaying(at now: Date) -> [Performance] {
        performances.filter { $0.start <= now && now < $0.end }
    }

    /// The midnight starting the festival day `start` belongs to (before 06:00: the previous day).
    public static func festivalDay(of start: Date, calendar: Calendar) -> Date {
        let midnight = calendar.startOfDay(for: start)
        guard calendar.component(.hour, from: start) < dayStartHour else { return midnight }
        return calendar.date(byAdding: .day, value: -1, to: midnight) ?? midnight
    }
}
