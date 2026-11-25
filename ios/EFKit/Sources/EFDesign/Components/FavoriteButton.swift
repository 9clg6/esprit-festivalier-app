import SwiftUI

/// Heart toggle: outline or filled, 44 pt. A light haptic and a short bounce (no bounce with Reduce
/// Motion) only when a tap fills the heart: not on removal, first display or a reverted write.
public struct FavoriteButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isFavorite: Bool
    private let action: () -> Void
    @State private var fills = 0

    public init(isFavorite: Bool, action: @escaping () -> Void) {
        self.isFavorite = isFavorite
        self.action = action
    }

    public var body: some View {
        Button {
            if !isFavorite { fills += 1 }
            action()
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.title3)
                .foregroundStyle(EFColorToken.accentDark.color)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : fills)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: fills)
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
