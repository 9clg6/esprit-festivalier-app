import EFDesign
import EFDomain
import SwiftUI

/// E11: reads the excerpt or text the feed carries, then sends the reader to the site.
struct ArticleView: View {
    let article: Article
    let environment: AppEnvironment
    @State private var safariURL: SafariItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = article.imageURL {
                    // Full bleed under the status bar and the navigation bar, like E5.
                    EFColorToken.thumb.color
                        .frame(height: 320)
                        .overlay {
                            AsyncImage(url: imageURL) { phase in
                                if let image = phase.image { image.resizable().scaledToFill() }
                            }
                        }
                        .overlay { HeroScrim() }
                        .clipped()
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Text(article.category.rawValue).efText(.sectionHeader)
                            .foregroundStyle(EFTextColor.accentDark.color)
                        if article.isSponsored { Badge("Sponsorisé") }
                    }
                    Text(article.title).efText(.title1).foregroundStyle(EFTextColor.ink.color)
                        .accessibilityAddTraits(.isHeader)
                    Text(byline).efText(.bodySecondary).foregroundStyle(EFTextColor.ink2.color)
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        // 17 pt, line height about 1.5.
                        Text(paragraph).efText(.body).lineSpacing(8).foregroundStyle(EFTextColor.ink.color)
                    }
                    ReactionBar(article: article.id, service: environment.reactions).padding(.top, 8)
                    PrimaryButton("Lire l'article complet") { safariURL = SafariItem(url: article.link) }
                        .padding(.top, 8)
                    ShareLink(item: article.link) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                            .efText(.strongLabel)
                            .foregroundStyle(EFTextColor.accentDark.color)
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 680, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        // Without a photo the article starts below the bar.
        .ignoresSafeArea(edges: article.imageURL == nil ? [] : .top)
        .background(EFColorToken.bg.color)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { SafariView(url: $0.url, readerMode: true).ignoresSafeArea() }
        .task {
            // Anonymous: the article and the Paris day only (FR-036), once per day on this device.
            // swiftlint:disable:next todo
            // TODO(STORY-030): skip when the audience-measurement setting is off; counted by default until it exists.
            try? await environment.reads.record(article.id, at: Date())
        }
    }

    private var paragraphs: [String] {
        article.body.isEmpty ? [article.excerpt].filter { !$0.isEmpty } : article.body
    }

    private var byline: String {
        let day = article.publishedAt.formatted(
            .dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "fr_FR")))
        return article.author.isEmpty ? day : "\(article.author) · \(day)"
    }
}
