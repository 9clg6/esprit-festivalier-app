import BackgroundTasks
import EFData
import EFDomain
import Foundation
import Observation
import UserNotifications

/// Every local notification, no server (STORY-020, 024, 025, 027): the permission, the Profil
/// switches, the reminders planned under the shared cap of 64, and the new articles of the site.
@MainActor @Observable
final class NotificationsModel {
    /// What a tapped notification opens.
    enum Opened: Equatable, Sendable {
        case article(Article)
        case articles
        case festival(Festival.ID)
    }

    enum Part { case picks, favorites }

    static let refreshIdentifier = "fr.espritfestivalier.app.articles"
    private static let askedKey = "remindersAsked"

    /// Shows the "Ne rate rien" sheet (E14) on the first pick or favorite, before the iOS prompt.
    var asksPermission = false
    /// Set by a tapped notification; RootView opens it, then clears it.
    var opened: Opened?
    var preferences: NotificationPreferences {
        didSet {
            try? JSONEncoder().encode(preferences).write(to: preferencesFile, options: .atomic)
            reschedule()
        }
    }

    private let picks: PicksStore
    private let favorites: FavoritesStore
    private let articles: any ArticleSource
    private let scheduler: NotificationScheduler
    private let preferencesFile: URL
    private let seenFile: URL
    /// Until both are read, an empty list would wipe the scheduled reminders.
    @ObservationIgnored private var waiting: Set<Part> = [.picks, .favorites]
    @ObservationIgnored private var scheduling: Task<Void, Never>?
    @ObservationIgnored private var checking: Task<Void, Never>?
    @ObservationIgnored private var tapHandler: NotificationTapHandler?

    /// `directory` is erased by the account deletion: the switches and the seen articles go with it.
    init(
        directory: URL, picks: PicksStore, favorites: FavoritesStore, articles: any ArticleSource,
        scheduler: NotificationScheduler
    ) {
        self.picks = picks
        self.favorites = favorites
        self.articles = articles
        self.scheduler = scheduler
        preferencesFile = directory.appending(path: "notification-preferences.json")
        seenFile = directory.appending(path: "seen-articles.json")
        preferences = Self.read(preferencesFile) ?? NotificationPreferences()
        #if DEBUG
        // Debug builds only: `-showReminderPrompt YES` (simulator runs).
        asksPermission = UserDefaults.standard.bool(forKey: "showReminderPrompt")
        #endif
    }

