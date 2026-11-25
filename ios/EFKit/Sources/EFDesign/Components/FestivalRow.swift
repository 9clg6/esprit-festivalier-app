import SwiftUI

/// Festival list row: 64 pt thumbnail, name, "13–15 juin 2027 · City", optional genres.
/// One VoiceOver element. Dates are shown in fr_FR, Europe/Paris.
public struct FestivalRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let name: String
    private let startDate: Date
    private let endDate: Date
    private let city: String
    private let imageURL: URL?
    private let genres: [String]
    private let favorite: (isOn: Bool, toggle: () -> Void)?

    /// `favorite`: when given, a heart sits at the trailing edge. VoiceOver still reads one element,
    /// ending with ", en favori" when on, and the heart is its "Ajouter / Retirer des favoris" action.
    public init(
        name: String, startDate: Date, endDate: Date, city: String,
        imageURL: URL? = nil, genres: [String] = [], favorite: (isOn: Bool, toggle: () -> Void)? = nil
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.city = city
        self.imageURL = imageURL
        self.genres = genres
        self.favorite = favorite
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            content
            if let favorite {
                FavoriteButton(isFavorite: favorite.isOn, action: favorite.toggle)
                    .padding(.trailing, 4)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EFColorToken.card.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if let favorite {
                Button(favorite.isOn ? "Retirer des favoris" : "Ajouter aux favoris", action: favorite.toggle)
            }
        }
    }

    private var accessibilityText: String {
        let parts = [name, FestivalDates.text(from: startDate, to: endDate), city] + genres
        return parts.joined(separator: ", ") + (favorite?.isOn == true ? ", en favori" : "")
    }

    @ViewBuilder private var content: some View {
        // Accessibility sizes: thumbnail above the text, so long names keep the full width.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .efText(.title3)
                    .foregroundStyle(EFTextColor.ink.color)
                Text("\(FestivalDates.text(from: startDate, to: endDate)) · \(city)")
                    .efText(.bodySecondary)
                    .foregroundStyle(EFTextColor.ink2.color)
                if !genres.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(genres, id: \.self) { genre in
                            Text(genre)
                                .efText(.caption)
                                .foregroundStyle(EFTextColor.ink.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(EFColorToken.sky.color, in: Capsule())
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thumbnail: some View {
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                // Placeholder while loading, on failure, and when there is no image.
                ZStack {
                    EFColorToken.thumb.color
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(EFTextColor.muted.color)
                }
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

#Preview("Light") { FestivalRowSample() }
#Preview("Dark") { FestivalRowSample().preferredColorScheme(.dark) }
#Preview("AX3") { FestivalRowSample().dynamicTypeSize(.accessibility3) }

private struct FestivalRowSample: View {
    private let start = Date(timeIntervalSince1970: 1_812_000_000)

    var body: some View {
        VStack(spacing: 12) {
            FestivalRow(name: "Hellfest", startDate: start, endDate: start.addingTimeInterval(172_800), city: "Clisson",
                        genres: ["Metal", "Rock"])
            FestivalRow(name: "Les Vieilles Charrues", startDate: start, endDate: start.addingTimeInterval(86_400),
                        city: "Carhaix")
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
