import EFData
import EFDomain
import Foundation
import Observation

/// The picked sets (☆/★) every timetable reads, and their reminders (STORY-019, STORY-020).
@MainActor @Observable
final class PicksModel {
    private(set) var ids: Set<Performance.ID> = []
    private let store: PicksStore
    private let notifications: NotificationsModel
    /// The last write: each write waits for it, so writes reach the store in tap order.
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?
    /// Bumped by each tap on an id: a failed write reverts the star only if it is still the last tap.
    @ObservationIgnored private var generation: [Performance.ID: Int] = [:]

    /// UserDefaults key; the lead is also read by the Profil tab through `@AppStorage`.
    static let leadKey = "reminderLead"

    init(store: PicksStore, notifications: NotificationsModel) {
        self.store = store
        self.notifications = notifications
    }

    func contains(_ id: Performance.ID) -> Bool { ids.contains(id) }

    func load() async {
        #if DEBUG
        // Debug builds only: `-seedPicks id1,id2` (simulator runs).
        for id in UserDefaults.standard.string(forKey: "seedPicks")?.split(separator: ",") ?? [] {
            try? await store.setPicked(String(id), true)
        }
        #endif
        ids = await store.pickedIDs
        notifications.loaded(.picks)
    }

    /// What "Exporter mes données" writes.
    func entries() async -> [PickEntry] { await store.entries }

    /// After the account deletion erased the files; the account then plans the reminders again.
    func reloadAfterErase() async {
        await store.reload()
        ids = await store.pickedIDs
    }

    /// The delay chosen in Profil.
    static var lead: ReminderLead { ReminderLead(rawValue: UserDefaults.standard.integer(forKey: leadKey)) ?? .default }

    func toggle(_ performance: Performance) {
        let id = performance.id
        let target = !contains(id)
        if target { ids.insert(id) } else { ids.remove(id) }
        if target { notifications.offerPermission() }
        let token = (generation[id] ?? 0) + 1
        generation[id] = token
        let previous = pendingWrite
        pendingWrite = Task {
            await previous?.value
            do {
                try await store.setPicked(id, target, festivalId: performance.festivalId)
            } catch {
                // A failed write puts the star back to what is saved.
                let saved = await store.isPicked(id)
                if generation[id] == token {
                    if saved { ids.insert(id) } else { ids.remove(id) }
                }
            }
            notifications.reschedule()
        }
    }
}
