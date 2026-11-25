import EFDesign
import EFDomain
import SwiftUI

/// E1: à la une, programmations, ce week-end (or ce mois-ci), derniers articles. Empty sections are hidden.
struct HomeView: View {
    @Environment(FavoritesModel.self) private var favorites
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [Route] = Self.initialPath
    let environment: AppEnvironment
    /// "Tout voir" of the weekend section: the Festivals tab on that period.
    let showFestivals: (FestivalFilter.Period) -> Void
    let showArticles: () -> Void

    /// Debug builds only: `-openLineups YES`, `-openLineup <festival id>`, `-openArtist <id>` (simulator runs).
    private static var initialPath: [Route] {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "openArtist") { return [.lineups, .artist(id)] }
        if let id = defaults.string(forKey: "openLineup") { return [.lineups, .festivalLineup(id)] }
        return defaults.bool(forKey: "openLineups") ? [.lineups] : []
        #else
        []
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            Loaded {
                let data = try await environment.lineupData()
                // Articles come from the site: offline, the other sections still show.
                let articles = (try? await environment.articles.articles(category: nil)) ?? []
                return HomeFeed.compose(
                    festivals: data.festivals, lineups: data.lineups, artists: data.artists, articles: articles,
                    now: Date(), calendar: AppEnvironment.calendar
                )
            } content: { feed, reload in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) { sections(feed) }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .refreshable { await reload() }
            }
            // The logo is the header; "Accueil" stays the back button label of pushed screens.
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("Accueil")
            .routes(environment)
        }
    }

    @ViewBuilder private func sections(_ feed: HomeFeed) -> some View {
        // Light letters with a dark outline: readable in light and dark mode as is.
        Image("Logo")
            .resizable()
            .scaledToFit()
            .frame(height: 44)
            .accessibilityLabel("Esprit Festivalier")
            .accessibilityAddTraits(.isHeader)
            .padding(.bottom, -16)
        if let article = feed.featured {
            NavigationLink(value: Route.article(article)) {
                HeroCard(imageURL: article.imageURL, category: article.category.rawValue, title: article.title)
            }
            .buttonStyle(.plain)
        }
        lineupsSection(feed.latestLineups)
        if !feed.weekend.isEmpty {
            section {
                SectionHeader(feed.weekendPeriod == .thisWeekend ? "Ce week-end" : "Ce mois-ci") {
                    showFestivals(feed.weekendPeriod)
                }
            } content: {
                ForEach(feed.weekend) { festival in
                    NavigationLink(value: Route.festival(festival.id)) { FestivalRow(festival, favorites: favorites) }
                        .buttonStyle(.plain)
                }
            }
        }
        articlesSection(feed.latestArticles)
    }

    @ViewBuilder private func lineupsSection(_ cards: [LineupAnnouncement]) -> some View {
        if !cards.isEmpty {
            section {
                SectionHeader("Programmations", seeAllValue: Route.lineups)
            } content: {
                carousel(cards) { card in
                    NavigationLink(value: Route.festivalLineup(card.festival.id)) {
                        FestivalCard(
                            imageURL: card.festival.imageURL, name: card.festival.name,
                            startDate: card.festival.startDate, endDate: card.festival.endDate,
                            artistCount: card.artistNames.count + card.remainingCount
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder private func articlesSection(_ articles: [Article]) -> some View {
        if !articles.isEmpty {
            section {
                SectionHeader("Derniers articles", seeAll: showArticles)
            } content: {
                carousel(articles) { article in
                    NavigationLink(value: Route.article(article)) {
                        ArticleCard(
                            imageURL: article.imageURL, category: article.category.rawValue, title: article.title,
                            author: article.author, date: article.publishedAt, isSponsored: article.isSponsored
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func section<Header: View, Content: View>(
        @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header()
            content()
        }
    }

    /// Horizontal cards; a vertical list at accessibility text sizes.
    @ViewBuilder private func carousel<Item: Identifiable, Card: View>(
        _ items: [Item], @ViewBuilder card: @escaping (Item) -> Card
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 12) { ForEach(items, content: card) }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { card($0).frame(width: 260) }
                }
            }
            .scrollClipDisabled()
        }
    }
}