    /// At launch, before it ends: taps and background refreshes need their handlers by then.
    func install() {
        let handler = NotificationTapHandler(model: self)
        tapHandler = handler
        UNUserNotificationCenter.current().delegate = handler
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshIdentifier, using: .main) { [self] task in
            MainActor.assumeIsolated {
                scheduleRefresh()
                let completion = BackgroundCompletion(task: task)
                let work = Task {
                    await checkArticles()
                    completion.finish(success: !Task.isCancelled)
                }
                // Stops the check (the fetch is cancelled with it) and tells iOS at once.
                task.expirationHandler = {
                    work.cancel()
                    Task { @MainActor in completion.finish(success: false) }
                }
            }
        }
    }

    /// iOS picks the moment; 15 min is the earliest asked for (STORY-025).
    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func loaded(_ part: Part) {
        waiting.remove(part)
        reschedule()
    }

    /// After the account deletion erased the files: default switches, then the plan again.
    func reloadAfterErase() {
        preferences = Self.read(preferencesFile) ?? NotificationPreferences()
    }

    /// What "Exporter mes données" writes.
    var exportFlags: [String: Bool] {
        let categories = Set(Article.Category.known).union(preferences.articleCategories)
        var flags = [
            "festivalJ7": preferences.festivalJ7, "festivalJ1": preferences.festivalJ1, "concerts": preferences.concerts
        ]
        for category in categories {
            flags["articles.\(category.rawValue)"] = preferences.articleCategories.contains(category)
        }
        return flags
    }

    /// Plans the nearest reminders again: launch, back to the app, picks, favorites, lead or switches.
    func reschedule() {
        guard waiting.isEmpty else { return }
        // One at a time: the newer plan waits for the older one, which stops at its next step.
        let previous = scheduling
        previous?.cancel()
        let lead = PicksModel.lead
        let preferences = preferences
        scheduling = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            await scheduler.reschedule(
                picks: await picks.pickedFestivals, favorites: await favorites.favoriteIDs, lead: lead,
                preferences: preferences
            )
        }
    }

    /// After the account deletion: the next pick or favorite offers the sheet again.
    func resetPermissionOffer() { UserDefaults.standard.removeObject(forKey: Self.askedKey) }

    /// Once: refused or postponed, the sheet does not come back by itself (UX P5).
    func offerPermission() {
        guard !UserDefaults.standard.bool(forKey: Self.askedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.askedKey)
        Task {
            if await Self.status() == .notDetermined { asksPermission = true }
        }
    }

    /// "Activer" on the sheet: the iOS prompt, then the reminders.
    func enable() {
        asksPermission = false
        Task { await requestAuthorization() }
    }

    /// The iOS prompt (shown once by iOS), then the reminders.
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        reschedule()
    }

    static func status() async -> UNAuthorizationStatus {
        // Only the status crosses the callback: older SDKs do not mark the settings Sendable.
        await withCheckedContinuation { done in
            UNUserNotificationCenter.current().getNotificationSettings {
                done.resume(returning: $0.authorizationStatus)
            }
        }
    }

    /// New articles of the feed in the followed sections; one check at a time, so a background
    /// refresh and a return to the app never notify the same article twice.
    /// Cancelling the caller cancels the check.
    func checkArticles() async {
        if let checking { return await Self.wait(for: checking) }
        let work = Task { await runArticleCheck() }
        checking = work
        await Self.wait(for: work)
        checking = nil
    }

    private static func wait(for work: Task<Void, Never>) async {
        await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
    }

    private func runArticleCheck() async {
        // An empty feed changes nothing: no seen set is written, so a first run stays a first run.
        guard let feed = try? await articles.articles(category: nil), !feed.isEmpty, !Task.isCancelled
        else { return }
        let stored: [Article.ID]? = Self.read(seenFile)
        let result = NewArticles.check(feed: feed, seen: stored.map(Set.init), preferences: preferences)
        let feedIDs = feed.map(\.id)
        // ponytail: the 500 most recent ids are kept; a feed of more than 500 items would notify old
        // ones again (the site's feed has about 10).
        let kept = feedIDs + (stored ?? []).filter { !Set(feedIDs).contains($0) }
        try? JSONEncoder().encode(Array(kept.prefix(500))).write(to: seenFile, options: .atomic)
        for notification in result.notifications {
            let content = UNMutableNotificationContent()
            content.title = "Esprit Festivalier"
            content.body = notification.body
            content.sound = .default
            var identifier = "articles-summary"
            if case .article(let article) = notification {
                identifier = "article-\(article.id)"
                content.userInfo = [
                    "link": article.link.absoluteString, "article": (try? JSONEncoder().encode(article)) ?? Data()
                ]
            }
            try? await UNUserNotificationCenter.current()
                .add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }
    }

    private static func read<Value: Decodable>(_ file: URL) -> Value? {
        (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }
}

/// Calls `setTaskCompleted` once, whether the check ends or iOS stops it first.
@MainActor private final class BackgroundCompletion {
    private var task: BGTask?

    init(task: BGTask) { self.task = task }

    func finish(success: Bool) {
        task?.setTaskCompleted(success: success)
        task = nil
    }
}

/// Shows notifications while the app is open, and turns a tap into the screen to open.
final class NotificationTapHandler: NSObject, UNUserNotificationCenterDelegate, Sendable {
    let model: NotificationsModel

    init(model: NotificationsModel) { self.model = model }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let request = response.notification.request
        let info = request.content.userInfo
        let opened: NotificationsModel.Opened? = if let data = info["article"] as? Data,
            let article = try? JSONDecoder().decode(Article.self, from: data) {
            .article(article)
        } else if request.identifier.hasPrefix("article") {
            .articles
        } else if let festival = info["festivalId"] as? String {
            .festival(festival)
        } else {
            nil
        }
        await MainActor.run { model.opened = opened }
    }
}
