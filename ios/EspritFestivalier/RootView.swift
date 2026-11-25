import EFDesign
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
        .environment(environment.favorites)
        .task { await environment.favorites.load() }
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
        case .festivals:
            FestivalListView(source: environment.festivals, artists: environment.artists)
        case .articles:
            ArticlesView(source: environment.articles, feed: environment.articleFeed)
        case .mine:
            MyFestivalsView(source: environment.festivals, artists: environment.artists) { self.tab = .festivals }
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
