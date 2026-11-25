import EFData
import EFDomain
import Foundation
import Observation
import UserNotifications

/// The picked sets (☆/★) every timetable reads, and their reminders (STORY-019, STORY-020).
@MainActor @Observable
final class PicksModel {
    private(set) var ids: Set<Performance.ID> = []
    /// Shows the "Ne rate aucun concert" sheet (E14) on the first pick, before the iOS prompt.
    var asksForReminders = false
    private let store: PicksStore
    private let reminders: ConcertReminderScheduler
    @ObservationIgnored private var scheduling: Task<Void, Never>?
    /// False until the picks are read: an empty set before that would wipe the scheduled reminders.
    @ObservationIgnored private var loaded = false
    /// The last write: each write waits for it, so writes reach the store in tap order.
    @ObservationIgnored private var pendingWrite: Task<Void, Never>?
    /// Bumped by each tap on an id: a failed write reverts the star only if it is still the last tap.
    @ObservationIgnored private var generation: [Performance.ID: Int] = [:]

    /// UserDefaults keys; the lead is also read by the Profil tab through `@AppStorage`.
    static let leadKey = "reminderLead"
    private static let askedKey = "remindersAsked"

    init(store: PicksStore, reminders: ConcertReminderScheduler) {
        self.store = store
        self.reminders = reminders
    }

    func contains(_ id: Performance.ID) -> Bool { ids.contains(id) }

    func load() async {
        #if DEBUG
        // Debug builds only: `-seedPicks id1,id2` and `-showReminderPrompt YES` (simulator runs).
        for id in UserDefaults.standard.string(forKey: "seedPicks")?.split(separator: ",") ?? [] {
            try? await store.setPicked(String(id), true)
        }
        asksForReminders = UserDefaults.standard.bool(forKey: "showReminderPrompt")
        #endif
        ids = await store.pickedIDs
        loaded = true
        rescheduleReminders()
    }

    func toggle(_ performance: Performance) {
        let id = performance.id
        let target = !contains(id)
        if target { ids.insert(id) } else { ids.remove(id) }
        if target { offerReminders() }
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
            rescheduleReminders()
        }
    }

    /// "Activer" on the sheet: the iOS prompt, then the reminders.
    func enableReminders() {
        asksForReminders = false
        Task { await requestNotifications() }
    }

    /// The iOS prompt (shown once by iOS), then the reminders.
    func requestNotifications() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        rescheduleReminders()
    }

    static func notificationStatus() async -> UNAuthorizationStatus {
        // Only the status crosses the callback: older SDKs do not mark the settings Sendable.
        await withCheckedContinuation { done in
            UNUserNotificationCenter.current().getNotificationSettings {
                done.resume(returning: $0.authorizationStatus)
            }
        }
    }

    /// Plans the nearest reminders again: on launch, back to the app, picks or lead changed.
    func rescheduleReminders() {
        guard loaded else { return }
        // One at a time: the newer plan waits for the older one, which stops at its next step.
        let previous = scheduling
        previous?.cancel()
        let lead = ReminderLead(rawValue: UserDefaults.standard.integer(forKey: Self.leadKey)) ?? .default
        scheduling = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await reminders.reschedule(picks: await store.pickedFestivals, lead: lead)
        }
    }

    /// Once: refused or postponed, the sheet does not come back by itself (UX P5).
    private func offerReminders() {
        guard !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        Task {
            if await Self.notificationStatus() == .notDetermined { asksForReminders = true }
        }
    }
}

/// Concert reminders as local notifications: no network, no account (ADR-004).
struct ConcertReminderScheduler {
    let festivals: any FestivalSource
    let artists: any ArtistSource

    /// Replaces the scheduled reminders with the plan. A picked set whose timetable cannot be read
    /// (offline, not a favorite) keeps the reminder already scheduled for it.
    @MainActor func reschedule(picks: [Performance.ID: Festival.ID?], lead: ReminderLead) async {
        let found = await timetables(for: picks)
        let picked = found.details.flatMap { $0.performances.filter { picks.keys.contains($0.id) } }
        let pickedIDs = Set(picked.map(\.id))
        let unresolved = Set(picks.filter { id, festival in
            // A pick without festival may be in any timetable that could not be read.
            !pickedIDs.contains(id) && (festival.map(found.failed.contains) ?? found.incomplete)
        }.keys)
        let festivalNames = Dictionary(
            found.details.map { ($0.festival.id, $0.festival.name) }, uniquingKeysWith: { first, _ in first }
        )
        let stageNames = Dictionary(
            found.details.flatMap(\.stages).map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first }
        )
        let artistNames = Dictionary(
            ((try? await artists.artists(ids: picked.map(\.artistId))) ?? []).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = ConcertReminders.plan(
            picks: picked, stageNames: stageNames, artistNames: artistNames, lead: lead, now: Date()
        )
        let festivalOf = Dictionary(picked.map { ($0.id, $0.festivalId) }, uniquingKeysWith: { first, _ in first })
        let prefix = ConcertReminders.identifierPrefix
        // Only the identifiers cross the callback: older SDKs do not mark the requests Sendable.
        let scheduled = await withCheckedContinuation { done in
            center.getPendingNotificationRequests { done.resume(returning: $0.map(\.identifier)) }
        }.filter { $0.hasPrefix(prefix) && !unresolved.contains(String($0.dropFirst(prefix.count))) }
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: scheduled)
        for reminder in plan {
            guard !Task.isCancelled else { return }
            let content = UNMutableNotificationContent()
            content.title = festivalOf[reminder.performanceId].flatMap { festivalNames[$0] } ?? ""
            content.body = reminder.body
            content.sound = .default
            // An interval, not calendar components: a time zone change cannot move the reminder.
            let delay = max(1, reminder.fireDate.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    private var center: UNUserNotificationCenter { .current() }

    /// The timetables holding the picks, and the festivals that could not be read. Picks saved
    /// without their festival are looked for in the whole catalogue.
    private func timetables(
        for picks: [Performance.ID: Festival.ID?]
    ) async -> Timetables {
        var wanted = Set(picks.values.compactMap { $0 })
        var catalogFailed = false
        if picks.values.contains(where: { $0 == nil }) {
            if let catalog = try? await festivals.festivals(updatedSince: nil) {
                wanted.formUnion(catalog.map(\.id))
            } else {
                catalogFailed = true
            }
        }
        var details: [FestivalDetail] = []
        var failed = Set<Festival.ID>()
        for id in wanted {
            if let detail = try? await festivals.festival(id: id) { details.append(detail) } else { failed.insert(id) }
        }
        return Timetables(details: details, failed: failed, incomplete: catalogFailed || !failed.isEmpty)
    }

    private struct Timetables {
        let details: [FestivalDetail]
        /// Festivals whose timetable could not be read.
        let failed: Set<Festival.ID>
        /// Some timetable could not be read, or the catalogue itself.
        let incomplete: Bool
    }
}
