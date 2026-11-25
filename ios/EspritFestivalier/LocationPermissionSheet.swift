import EFDesign
import SwiftUI

/// E14: explains why the position is asked, before the iOS prompt.
struct LocationPermissionSheet: View {
    let onActivate: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(EFColorToken.accent.color)
                    .accessibilityHidden(true)
                Text("Festivals autour de toi")
                    .efText(.title2)
                    .foregroundStyle(EFTextColor.ink.color)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 8) {
                    line("Les festivals à moins de 25, 50 ou 100 km")
                    line("Le plus proche ce week-end")
                    line("Ta position reste sur ton téléphone")
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
            LocationPermissionSheet(onActivate: aroundMe.confirmExplanation, onLater: aroundMe.declineExplanation)
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
