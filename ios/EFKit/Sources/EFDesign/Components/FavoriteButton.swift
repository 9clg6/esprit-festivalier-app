import SwiftUI

/// Heart toggle: outline or filled, 44 pt, light haptic and a short bounce (none with Reduce Motion).
public struct FavoriteButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isFavorite: Bool
    private let action: () -> Void

    public init(isFavorite: Bool, action: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(EFColorToken.accentDark.color)
                .symbolEffect(.bounce, value: reduceMotion ? false : isFavorite)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
    }
}

#Preview("Light") { FavoriteButtonSample() }
#Preview("Dark") { FavoriteButtonSample().preferredColorScheme(.dark) }

private struct FavoriteButtonSample: View {
    @State private var isFavorite = true

    var body: some View {
        HStack {
            FavoriteButton(isFavorite: false) {}
            FavoriteButton(isFavorite: isFavorite) { isFavorite.toggle() }
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
