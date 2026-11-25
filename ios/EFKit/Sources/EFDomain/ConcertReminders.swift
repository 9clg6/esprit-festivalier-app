import Foundation

/// How long before a picked set its reminder fires (Profil, "Rappels de concerts").
public enum ReminderLead: Int, CaseIterable, Sendable {
    case five = 5, ten = 10, fifteen = 15, thirty = 30

    public static let `default` = ReminderLead.fifteen
}

public struct ConcertReminder: Sendable, Hashable {
    /// Depends on the performance only: scheduling again replaces, never duplicates.
    public let id: String
    public let performanceId: Performance.ID
    public let fireDate: Date
    public let body: String
}

/// Local reminders for the picked sets. iOS keeps at most 64 pending local notifications, so the
/// nearest ones are planned again at each app opening.
public enum ConcertReminders {
    public static let limit = 64
    /// Every reminder identifier starts with it, so the app can tell them from other notifications.
    public static let identifierPrefix = "concert-"

    public static func plan(
        picks: [Performance], stageNames: [Stage.ID: String], artistNames: [Artist.ID: String],
        lead: ReminderLead = .default, now: Date, limit: Int = ConcertReminders.limit
    ) -> [ConcertReminder] {
        let offset = TimeInterval(lead.rawValue * 60)
        return picks
            .filter { $0.start - offset > now }
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
            .prefix(max(0, limit))
            .map { performance in
                ConcertReminder(
                    id: identifierPrefix + performance.id, performanceId: performance.id,
                    fireDate: performance.start - offset,
                    body: body(
                        artist: artistNames[performance.artistId], stage: stageNames[performance.stageId], lead: lead
                    )
                )
            }
    }

    /// "Artiste Y sur la scène Z dans 15 min"; "Un concert" without artist, no stage part without stage.
    private static func body(artist: String?, stage: String?, lead: ReminderLead) -> String {
        let place = stage.map { " sur la scène \($0)" } ?? ""
        return "\(artist ?? "Un concert")\(place) dans \(lead.rawValue) min"
    }
}
