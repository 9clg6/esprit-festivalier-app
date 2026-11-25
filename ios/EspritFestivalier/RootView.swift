import EFDesign
import EFDomain
import SwiftUI

enum AppTab: CaseIterable {
    case home, festivals, mine, articles, profile

    var title: String {
        switch self {
        case .home: "Accueil"
        case .festivals: "Festivals"
        case .mine: "Mes festivals"
        case .articles: "Articles"
        case .profile: "Profil"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .festivals: "magnifyingglass"
        case .mine: "heart"
        case .articles: "newspaper"
        case .profile: "person.crop.circle"
        }
    }
}

/// E15 on the first launch, then the five tabs (UX doc, "Navigation").
struct RootView: View {
    let environment: AppEnvironment
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(PicksModel.leadKey) private var lead = ReminderLead.default.rawValue
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    // ponytail: `-initialTab festivals` launch argument lets simulator runs start on any tab.
    @State private var tab = AppTab.allCases.first {
        "\($0)" == UserDefaults.standard.string(forKey: "initialTab")
    } ?? .home
    @State private var festivalsPeriod: FestivalFilter.Period?
    /// Opened by a tapped notification.
    @State private var openedArticle: Article?
    @State private var openedFestival: Festival.ID?

    var body: some View {
        Group {
            if hasSeenWelcome {
                tabs
            } else {
                WelcomeView {
                    tab = .festivals
                    hasSeenWelcome = true
                }
            }
        }
        .background(EFColorToken.bg.color.ignoresSafeArea())
        .overlay(alignment: .top) { saveError.allowsHitTesting(false) }
        .animation(.default, value: environment.favorites.saveError)
        .environment(environment.favorites)
        // One light haptic per favorite added, from the heart, a swipe or the VoiceOver action.
        .sensoryFeedback(.impact(weight: .light), trigger: environment.favorites.additions)
        .environment(environment.picks)
        .environment(environment.account)
        .environment(environment.notifications)
        .sheet(isPresented: Binding(
            get: { environment.notifications.asksPermission },
            set: { environment.notifications.asksPermission = $0 }
        )) { notificationsSheet }
        .task { await environment.favorites.load() }
        .task { await environment.picks.load() }
        .task { await environment.account.load() }
        .task { await environment.notifications.checkArticles() }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                // The next reminders take the places of those already shown (64 at most).
                environment.notifications.reschedule()
                Task { await environment.notifications.checkArticles() }
            case .background:
                environment.notifications.scheduleRefresh()
            default:
                break
            }
        }
        // initial: a tap that launched the app is set before the first render.
        .onChange(of: environment.notifications.opened, initial: true) { open(environment.notifications.opened) }
    }

    /// E14, once, on the first pick or favorite (UX P5): one sheet for the whole app.
    private var notificationsSheet: some View {
        PermissionSheet(
            systemImage: "bell.badge.fill", title: "Ne rate rien",
            examples: [
                "Les nouvelles programmations du site", "J-7 et J-1 avant tes festivals favoris",
                "Un rappel \(lead) min avant chaque concert coché"
            ],
            onActivate: environment.notifications.enable,
            onLater: { environment.notifications.asksPermission = false }
        )
    }

    /// A tapped notification: the article (E11), the Articles tab for a summary, or the festival (E5).
    private func open(_ opened: NotificationsModel.Opened?) {
        guard let opened else { return }
        hasSeenWelcome = true
        switch opened {
        case .article(let article):
            tab = .articles
            openedArticle = article
        case .articles:
            tab = .articles
        case .festival(let id):
            tab = .mine
            openedFestival = id
        }
        environment.notifications.opened = nil
    }

    @ViewBuilder private var saveError: some View {
        if let message = environment.favorites.saveError {
            Text(message)
                .efText(.strongLabel)
                .foregroundStyle(EFTextColor.onFill.color)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(EFColorToken.deep.color, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear { AccessibilityNotification.Announcement(message).post() }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                content(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
        .tint(EFColorToken.accentFill.color)
    }

    @ViewBuilder private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(environment: environment) { period in
                festivalsPeriod = period
                self.tab = .festivals
            } showArticles: {
                self.tab = .articles
            }
        case .festivals:
            FestivalListView(environment: environment, requestedPeriod: $festivalsPeriod)
        case .articles:
            ArticlesView(environment: environment, opened: $openedArticle)
        case .mine:
            MyFestivalsView(environment: environment, opened: $openedFestival) { self.tab = .festivals }
        case .profile:
            ProfileView()
        }
    }
}
