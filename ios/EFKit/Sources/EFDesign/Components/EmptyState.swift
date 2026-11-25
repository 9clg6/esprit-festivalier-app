import SwiftUI

/// A useful sentence and, optionally, one action.
public struct EmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let action: (title: String, run: () -> Void)?

    public init(
        systemImage: String, title: String, message: String,
        actionTitle: String? = nil, action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.action = actionTitle.flatMap { title in action.map { (title, $0) } }
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(EFColorToken.accent.color)
                .accessibilityHidden(true)
            Text(title)
                .efText(.title2)
                .foregroundStyle(EFTextColor.ink.color)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .efText(.body)
                .foregroundStyle(EFTextColor.ink2.color)
                .multilineTextAlignment(.center)
            if let action {
                SecondaryButton(action.title, action: action.run).padding(.top, 8)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Light") { EmptyStateSample() }
#Preview("Dark") { EmptyStateSample().preferredColorScheme(.dark) }
#Preview("AX3") { EmptyStateSample().dynamicTypeSize(.accessibility3) }

private struct EmptyStateSample: View {
    var body: some View {
        EmptyState(systemImage: "calendar", title: "Aucun festival", message: "Reviens bientôt.",
                   actionTitle: "Réessayer") {}
            .background(EFColorToken.bg.color)
    }
}
