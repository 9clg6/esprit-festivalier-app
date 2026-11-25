import SwiftUI

/// Design-system colours from docs/design/direction-artistique.md, defined once as hex light/dark pairs.
public enum EFColorToken: CaseIterable, Sendable {
    // Icons and large titles only. Text uses `EFTextColor`, buttons use `accentFill`.
    case accent, accentDark, accentFill, deep, night, sun
    case sky, sky2, ink, ink2, muted, line, card, hover, thumb
    case bg // swiftlint:disable:this identifier_name

    var hex: (light: UInt32, dark: UInt32) {
        switch self {
        case .accent: (0x1d9fc9, 0x1d9fc9)
        case .accentDark: (0x14728f, 0x5cc3e4)
        case .accentFill: (0x14728f, 0x14728f)
        case .deep: (0x0b3d63, 0x0b3d63)
        case .night: (0x071e33, 0x071e33)
        case .sun: (0xffd23f, 0xffd23f)
        case .sky: (0xe6f4fa, 0x12283a)
        case .sky2: (0xd2ebf5, 0x173548)
        case .ink: (0x0e1a26, 0xeef4f8)
        case .ink2: (0x2f3d4a, 0xcbd7e1)
        case .muted: (0x5f7180, 0x93a6b6)
        case .line: (0xdbe6ee, 0x22313f)
        case .bg: (0xf3f8fb, 0x0b131b)
        case .card: (0xffffff, 0x131e29)
        case .hover: (0xe9f2f8, 0x1a2836)
        case .thumb: (0xd9e8f0, 0x1c2a38)
        }
    }

    /// Follows the colour scheme (iOS and macOS).
    public var color: Color { Color(light: hex.light, dark: hex.dark) }
}

/// Colours allowed for text. `accent` is deliberately absent (3.1:1 on white).
public enum EFTextColor: CaseIterable, Sendable {
    case ink, ink2, muted, accentDark, onFill, onSun

    public var color: Color {
        switch self {
        case .ink: EFColorToken.ink.color
        case .ink2: EFColorToken.ink2.color
        case .muted: EFColorToken.muted.color
        case .accentDark: EFColorToken.accentDark.color
        case .onFill: Color(light: 0xffffff, dark: 0xffffff)
        case .onSun: Color(light: 0x0e1a26, dark: 0x0e1a26)
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .init(hex: dark) : .init(hex: light) })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .init(hex: dark) : .init(hex: light)
        })
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
#else
private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
#endif
