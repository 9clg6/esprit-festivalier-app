import CoreText
import SwiftUI

/// Registers the bundled fonts for the process. Safe to call more than once.
public enum EFFonts {
    private static let files = ["Chivo-Black", "Chivo-Bold", "Raleway-Bold", "OpenSans"]
    private static let registered: Void = {
        for file in files {
            let url = Bundle.module.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts")
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    public static func register() { _ = registered }

    static func custom(_ name: String, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        register()
        return .custom(name, size: size, relativeTo: style)
    }
}

/// Type scale from the UX doc ("Tokens > Typographie"), linked to Dynamic Type.
public enum EFTextStyle: CaseIterable, Sendable {
    case largeTitle, title1, title2, title3, strongLabel, body, bodySecondary, sectionHeader, caption

    public var postScriptName: String {
        switch self {
        case .largeTitle: "Chivo-Black"
        case .title1, .title2, .title3: "Chivo-Bold"
        case .strongLabel, .sectionHeader: "Raleway-Bold"
        case .body, .bodySecondary, .caption: "OpenSans-Regular"
        }
    }

    public var size: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title1: 28
        case .title2: 22
        case .title3: 20
        case .strongLabel, .body: 17
        case .bodySecondary: 15
        case .sectionHeader: 13
        case .caption: 12
        }
    }

    public var relativeTo: Font.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title1: .title
        case .title2: .title2
        case .title3: .title3
        case .strongLabel: .headline
        case .body: .body
        case .bodySecondary: .subheadline
        case .sectionHeader: .footnote
        case .caption: .caption
        }
    }

    public var isUppercase: Bool { self == .sectionHeader }
    public var trackingEm: CGFloat { self == .sectionHeader ? 0.06 : 0 }

    public var font: Font {
        EFFonts.custom(postScriptName, size: size, relativeTo: relativeTo)
    }
}

extension View {
    /// Font, tracking and casing of an `EFTextStyle`.
    public func efText(_ style: EFTextStyle) -> some View {
        font(style.font)
            .tracking(style.trackingEm * style.size)
            .textCase(style.isUppercase ? .uppercase : nil)
    }
}
