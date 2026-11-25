import EFDesign
import SwiftUI

/// E14: explains why a permission is asked, before the iOS prompt (position, notifications).
struct PermissionSheet: View {
    let systemImage: String
    let title: String
    let examples: [String]
    let onActivate: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 56))
                    .foregroundStyle(EFColorToken.accent.color)
                    .accessibilityHidden(true)
                Text(title)
                    .efText(.title2)
                    .foregroundStyle(EFTextColor.ink.color)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(examples, id: \.self, content: line)
                }
                PrimaryButton("Activer", action: onActivate).padding(.top, 8)
                Button("Plus tard", action: onLater)
                    .efText(.strongLabel)
                    .foregroundStyle(EFTextColor.accentDark.color)
                    .frame(minHeight: 44)
            }
            .padding(24)
        }
        .background(EFColorToken.bg.color)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func line(_ text: String) -> some View {
        Label {
            Text(text).efText(.body).foregroundStyle(EFTextColor.ink2.color)
        } icon: {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(EFColorToken.accent.color)
        }
    }
}

extension View {
    /// The E14 sheet and the "refused" offer, shown by the view that is on top (`isOn`).
    func aroundMePrompts(_ aroundMe: AroundMe, isOn: Bool = true, chooseRegion: @escaping () -> Void) -> some View {
        @Bindable var aroundMe = aroundMe
        return sheet(isPresented: Binding(
            get: { isOn && aroundMe.showExplanation }, set: { if !$0 { aroundMe.declineExplanation() } }
        )) {
            PermissionSheet(
                systemImage: "location.circle.fill", title: "Festivals autour de toi",
                examples: [
                    "Les festivals à moins de 25, 50 ou 100 km", "Le plus proche ce week-end",
                    "Ta position reste sur ton téléphone"
                ],
                onActivate: aroundMe.confirmExplanation, onLater: aroundMe.declineExplanation
            )
        }
        .alert("Position désactivée", isPresented: Binding(
            get: { isOn && aroundMe.showDenied }, set: { aroundMe.showDenied = $0 }
        )) {
            Button("Choisir une région", action: chooseRegion)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Autorise la position dans Réglages, ou choisis une région.")
        }
    }
}
