import SwiftUI

/// "Hors ligne · données du 12 juin à 18:04", under the navigation bar.
public struct OfflineBanner: View {
    private let cachedAt: Date

    public init(cachedAt: Date) { self.cachedAt = cachedAt }

    public var body: some View {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone(identifier: "Europe/Paris")
        formatter.dateFormat = "d MMMM 'à' HH:mm"
        return Text("Hors ligne · données du \(formatter.string(from: cachedAt))")
            .efText(.bodySecondary)
            .foregroundStyle(EFTextColor.ink2.color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EFColorToken.sky.color)
    }
}

#Preview("Light") { OfflineBannerSample() }
#Preview("Dark") { OfflineBannerSample().preferredColorScheme(.dark) }
#Preview("AX3") { OfflineBannerSample().dynamicTypeSize(.accessibility3) }

private struct OfflineBannerSample: View {
    var body: some View {
        OfflineBanner(cachedAt: Date(timeIntervalSince1970: 1_812_000_000))
    }
}
