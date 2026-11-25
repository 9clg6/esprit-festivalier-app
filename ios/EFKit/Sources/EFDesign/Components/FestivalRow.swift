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

    public init(
        name: String, startDate: Date, endDate: Date, city: String,
        imageURL: URL? = nil, genres: [String] = []
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.city = city
        self.imageURL = imageURL
        self.genres = genres
    }

    public var body: some View {
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
                Text("\(Self.dates(startDate, endDate)) · \(city)")
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
        .background(EFColorToken.card.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([name, Self.dates(startDate, endDate), city] + genres).joined(separator: ", "))
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

    private static let locale = Locale(identifier: "fr_FR")
    private static let paris = TimeZone(identifier: "Europe/Paris") ?? .current

    static func dates(_ start: Date, _ end: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = paris
        calendar.locale = locale
        return (start..<max(start, end)).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: paris)
                .day().month(.wide).year()
        )
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
