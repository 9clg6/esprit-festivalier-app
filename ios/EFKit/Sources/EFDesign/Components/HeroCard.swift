import SwiftUI

/// "À la une": large photo, category and title in white on a `night` gradient. One VoiceOver element.
public struct HeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let imageURL: URL?
    private let category: String
    private let title: String
    private let isSponsored: Bool

    public init(imageURL: URL?, category: String, title: String, isSponsored: Bool = false) {
        self.imageURL = imageURL
        self.category = category
        self.title = title
        self.isSponsored = isSponsored
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(category).efText(.sectionHeader)
                if isSponsored { Badge("Sponsorisé") }
            }
            Text(title).efText(.title2).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
        }
        .foregroundStyle(EFTextColor.onFill.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        // Solid 85 % `night` behind the text, whatever its height (AX sizes): white stays above 4.5:1
        // on any photo. A fixed 72 pt ramp above it fades into the photo.
        .background(EFColorToken.night.color.opacity(0.85))
        .background(alignment: .top) {
            LinearGradient(
                colors: [EFColorToken.night.color.opacity(0), EFColorToken.night.color.opacity(0.85)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 72)
            .offset(y: -72)
        }
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .bottom)
        .background { photo }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(isSponsored ? "Sponsorisé, " : "")\(category), \(title)")
        .accessibilityAddTraits(.isButton)
    }

    private var photo: some View {
        EFColorToken.deep.color.overlay {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
            }
        }
        .clipped()
    }
}

#Preview("Light") { HeroCardSample() }
#Preview("Dark") { HeroCardSample().preferredColorScheme(.dark) }
#Preview("AX3") { HeroCardSample().dynamicTypeSize(.accessibility3) }

private struct HeroCardSample: View {
    var body: some View {
        HeroCard(imageURL: nil, category: "Live report", title: "Orelsan séduit même les novices à Nantes")
            .padding(16)
            .background(EFColorToken.bg.color)
    }
}
