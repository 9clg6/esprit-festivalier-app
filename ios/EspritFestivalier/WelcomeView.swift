import EFDesign
import SwiftUI

/// E15: one screen, no permission request.
struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.house")
                .font(.system(size: 56))
                .foregroundStyle(EFColorToken.accent.color)
                .accessibilityHidden(true)
            Text("Esprit Festivalier")
                .efText(.largeTitle)
                .foregroundStyle(EFTextColor.ink.color)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Le média des festivals, par ceux qui les vivent")
                .efText(.body)
                .foregroundStyle(EFTextColor.ink2.color)
                .multilineTextAlignment(.center)
            Spacer()
            PrimaryButton("Trouve ton prochain festival", action: onStart)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EFColorToken.bg.color)
    }
}

#Preview("Light") { WelcomeView {} }
#Preview("AX3") { WelcomeView {}.dynamicTypeSize(.accessibility3) }
