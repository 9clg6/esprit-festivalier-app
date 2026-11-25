import EFData
import EFDomain
import Foundation
import UserNotifications

/// Plans the concert and favorite-festival reminders as local notifications: no network, no account
/// (ADR-004).
struct NotificationScheduler {
    let festivals: any FestivalSource
    let artists: any ArtistSource
    let offline: OfflineCache

    /// Replaces the scheduled reminders with the plan. A pick or favorite that cannot be read
    /// (offline, not a favorite) keeps the reminders already scheduled for it.
    @MainActor func reschedule(
        picks: [Performance.ID: Festival.ID?], favorites: [Festival.ID], lead: ReminderLead,
        preferences: NotificationPreferences
    ) async {
        // Switched off: no concert reminder is planned or kept.
        let concerts = preferences.concerts ? await concertPlan(picks: picks, lead: lead) : .none
        let favorite = await favoriteFestivals(favorites)
        let concertPrefix = ConcertReminders.identifierPrefix
        let favoritePrefix = FestivalReminders.identifierPrefix
        // Only the identifiers cross the callback: older SDKs do not mark the requests Sendable.
        let pending = await withCheckedContinuation { done in
            center.getPendingNotificationRequests { done.resume(returning: $0.map(\.identifier)) }
        }.filter { $0.hasPrefix(concertPrefix) || $0.hasPrefix(favoritePrefix) }
        let kept = Set(pending.filter { id in
            if id.hasPrefix(concertPrefix) {
                return concerts.unresolved.contains(String(id.dropFirst(concertPrefix.count)))
            }
            // "fav-<festival>-<kind>": a switched-off or unknown kind goes.
            let rest = id.dropFirst(favoritePrefix.count)
            guard let dash = rest.lastIndex(of: "-"),
                  let kind = FestivalReminderKind(rawValue: String(rest[rest.index(after: dash)...]))
            else { return false }
            return preferences.allows(kind) && favorite.unresolved.contains(String(rest[..<dash]))
        })
        let scheduled = pending.filter { !kept.contains($0) }
        // The kept reminders take their places under the iOS cap.
        let plan = NotificationPlan.earliest(
            concerts: concerts.reminders,
            festivals: FestivalReminders.plan(
                favorites: favorite.found, preferences: preferences, now: Date(), calendar: AppEnvironment.calendar
            ),
            limit: max(0, ConcertReminders.limit - kept.count)
        )
        guard !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: scheduled)
        for reminder in plan.concerts {
            guard !Task.isCancelled else { return }
            await add(reminder.id, title: concerts.titles[reminder.performanceId] ?? "", body: reminder.body,
                      at: reminder.fireDate)
        }
        for reminder in plan.festivals {
            guard !Task.isCancelled else { return }
            await add(
                reminder.id, body: reminder.body, at: reminder.fireDate, userInfo: ["festivalId": reminder.festivalId]
            )
        }
    }

    private var center: UNUserNotificationCenter { .current() }

    private func add(
        _ identifier: String, title: String = "", body: String, at fireDate: Date, userInfo: [String: String] = [:]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        // An interval, not calendar components: a time zone change cannot move the reminder.
        let delay = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    /// The favorites from the catalogue, or offline from their stored sheets; the others are unresolved.
    private func favoriteFestivals(
        _ ids: [Festival.ID]
    ) async -> (found: [Festival], unresolved: Set<Festival.ID>) {
        var known = (try? await festivals.festivals(updatedSince: nil)) ?? []
        if known.isEmpty { known = await offline.storedFestivals() }
        let found = known.filter { ids.contains($0.id) }
        return (found, Set(ids).subtracting(found.map(\.id)))
    }

    private struct ConcertPlan {
        static let none = ConcertPlan(reminders: [], titles: [:], unresolved: [])

        let reminders: [ConcertReminder]
        /// The festival's name, the notification's title.
        let titles: [Performance.ID: String]
        /// Picks whose timetable could not be read.
        let unresolved: Set<Performance.ID>
    }

    private func concertPlan(picks: [Performance.ID: Festival.ID?], lead: ReminderLead) async -> ConcertPlan {
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
        let reminders = ConcertReminders.plan(
            picks: picked, stageNames: stageNames, artistNames: artistNames, lead: lead, now: Date()
        )
        let titles = Dictionary(
            picked.map { ($0.id, festivalNames[$0.festivalId] ?? "") }, uniquingKeysWith: { first, _ in first }
        )
        return ConcertPlan(reminders: reminders, titles: titles, unresolved: unresolved)
    }

    /// The timetables holding the picks, and the festivals that could not be read. Picks saved
    /// without their festival are looked for in the whole catalogue.
    private func timetables(for picks: [Performance.ID: Festival.ID?]) async -> Timetables {
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
