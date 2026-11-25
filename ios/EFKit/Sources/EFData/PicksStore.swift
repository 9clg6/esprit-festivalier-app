import EFDomain
import Foundation

/// One picked set of a timetable (☆/★). An unpicked set stays as a tombstone, like a favorite.
public struct PickEntry: Sendable, Codable, Hashable {
    public let performanceId: Performance.ID
    /// The set's festival, so reminders load only that timetable; nil for picks saved before it was kept.
    public let festivalId: Festival.ID?
    public let updatedAt: Date
    public let deleted: Bool
}

/// The picked sets, kept on the device in `picks.json` (ADR-004, local first).
public actor PicksStore {
    private var file: LocalJSONFile<PickEntry>
    private let now: @Sendable () -> Date
    public private(set) var entries: [PickEntry]

    public init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        var file = LocalJSONFile<PickEntry>(directory.appending(path: "picks.json"))
        entries = file.read()
        self.file = file
        self.now = now
    }

    /// Reads the file again, after something else changed it (the account deletion erases it).
    public func reload() { entries = file.read() }

    public var pickedIDs: Set<Performance.ID> { Set(entries.filter { !$0.deleted }.map(\.performanceId)) }

    /// Live picks with their festival (nil when unknown).
    public var pickedFestivals: [Performance.ID: Festival.ID?] {
        Dictionary(entries.filter { !$0.deleted }.map { ($0.performanceId, $0.festivalId) }, uniquingKeysWith: { $1 })
    }

    public func isPicked(_ id: Performance.ID) -> Bool {
        entries.contains { $0.performanceId == id && !$0.deleted }
    }

    /// Idempotent: the same value twice changes nothing; unpicking a never-picked set leaves no entry.
    public func setPicked(_ id: Performance.ID, _ picked: Bool, festivalId: Festival.ID? = nil) throws {
        guard isPicked(id) != picked else { return }
        let entry = PickEntry(performanceId: id, festivalId: festivalId, updatedAt: now(), deleted: !picked)
        let updated = entries.filter { $0.performanceId != id } + [entry]
        try file.write(updated, now: now())
        entries = updated
    }
}
