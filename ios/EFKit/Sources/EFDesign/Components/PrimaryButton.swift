import SwiftUI

/// Filled pill button. White text on `accentFill`; `accent` itself is never a text background.
public struct PrimaryButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action).buttonStyle(PrimaryButtonStyle())
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .efText(.strongLabel)
            .foregroundStyle(EFTextColor.onFill.color)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 50)
            // Pressed uses `deep`, not `accentDark`: white on dark-mode accentDark would fail AA.
            .background((configuration.isPressed ? EFColorToken.deep : .accentFill).color, in: Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

#Preview("Light") { PrimaryButtonSample() }
#Preview("Dark") { PrimaryButtonSample().preferredColorScheme(.dark) }
#Preview("AX3") { PrimaryButtonSample().dynamicTypeSize(.accessibility3) }

private struct PrimaryButtonSample: View {
    var body: some View {
        VStack(spacing: 16) {
            PrimaryButton("Voir le festival") {}
            PrimaryButton("Indisponible") {}.disabled(true)
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
