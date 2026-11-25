import EFDesign
import EFDomain
import SwiftUI

/// E11: reads the excerpt or text the feed carries, then sends the reader to the site.
struct ArticleView: View {
    let article: Article
    @State private var safariURL: SafariItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EFColorToken.thumb.color
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: article.imageURL) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                        }
                    }
                    .clipped()
                    .accessibilityHidden(true)
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
        .background(EFColorToken.bg.color)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $safariURL) { SafariView(url: $0.url, readerMode: true).ignoresSafeArea() }
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
