import SwiftUI

/// One reaction of the article's bar. Neutral: `ink2` on `sky`; selected: white on `accentFill` with
/// a checkmark (never the colour alone); the emoji bounces 0.3 s when selected, unless Reduce Motion.
/// The count shows only when known and above zero ("1,2 k" past 999). VoiceOver reads the label,
/// "Sélectionné" and the count, never the emoji. 44 pt tall.
public struct ReactionPill: View {
    private let emoji: String
    private let label: String
    private let count: Int?
    private let isSelected: Bool
    private let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped when the pill becomes selected: the emoji's 0.3 s bounce.
    @State private var bounces = 0

    public init(emoji: String, label: String, count: Int?, isSelected: Bool, action: @escaping () -> Void) {
        self.emoji = emoji
        self.label = label
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
                Text(emoji).font(EFTextStyle.body.font)
                    .keyframeAnimator(initialValue: 1.0, trigger: bounces) { emoji, scale in
                        emoji.scaleEffect(scale)
                    } keyframes: { _ in
                        CubicKeyframe(1.3, duration: 0.15)
                        CubicKeyframe(1.0, duration: 0.15)
                    }
                Text(label).efText(isSelected ? .strongLabel : .bodySecondary)
                if let shown { Text(shown).efText(.strongLabel) }
            }
            .foregroundStyle(isSelected ? EFTextColor.onFill.color : EFTextColor.ink2.color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background((isSelected ? EFColorToken.accentFill : .sky).color, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onChange(of: isSelected) { _, selected in
            if selected, !reduceMotion { bounces += 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(count.map { $0 > 0 ? "\($0) réaction\($0 > 1 ? "s" : "")" : "" } ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// nil for no count and for 0: the pill never says "0".
    private var shown: String? {
        guard let count, count > 0 else { return nil }
        guard count > 999 else { return "\(count)" }
        let thousands = (Double(count) / 1000).formatted(
            .number.precision(.fractionLength(0...1)).locale(Locale(identifier: "fr_FR"))
        )
        return "\(thousands) k"
    }
}

#Preview("Light") { ReactionPillSample() }
#Preview("Dark") { ReactionPillSample().preferredColorScheme(.dark) }
#Preview("AX3") { ReactionPillSample().dynamicTypeSize(.accessibility3) }

private struct ReactionPillSample: View {
    var body: some View {
        VStack(alignment: .leading) {
            ReactionPill(emoji: "❤️", label: "J'adore", count: 12, isSelected: true) {}
            ReactionPill(emoji: "🔥", label: "Ça chauffe", count: 1_234, isSelected: false) {}
            ReactionPill(emoji: "👏", label: "Bravo", count: nil, isSelected: false) {}
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
