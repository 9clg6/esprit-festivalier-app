import EFDomain
import Foundation

/// One picked set of a timetable (☆/★). An unpicked set stays as a tombstone, like a favorite.
public struct PickEntry: Sendable, Codable, Hashable {
    public let performanceId: Performance.ID
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

    public var pickedIDs: Set<Performance.ID> { Set(entries.filter { !$0.deleted }.map(\.performanceId)) }

    public func isPicked(_ id: Performance.ID) -> Bool {
        entries.contains { $0.performanceId == id && !$0.deleted }
    }

    /// Idempotent: the same value twice changes nothing; unpicking a never-picked set leaves no entry.
    public func setPicked(_ id: Performance.ID, _ picked: Bool) throws {
        guard isPicked(id) != picked else { return }
        let entry = PickEntry(performanceId: id, updatedAt: now(), deleted: !picked)
        let updated = entries.filter { $0.performanceId != id } + [entry]
        try file.write(updated, now: now())
        entries = updated
    }
}
