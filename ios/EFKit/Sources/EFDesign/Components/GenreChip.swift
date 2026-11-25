import SwiftUI

/// Filter pill. Selected: white on `accentFill`.
public struct GenreChip: View {
    private let title: String
    private let isSelected: Bool
    private let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .efText(.bodySecondary)
                .foregroundStyle(isSelected ? EFTextColor.onFill.color : EFTextColor.ink.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background((isSelected ? EFColorToken.accentFill : .sky).color, in: Capsule())
                .frame(minHeight: 44) // tap target
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Light") { GenreChipSample() }
#Preview("Dark") { GenreChipSample().preferredColorScheme(.dark) }
#Preview("AX3") { GenreChipSample().dynamicTypeSize(.accessibility3) }

private struct GenreChipSample: View {
    var body: some View {
        HStack {
            GenreChip("Électro", isSelected: false) {}
            GenreChip("Rock", isSelected: true) {}
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
