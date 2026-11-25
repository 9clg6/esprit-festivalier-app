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
        .overlay(alignment: .top) { saveError }
        .animation(.default, value: environment.favorites.saveError)
        .environment(environment.favorites)
        .task { await environment.favorites.load() }
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
        default:
            EmptyState(
                systemImage: tab.symbol, title: "Bientôt disponible",
                message: "Cet onglet arrive dans une prochaine version."
            )
            .frame(maxHeight: .infinity)
            .background(EFColorToken.bg.color)
        }
    }
}
