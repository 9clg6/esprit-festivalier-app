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

    func toggle(_ id: Performance.ID) {
        let target = !contains(id)
        if target { ids.insert(id) } else { ids.remove(id) }
        if target { offerReminders() }
        let token = (generation[id] ?? 0) + 1
        generation[id] = token
        let previous = pendingWrite
        pendingWrite = Task {
            await previous?.value
            do {
                try await store.setPicked(id, target)
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
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            rescheduleReminders()
        }
    }

    /// Plans the nearest reminders again: on launch, back to the app, picks or lead changed.
    func rescheduleReminders() {
        guard loaded else { return }
        scheduling?.cancel()
        let picks = ids
        let lead = ReminderLead(rawValue: UserDefaults.standard.integer(forKey: Self.leadKey)) ?? .default
        scheduling = Task { await reminders.reschedule(picks: picks, lead: lead) }
    }

    /// Once: refused or postponed, the sheet does not come back by itself (UX P5).
    private func offerReminders() {
        guard !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        Task {
            // Only the status crosses the callback: older SDKs do not mark the settings Sendable.
            let status = await withCheckedContinuation { done in
                UNUserNotificationCenter.current().getNotificationSettings {
                    done.resume(returning: $0.authorizationStatus)
                }
            }
            if status == .notDetermined { asksForReminders = true }
        }
    }
}

/// Concert reminders as local notifications: no network, no account (ADR-004).
struct ConcertReminderScheduler {
    let festivals: any FestivalSource
    let artists: any ArtistSource

    /// Replaces the scheduled reminders with the plan. If a timetable cannot be read (offline and not a
    /// favorite), the reminders already scheduled are kept as they are.
    @MainActor func reschedule(picks: Set<Performance.ID>, lead: ReminderLead) async {
        let center = UNUserNotificationCenter.current()
        // ponytail: reads every festival to find the picked sets (the plan drops the past ones); store
        // the festival id with each pick when the catalogue grows past a few dozen festivals.
        var picked: [Performance] = [], stageNames: [Stage.ID: String] = [:], festivalNames: [Festival.ID: String] = [:]
        do {
            let catalog = picks.isEmpty ? [] : try await festivals.festivals(updatedSince: nil)
            for festival in catalog {
                let detail = try await festivals.festival(id: festival.id)
                let mine = detail.performances.filter { picks.contains($0.id) }
                guard !mine.isEmpty else { continue }
                picked += mine
                festivalNames[festival.id] = festival.name
                for stage in detail.stages { stageNames[stage.id] = stage.name }
            }
        } catch {
            return
        }
        let artistNames = Dictionary(
            ((try? await artists.artists(ids: picked.map(\.artistId))) ?? []).map { ($0.id, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = ConcertReminders.plan(
            picks: picked, stageNames: stageNames, artistNames: artistNames, lead: lead, now: Date()
        )
        let festivalOf = Dictionary(picked.map { ($0.id, $0.festivalId) }, uniquingKeysWith: { first, _ in first })
        // Only the identifiers cross the callback: older SDKs do not mark the requests Sendable.
        let scheduled = await withCheckedContinuation { done in
            center.getPendingNotificationRequests { done.resume(returning: $0.map(\.identifier)) }
        }.filter { $0.hasPrefix(ConcertReminders.identifierPrefix) }
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: scheduled)
        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = festivalOf[reminder.performanceId].flatMap { festivalNames[$0] } ?? ""
            content.body = reminder.body
            content.sound = .default
            let when = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
