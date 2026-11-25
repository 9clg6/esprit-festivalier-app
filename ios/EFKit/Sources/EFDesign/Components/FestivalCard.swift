import SwiftUI

/// Home carousel card: 16:9 visual, name, dates, artist count. One VoiceOver element.
public struct FestivalCard: View {
    private let imageURL: URL?
    private let name: String
    private let startDate: Date
    private let endDate: Date
    private let artistCount: Int

    public init(imageURL: URL?, name: String, startDate: Date, endDate: Date, artistCount: Int) {
        self.imageURL = imageURL
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.artistCount = artistCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FestivalVisual(imageURL: imageURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).efText(.strongLabel).foregroundStyle(EFTextColor.ink.color)
                Text(FestivalDates.text(from: startDate, to: endDate))
                    .efText(.bodySecondary).foregroundStyle(EFTextColor.ink2.color)
                Text(artists).efText(.caption).foregroundStyle(EFTextColor.muted.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EFColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([name, FestivalDates.text(from: startDate, to: endDate), artists].joined(separator: ", "))
    }

    private var artists: String { artistCount == 1 ? "1 artiste" : "\(artistCount) artistes" }
}

/// A festival's 16:9 visual, decorative for VoiceOver; a music note on `thumb` without image.
public struct FestivalVisual: View {
    private let imageURL: URL?

    public init(imageURL: URL?) { self.imageURL = imageURL }

    public var body: some View {
        EFColorToken.thumb.color
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "music.note").font(.title2).foregroundStyle(EFTextColor.muted.color)
                    }
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview("Light") { FestivalCardSample() }
#Preview("Dark") { FestivalCardSample().preferredColorScheme(.dark) }
#Preview("AX3") { FestivalCardSample().dynamicTypeSize(.accessibility3) }

private struct FestivalCardSample: View {
    private let start = Date(timeIntervalSince1970: 1_812_000_000)

    var body: some View {
        FestivalCard(imageURL: nil, name: "Hellfest", startDate: start, endDate: start.addingTimeInterval(259_200),
                     artistCount: 12)
            .frame(width: 240)
            .padding(16)
            .background(EFColorToken.bg.color)
    }
}
