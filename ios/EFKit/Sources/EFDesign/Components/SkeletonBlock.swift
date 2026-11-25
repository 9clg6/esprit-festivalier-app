import SwiftUI

/// Loading placeholder on `thumb`. Pulses unless Reduce Motion is on.
public struct SkeletonBlock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dimmed = false
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 12) { self.cornerRadius = cornerRadius }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(EFColorToken.thumb.color)
            .opacity(dimmed ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dimmed = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Light") { SkeletonBlockSample() }
#Preview("Dark") { SkeletonBlockSample().preferredColorScheme(.dark) }
#Preview("AX3") { SkeletonBlockSample().dynamicTypeSize(.accessibility3) }

private struct SkeletonBlockSample: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonBlock().frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock().frame(height: 20)
                SkeletonBlock().frame(width: 140, height: 14)
            }
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
