import SwiftUI

/// Gradient over a full-bleed hero photo that runs under the status bar and the navigation bar.
/// Top: page colour, so the status bar and the back button stay legible on a bright photo, light and dark.
/// Bottom (optional): night shade for a caption such as the photo credit.
public struct HeroScrim: View {
    private let shadesBottom: Bool

    public init(shadesBottom: Bool = false) {
        self.shadesBottom = shadesBottom
    }

    public var body: some View {
        let top: [Gradient.Stop] = [.init(color: EFColorToken.bg.color.opacity(0.8), location: 0),
                                    .init(color: .clear, location: 0.22)]
        let bottom: [Gradient.Stop] = shadesBottom
            ? [.init(color: .clear, location: 0.6), .init(color: EFColorToken.night.color.opacity(0.85), location: 1)]
            : []
        LinearGradient(stops: top + bottom, startPoint: .top, endPoint: .bottom)
            .accessibilityHidden(true)
    }
}
