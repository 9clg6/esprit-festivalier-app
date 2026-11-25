import SwiftUI

/// Uppercase section title with an optional "Tout voir" link.
public struct SectionHeader: View {
    private let title: String
    private let seeAll: (() -> Void)?

    public init(_ title: String, seeAll: (() -> Void)? = nil) {
        self.title = title
        self.seeAll = seeAll
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .efText(.sectionHeader)
                .foregroundStyle(EFTextColor.ink2.color)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let seeAll {
                Button(action: seeAll) {
                    Text("Tout voir")
                        .efText(.bodySecondary)
                        .foregroundStyle(EFTextColor.accentDark.color)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview("Light") { SectionHeaderSample() }
#Preview("Dark") { SectionHeaderSample().preferredColorScheme(.dark) }
#Preview("AX3") { SectionHeaderSample().dynamicTypeSize(.accessibility3) }

private struct SectionHeaderSample: View {
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader("À la une") {}
            SectionHeader("Prochains festivals")
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
