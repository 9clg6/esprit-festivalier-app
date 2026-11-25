import SwiftUI

/// Uppercase section title with an optional "Tout voir" link (an action, or a navigation value).
public struct SectionHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let title: String
    private let seeAll: AnyView?

    public init(_ title: String, seeAll: (() -> Void)? = nil) {
        self.title = title
        self.seeAll = seeAll.map { action in AnyView(Button(action: action) { Self.seeAllLabel }.buttonStyle(.plain)) }
    }

    /// "Tout voir" pushes `value` on the enclosing `NavigationStack`.
    public init<Value: Hashable>(_ title: String, seeAllValue value: Value) {
        self.title = title
        self.seeAll = AnyView(NavigationLink(value: value) { Self.seeAllLabel }.buttonStyle(.plain))
    }

    private static var seeAllLabel: some View {
        Text("Tout voir")
            .efText(.bodySecondary)
            .foregroundStyle(EFTextColor.accentDark.color)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }

    public var body: some View {
        // Accessibility sizes: "Tout voir" under the title, so the title keeps its words whole.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
        layout {
            Text(title)
                .efText(.sectionHeader)
                .foregroundStyle(EFTextColor.ink2.color)
                .accessibilityAddTraits(.isHeader)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            seeAll
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
