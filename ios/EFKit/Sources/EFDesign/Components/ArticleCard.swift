import SwiftUI

/// Article list card: 16:9 image, category, title, "Author · 25 nov. 2026", optional "Sponsorisé" badge.
/// One VoiceOver element. Dates are shown in fr_FR, Europe/Paris.
public struct ArticleCard: View {
    private let imageURL: URL?
    private let category: String
    private let title: String
    private let author: String
    private let date: Date
    private let isSponsored: Bool

    public init(
        imageURL: URL?, category: String, title: String, author: String, date: Date, isSponsored: Bool = false
    ) {
        self.imageURL = imageURL
        self.category = category
        self.title = title
        self.author = author
        self.date = date
        self.isSponsored = isSponsored
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            image
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(category).efText(.sectionHeader).foregroundStyle(EFTextColor.accentDark.color)
                    if isSponsored { Badge("Sponsorisé") }
                }
                Text(title).efText(.title3).foregroundStyle(EFTextColor.ink.color)
                Text(byline).efText(.bodySecondary).foregroundStyle(EFTextColor.ink2.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EFColorToken.card.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            ([isSponsored ? "Sponsorisé" : nil, category, title, byline].compactMap { $0 }).joined(separator: ", ")
        )
    }

    private var byline: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "d MMM yyyy"
        let day = formatter.string(from: date)
        return author.isEmpty ? day : "\(author) · \(day)"
    }

    private var image: some View {
        EFColorToken.thumb.color
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "newspaper").font(.title).foregroundStyle(EFTextColor.muted.color)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview("Light") { ArticleCardSample() }
#Preview("Dark") { ArticleCardSample().preferredColorScheme(.dark) }
#Preview("AX3") { ArticleCardSample().dynamicTypeSize(.accessibility3) }

private struct ArticleCardSample: View {
    var body: some View {
        VStack(spacing: 12) {
            ArticleCard(
                imageURL: nil, category: "Live report", title: "Orelsan séduit même les novices à Nantes",
                author: "Mano Le Bris", date: Date(timeIntervalSince1970: 1_812_000_000))
            ArticleCard(
                imageURL: nil, category: "Actu", title: "Un article sponsorisé", author: "",
                date: Date(timeIntervalSince1970: 1_812_000_000), isSponsored: true)
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
