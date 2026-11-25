import EFData
import EFDomain
import Foundation
import Observation

@MainActor @Observable
final class FestivalListModel {
    enum State {
        case loading
        case loaded([Festival])
        case failed
    }

    private(set) var state = State.loading
    var filter = FestivalFilter()
    private let source: any FestivalSource
    let calendar: Calendar

    init(source: any FestivalSource) {
        self.source = source
        self.calendar = AppEnvironment.calendar
    }

    func load() async {
        do {
            state = .loaded(try await source.festivals(updatedSince: nil))
        } catch is CancellationError {
            // A cancelled pull-to-refresh keeps what is shown.
        } catch {
            state = .failed
        }
    }

    var festivals: [Festival] {
        if case .loaded(let festivals) = state { festivals } else { [] }
    }

    /// The list sections: filtered, then upcoming festivals by month.
    var sections: [FestivalListSection] { sections(for: filter) }

    /// Not finished festivals matching the filter: what the list, the map and "Voir N festivals" show.
    var upcoming: [Festival] { sections.flatMap(\.festivals) }

    func count(for filter: FestivalFilter) -> Int { sections(for: filter).reduce(0) { $0 + $1.festivals.count } }

    var availableGenres: [String] { FestivalFilter.availableGenres(in: festivals) }

    var availableRegions: [String] {
        Set(festivals.compactMap(\.region)).sorted { $0.compare($1, locale: calendar.locale) == .orderedAscending }
    }

    /// The date-interval end is the end of the last chosen day.
    func dates(from start: Date, to end: Date) -> FestivalFilter.Period {
        let first = calendar.startOfDay(for: start)
        let last = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: max(start, end)) ?? end
        return .dates(DateInterval(start: first, end: max(first, last)))
    }

    private func sections(for filter: FestivalFilter) -> [FestivalListSection] {
        FestivalList.sections(
            from: filter.apply(to: festivals, now: Date(), calendar: calendar), now: Date(), calendar: calendar
        )
    }
}
