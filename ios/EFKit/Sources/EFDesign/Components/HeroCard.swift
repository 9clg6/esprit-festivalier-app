import SwiftUI

/// "À la une": large photo, category and title in white on a `night` gradient. One VoiceOver element.
public struct HeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let imageURL: URL?
    private let category: String
    private let title: String

    public init(imageURL: URL?, category: String, title: String) {
        self.imageURL = imageURL
        self.category = category
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(category).efText(.sectionHeader)
            Text(title).efText(.title2).lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
        }
        .foregroundStyle(EFTextColor.onFill.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .padding(.top, 72)
        // Behind the text the gradient is at least 85 % `night`: white stays above 4.5:1 on any photo.
        .background(
            LinearGradient(
                stops: [.init(color: EFColorToken.night.color.opacity(0), location: 0),
                        .init(color: EFColorToken.night.color.opacity(0.85), location: 0.45),
                        .init(color: EFColorToken.night.color.opacity(0.95), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .bottom)
        .background { photo }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category), \(title)")
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
