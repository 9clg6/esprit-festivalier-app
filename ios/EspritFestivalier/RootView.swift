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
        .sheet(isPresented: Binding(
            get: { environment.picks.asksForReminders }, set: { environment.picks.asksForReminders = $0 }
        )) { remindersSheet }
        .task { await environment.favorites.load() }
        .task { await environment.picks.load() }
        // Back to the app: the next reminders take the places of those already shown (64 at most).
        .onChange(of: scenePhase) { if scenePhase == .active { environment.picks.rescheduleReminders() } }
    }

    /// E14 for the reminders, once, on the first pick: one sheet for the whole app.
    private var remindersSheet: some View {
        PermissionSheet(
            systemImage: "bell.badge.fill", title: "Ne rate aucun concert",
            examples: [
                "Un rappel \(lead) min avant chaque concert coché", "Les rappels marchent même sans réseau",
                "Le délai se règle dans Profil"
            ],
            onActivate: environment.picks.enableReminders,
            onLater: { environment.picks.asksForReminders = false }
        )
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
            ArticlesView(source: environment.articles, feed: environment.articleFeed)
        case .mine:
            MyFestivalsView(environment: environment) { self.tab = .festivals }
        case .profile:
            ProfileView()
        }
    }
}
