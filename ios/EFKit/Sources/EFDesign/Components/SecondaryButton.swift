import SwiftUI

/// Soft pill button: `accentDark` text on `sky`.
public struct SecondaryButton: View {
    private let title: String
    private let action: () -> Void

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(title, action: action).buttonStyle(SecondaryButtonStyle())
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .efText(.strongLabel)
            .foregroundStyle(EFTextColor.accentDark.color)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background((configuration.isPressed ? EFColorToken.sky2 : .sky).color, in: Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .contentShape(Capsule())
    }
}

#Preview("Light") { SecondaryButtonSample() }
#Preview("Dark") { SecondaryButtonSample().preferredColorScheme(.dark) }
#Preview("AX3") { SecondaryButtonSample().dynamicTypeSize(.accessibility3) }

private struct SecondaryButtonSample: View {
    var body: some View {
        VStack(spacing: 16) {
            SecondaryButton("Voir la carte") {}
            SecondaryButton("Indisponible") {}.disabled(true)
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
