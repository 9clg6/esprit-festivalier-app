import SwiftUI

/// Highlight label ("Partenaire", "Premium"...). Fixed dark text on `sun`.
public struct Badge: View {
    private let title: String

    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title)
            .font(EFFonts.custom("Raleway-Bold", size: 12, relativeTo: .caption))
            .foregroundStyle(EFTextColor.onSun.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(EFColorToken.sun.color, in: Capsule())
    }
}

#Preview("Light") { BadgeSample() }
#Preview("Dark") { BadgeSample().preferredColorScheme(.dark) }
#Preview("AX3") { BadgeSample().dynamicTypeSize(.accessibility3) }

private struct BadgeSample: View {
    var body: some View {
        HStack {
            Badge("Partenaire")
            Badge("Premium")
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
