import EFData
import EFDesign
import EFDomain
import SwiftUI

/// E10: the site's articles, filtered by section.
struct ArticlesView: View {
    @State private var model: ArticlesModel
    @State private var path: [Article] = []
    /// Set by a tapped article notification.
    @Binding private var opened: Article?

    init(source: any ArticleSource, feed: SiteFeed?, opened: Binding<Article?>) {
        _model = State(initialValue: ArticlesModel(source: source, feed: feed))
        _opened = opened
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                if let cachedAt = model.offlineSince { OfflineBanner(cachedAt: cachedAt) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        chips
                        content
                    }
                    .padding(.horizontal, 16)
                }
                .refreshable { await model.load() }
            }
            .background(EFColorToken.bg.color)
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Article.self) { ArticleView(article: $0) }
        }
        .onChange(of: opened, initial: true) {
            guard let opened else { return }
            path = [opened]
            self.opened = nil
        }
        .task {
            await model.load()
            #if DEBUG
            // `-openArticle <index>` opens an article at launch (simulator runs).
            if UserDefaults.standard.object(forKey: "openArticle") != nil,
               model.shown.indices.contains(UserDefaults.standard.integer(forKey: "openArticle")) {
                path = [model.shown[UserDefaults.standard.integer(forKey: "openArticle")]]
            }
            #endif
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ArticlesModel.chips, id: \.label) { chip in
                    GenreChip(chip.label, isSelected: model.category == chip.category) {
                        model.category = chip.category
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ForEach(0..<3, id: \.self) { _ in SkeletonBlock(cornerRadius: 16).frame(height: 280) }
        case .failed:
            EmptyState(
                systemImage: "wifi.exclamationmark", title: "Impossible de charger les articles",
                message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
            ) { Task { await model.load() } }
        case .loaded:
            if model.shown.isEmpty {
                EmptyState(
                    systemImage: "newspaper", title: "Pas encore d'article dans cette rubrique",
                    message: "Reviens bientôt, ou regarde les autres rubriques.",
                    actionTitle: "Voir tous les articles"
                ) { model.category = nil }
            } else {
                ForEach(model.shown) { article in
                    NavigationLink(value: article) {
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
}
