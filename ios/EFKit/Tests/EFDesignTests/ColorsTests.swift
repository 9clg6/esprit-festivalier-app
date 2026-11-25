import SwiftUI
import Testing
import EFDesign

// Need: STORY-002, docs/design/direction-artistique.md ("Couleurs", "Règle de contraste")
// and docs/ux-design-esprit-festivalier-app-2026-11-25.md ("Contrastes vérifiés", "Composants", "Tokens").

// MARK: - Helpers (what the user sees: the colour SwiftUI renders in a given appearance)

private func rgbHex(_ color: Color, _ scheme: ColorScheme) -> String {
    var environment = EnvironmentValues()
    environment.colorScheme = scheme
    let resolved = color.resolve(in: environment)
    let channels = [resolved.red, resolved.green, resolved.blue]
        .map { Int((min(max($0, 0), 1) * 255).rounded()) }
    return "#" + channels.map { String(format: "%02x", $0) }.joined()
}

/// WCAG 2.1 relative luminance of an sRGB "#rrggbb" colour.
private func relativeLuminance(_ hex: String) -> Double {
    let value = Int(hex.dropFirst(), radix: 16)!
    let linear = [(value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff].map { channel -> Double in
        let c = Double(channel) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
}

/// WCAG 2.1 contrast ratio (L1 + 0.05) / (L2 + 0.05).
private func contrastRatio(_ a: String, _ b: String) -> Double {
    let (la, lb) = (relativeLuminance(a), relativeLuminance(b))
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
}

// Sanity of the ratio helper itself, against the WCAG reference points.
@Test func contrastHelperMatchesWCAGReferencePoints() {
    #expect(abs(contrastRatio("#000000", "#ffffff") - 21) < 0.001)
    #expect(abs(contrastRatio("#ffffff", "#ffffff") - 1) < 0.001)
    // DA doc: accent (#1d9fc9) "n'atteint que 3,1:1 sur blanc".
    #expect(abs(contrastRatio("#1d9fc9", "#ffffff") - 3.06) < 0.01)
}

// MARK: - Tokens resolve to the DA values

struct TokenCase: Sendable, CustomTestStringConvertible {
    let token: EFColorToken
    let light: String
    let dark: String
    var testDescription: String { "\(token)" }
}

// Copied from the DA table. "—" in the Sombre column is read as "same value as light"
// (the site's dark CSS does not override it): open question reported to the lead.
let daTokens: [TokenCase] = [
    TokenCase(token: .accent, light: "#1d9fc9", dark: "#1d9fc9"),
    TokenCase(token: .accentDark, light: "#14728f", dark: "#5cc3e4"),
    TokenCase(token: .accentFill, light: "#14728f", dark: "#14728f"),
    TokenCase(token: .deep, light: "#0b3d63", dark: "#0b3d63"),
    TokenCase(token: .night, light: "#071e33", dark: "#071e33"),
    TokenCase(token: .sun, light: "#ffd23f", dark: "#ffd23f"),
    TokenCase(token: .sky, light: "#e6f4fa", dark: "#12283a"),
    TokenCase(token: .sky2, light: "#d2ebf5", dark: "#173548"),
    TokenCase(token: .ink, light: "#0e1a26", dark: "#eef4f8"),
    TokenCase(token: .ink2, light: "#2f3d4a", dark: "#cbd7e1"),
    TokenCase(token: .muted, light: "#5f7180", dark: "#93a6b6"),
    TokenCase(token: .line, light: "#dbe6ee", dark: "#22313f"),
    TokenCase(token: .bg, light: "#f3f8fb", dark: "#0b131b"),
    TokenCase(token: .card, light: "#ffffff", dark: "#131e29"),
    TokenCase(token: .hover, light: "#e9f2f8", dark: "#1a2836"),
    TokenCase(token: .thumb, light: "#d9e8f0", dark: "#1c2a38"),
]

@Test func everyDATokenExistsAndNothingElse() {
    #expect(Set(EFColorToken.allCases.map { "\($0)" }) == Set(daTokens.map { "\($0.token)" }))
}

@Test(arguments: daTokens)
func tokenRendersTheDAColourInLightAppearance(_ c: TokenCase) {
    #expect(rgbHex(c.token.color, .light) == c.light)
}

@Test(arguments: daTokens)
func tokenRendersTheDAColourInDarkAppearance(_ c: TokenCase) {
    #expect(rgbHex(c.token.color, .dark) == c.dark)
}

// MARK: - Text colours: accent is never one of them

@Test func noTextColourRendersAsAccentInEitherAppearance() {
    for scheme in [ColorScheme.light, .dark] {
        let accent = rgbHex(EFColorToken.accent.color, scheme)
        for text in EFTextColor.allCases {
            #expect(rgbHex(text.color, scheme) != accent, "\(text) renders as accent in \(scheme)")
        }
    }
}

@Test func theAccentTextColourIsAccentDark() {
    #expect(rgbHex(EFTextColor.accentDark.color, .light) == "#14728f")
    #expect(rgbHex(EFTextColor.accentDark.color, .dark) == "#5cc3e4")
}

// Lead decision 2026-11-25: badge text is a fixed #0e1a26, never the dark ink (1.3:1 on sun).
@Test func textOnSunIsTheFixedDarkInkInBothAppearances() {
    #expect(rgbHex(EFTextColor.onSun.color, .light) == "#0e1a26")
    #expect(rgbHex(EFTextColor.onSun.color, .dark) == "#0e1a26")
}

@Test func textOnFilledButtonsIsWhiteInBothAppearances() {
    #expect(rgbHex(EFTextColor.onFill.color, .light) == "#ffffff")
    #expect(rgbHex(EFTextColor.onFill.color, .dark) == "#ffffff")
}

// MARK: - WCAG AA (4.5:1) for every text pair the UX doc allows, in both appearances

struct TextPair: Sendable, CustomTestStringConvertible {
    let text: EFTextColor
    let background: EFColorToken
    let source: String
    var testDescription: String { "\(text) on \(background) (\(source))" }
}

let allowedTextPairs: [TextPair] = [
    TextPair(text: .ink, background: .card, source: "Contrastes vérifiés: ink sur card"),
    TextPair(text: .muted, background: .card, source: "Contrastes vérifiés: muted sur card"),
    TextPair(text: .muted, background: .bg, source: "Contrastes vérifiés: muted sur bg"),
    TextPair(text: .accentDark, background: .card, source: "Contrastes vérifiés: accent-dark sur blanc / sur card"),
    TextPair(text: .onFill, background: .accentFill, source: "Contrastes vérifiés: blanc sur accent-fill, PrimaryButton, GenreChip"),
    TextPair(text: .onFill, background: .deep, source: "Contrastes vérifiés: blanc sur deep"),
    TextPair(text: .accentDark, background: .sky, source: "Composants: SecondaryButton"),
    TextPair(text: .ink2, background: .card, source: "DA: ink2 texte secondaire"),
    TextPair(text: .onSun, background: .sun, source: "Composants: Badge, alertes de conflit"),
]

@Test(arguments: allowedTextPairs, [ColorScheme.light, .dark])
func allowedTextPairReachesWCAGAA(_ pair: TextPair, _ scheme: ColorScheme) {
    let ratio = contrastRatio(rgbHex(pair.text.color, scheme), rgbHex(pair.background.color, scheme))
    #expect(ratio >= 4.5, "\(pair.testDescription) in \(scheme): \(ratio):1")
}
