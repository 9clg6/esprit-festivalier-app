import EFData
import EFDesign
import EFDomain
import SwiftUI

/// E11: the feed's cover, title and excerpt at once, then the full text rendered natively (ADR-007).
/// `model.fullTextDisplayed` is the signal read counting listens to (FR-036).
struct ArticleView: View {
    @State private var model: ArticleReaderModel
    /// The blocks' text, built once per content, never on a body recomputation.
    @State private var rendered: [RenderedBlock] = []
    @State private var safariURL: SafariItem?
    @State private var zoomed: ZoomItem?
    @State private var pushed: ReaderPush?
    /// The parent's action: Mail and Phone for `mailto:` and `tel:`.
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let environment: AppEnvironment

    init(article: Article, environment: AppEnvironment) {
        self.environment = environment
        _model = State(initialValue: ArticleReaderModel(article: article, source: environment.articleContent))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let heroURL { hero(heroURL) }
                header.padding(.horizontal, 16)
                text
                ShareLink(item: article.link) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .efText(.strongLabel)
                        .foregroundStyle(EFTextColor.accentDark.color)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        // Without a photo the article starts below the bar.
        .ignoresSafeArea(edges: heroURL == nil ? [] : .top)
        .background(EFColorToken.bg.color)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.openURL, OpenURLAction { url in
            open(url)
            return .handled
        })
        .sheet(item: $safariURL) { SafariView(url: $0.url).ignoresSafeArea() }
        .fullScreenCover(item: $zoomed) { ZoomedImage(image: $0.image) }
        .navigationDestination(item: $pushed) { push in
            switch push {
            // AnyView: an article inside an article would define the view's type in terms of itself.
            case .article(let article): AnyView(ArticleView(article: article, environment: environment))
            case .festival(let id): AnyView(FestivalDetailView(id: id, environment: environment))
            }
        }
        .task {
            if case .loading = model.state { await model.load() }
        }
        .onChange(of: model.state, initial: true) { _, state in
            if case .loaded(let content) = state { rendered = RenderedBlock.make(content.blocks) }
        }
    }

    private var article: Article { model.article }

    private var content: ArticleContent? {
        if case .loaded(let content) = model.state { content } else { nil }
    }

    private var heroURL: URL? { content?.cover?.url ?? article.imageURL }

    private func hero(_ url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Full bleed under the status bar and the navigation bar, like E5.
            Button {
                if let cover = content?.cover { zoom(cover) }
            } label: {
                EFColorToken.thumb.color
                    .frame(height: 320)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                        }
                    }
                    .overlay { HeroScrim() }
                    .clipped()
            }
            .buttonStyle(.plain)
            .accessibilityHidden(content?.cover == nil)
            .accessibilityLabel(content?.cover?.caption ?? "Photo")
            .accessibilityAddTraits(.isImage)
            if let caption = content?.cover?.caption {
                Text(caption).efText(.caption).foregroundStyle(EFTextColor.muted.color).padding(.horizontal, 16)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Header: VoiceOver reads the title, then the meta, then the text.

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            meta
            let title = content?.title ?? article.title
            if title.isEmpty {
                SkeletonBlock(cornerRadius: 8).frame(height: 64)
            } else {
                Text(title).efText(.title1).foregroundStyle(EFTextColor.ink.color)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilitySortPriority(3)
            }
            if let chapo = content?.chapo {
                Text(chapo).efText(.body).foregroundStyle(EFTextColor.ink.color).accessibilitySortPriority(1)
            }
            if let byline {
                Text(byline).efText(.bodySecondary).foregroundStyle(EFTextColor.muted.color)
                    .accessibilitySortPriority(2)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var meta: some View {
        HStack(spacing: 8) {
            let category = (content?.category ?? article.category).rawValue
            if !category.isEmpty {
                Text(category).efText(.sectionHeader).foregroundStyle(EFTextColor.accentDark.color)
            }
            if let festival = content?.festival,
               let url = URL(string: "https://\(SiteLink.siteHost)/festival/\(festival.slug)/") {
                Button("· \(festival.name) ↗\u{FE0E}") { open(url) }
                    .efText(.sectionHeader)
                    .foregroundStyle(EFTextColor.accentDark.color)
                    .frame(minHeight: 44)
            }
            if content?.isSponsored ?? article.isSponsored { Badge("Sponsorisé") }
        }
        .accessibilitySortPriority(2)
    }

    /// "Mano Le Bris · 25 nov. 2026 · 3 min"; nil for an article known only by its address, until it loads.
    private var byline: String? {
        guard content != nil || article.publishedAt != Article.stubDate else { return nil }
        let day = (content?.publishedAt ?? article.publishedAt).formatted(
            .dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "fr_FR")))
        let author = content?.author?.name ?? article.author
        let minutes = content?.readingMinutes.map { "\($0) min" }
        return ([author, day] + [minutes].compactMap { $0 }).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: Text

    @ViewBuilder private var text: some View {
        switch model.state {
        case .loading:
            excerpt
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(cornerRadius: 8).frame(height: 72) }
            }
            .padding(.horizontal, 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chargement du texte")
        case .loaded:
            ForEach(rendered) { block in
                ArticleBlockView(block: block.kind, zoom: zoom, play: play) {
                    pushed = .article(.stub($0.url, title: $0.title))
                }
            }
            .tint(EFTextColor.accentDark.color)
        case .failed(let failure):
            excerpt
            failed(failure)
        }
    }

    @ViewBuilder private var excerpt: some View {
        let paragraphs = article.body.isEmpty ? [article.excerpt].filter { !$0.isEmpty } : article.body
        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
            // 17 pt, line height about 1.5.
            Text(paragraph).efText(.body).lineSpacing(8).foregroundStyle(EFTextColor.ink.color)
                .padding(.horizontal, 16)
        }
    }

    /// Never a silent Safari: the site is a choice, offered only when the page cannot be read (ADR-007).
    private func failed(_ failure: ArticleReaderModel.Failure) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(failure == .offline ? "Article complet indisponible hors ligne"
                                     : "Impossible d'afficher cet article dans l'app")
                .efText(.strongLabel)
                .foregroundStyle(EFTextColor.ink.color)
            SecondaryButton("Réessayer") { Task { await model.retry() } }
            if model.showsOpenOnSite {
                Button("Ouvrir sur le site ↗\u{FE0E}") { safariURL = SafariItem(url: article.link) }
                    .efText(.strongLabel)
                    .foregroundStyle(EFTextColor.accentDark.color)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Actions

    private func zoom(_ image: ArticleImage) {
        // Reduce Motion: no slide-up, the picture fades in.
        var transaction = Transaction()
        transaction.disablesAnimations = reduceMotion
        withTransaction(transaction) { zoomed = ZoomItem(image: image) }
    }

    /// Third-party content loads only now, in a Safari sheet (no inline player: no third-party tracker
    /// in the article, NFR-005).
    private func play(_ embed: Embed) {
        model.activateEmbed(embed.url)
        open(embed.url)
    }

    private func open(_ url: URL) {
        switch model.destination(for: url) {
        case .article(let address): pushed = .article(.stub(address))
        case .festival(let slug): Task { await openFestival(slug, url: url) }
        // swiftlint:disable:next todo
        // TODO(STORY-057/059): author, artist, category and tag screens; the site until they exist.
        case .author, .artist, .category, .tag: safariURL = SafariItem(url: url)
        case .external(let address): safariURL = SafariItem(url: address)
        case .system(let address): openURL(address)
        case .ignored: break
        }
    }

    /// E5 when the catalogue has a festival of that slug, otherwise its page on the site.
    private func openFestival(_ slug: String, url: URL) async {
        let festivals = (try? await environment.festivals.festivals(updatedSince: nil)) ?? []
        if festivals.contains(where: { $0.id == slug }) {
            pushed = .festival(slug)
        } else {
            safariURL = SafariItem(url: url)
        }
    }
}

private enum ReaderPush: Hashable {
    case article(Article)
    case festival(Festival.ID)
}

private struct ZoomItem: Identifiable {
    let image: ArticleImage
    var id: URL { image.url }
}

extension Article {
    /// The date of an article known only by its address: the reader fills in the rest.
    static let stubDate = Date.distantPast

    /// An article known only by its address (a link in another article).
    static func stub(_ url: URL, title: String = "") -> Article {
        Article(
            id: ArticleKey(url: url).rawValue, title: title, link: url, category: Category(rawValue: ""),
            author: "", publishedAt: stubDate, imageURL: nil)
    }
}
