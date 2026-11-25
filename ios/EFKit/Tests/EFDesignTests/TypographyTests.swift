import CoreText
import SwiftUI
import Testing
import EFDesign

// Need: STORY-002 "Chivo, Raleway, Open Sans embarquées et liées à Dynamic Type",
// UX doc "Tokens > Typographie (alignée sur Dynamic Type)".

// MARK: - Bundled fonts are registered and usable

let typeScaleFaces = ["Chivo-Black", "Chivo-Bold", "Raleway-Bold", "OpenSans-Regular"]

@Test(arguments: typeScaleFaces)
func bundledFaceIsUsableByPostScriptNameAfterRegistration(_ postScriptName: String) throws {
    EFFonts.register()
    // CTFontCreateWithName silently falls back to another font: compare what we actually got.
    let font = CTFontCreateWithName(postScriptName as CFString, 17, nil)
    #expect(CTFontCopyPostScriptName(font) as String == postScriptName)
    // It comes from the package resources, not from a font installed on the machine.
    let url = try #require(CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL)
    #expect(url.path.contains(".bundle/"), "\(postScriptName) loaded from \(url.path)")
}

@Test func registeringTwiceIsHarmless() {
    EFFonts.register()
    EFFonts.register()
    let font = CTFontCreateWithName("Chivo-Black" as CFString, 17, nil)
    #expect(CTFontCopyPostScriptName(font) as String == "Chivo-Black")
}

// MARK: - Type scale

struct TypeScaleRow: Sendable, CustomTestStringConvertible {
    let style: EFTextStyle
    let postScriptName: String
    let size: CGFloat
    let relativeTo: Font.TextStyle
    var testDescription: String { "\(style)" }
}

// UX doc table, row by row.
let uxTypeScale: [TypeScaleRow] = [
    TypeScaleRow(style: .largeTitle, postScriptName: "Chivo-Black", size: 34, relativeTo: .largeTitle),
    TypeScaleRow(style: .title1, postScriptName: "Chivo-Bold", size: 28, relativeTo: .title),
    TypeScaleRow(style: .title2, postScriptName: "Chivo-Bold", size: 22, relativeTo: .title2),
    TypeScaleRow(style: .title3, postScriptName: "Chivo-Bold", size: 20, relativeTo: .title3),
    TypeScaleRow(style: .strongLabel, postScriptName: "Raleway-Bold", size: 17, relativeTo: .headline),
    TypeScaleRow(style: .body, postScriptName: "OpenSans-Regular", size: 17, relativeTo: .body),
    TypeScaleRow(style: .bodySecondary, postScriptName: "OpenSans-Regular", size: 15, relativeTo: .subheadline),
    TypeScaleRow(style: .sectionHeader, postScriptName: "Raleway-Bold", size: 13, relativeTo: .footnote),
    TypeScaleRow(style: .caption, postScriptName: "OpenSans-Regular", size: 12, relativeTo: .caption),
]

@Test func typeScaleHasExactlyTheUXDocStyles() {
    #expect(Set(EFTextStyle.allCases.map { "\($0)" }) == Set(uxTypeScale.map { "\($0.style)" }))
}

@Test(arguments: uxTypeScale)
func styleUsesTheUXDocFaceSizeAndDynamicTypeStyle(_ row: TypeScaleRow) {
    #expect(row.style.postScriptName == row.postScriptName)
    #expect(row.style.size == row.size)
    #expect(row.style.relativeTo == row.relativeTo)
}

@Test(arguments: uxTypeScale)
func everyStyleFaceIsOneOfTheRegisteredBundledFaces(_ row: TypeScaleRow) {
    #expect(typeScaleFaces.contains(row.style.postScriptName))
}

@Test func sectionHeaderIsUppercasedWithSixHundredthsEmTracking() {
    #expect(EFTextStyle.sectionHeader.isUppercase)
    #expect(abs(EFTextStyle.sectionHeader.trackingEm - 0.06) < 0.0001)
}

@Test(arguments: uxTypeScale.filter { $0.style != .sectionHeader })
func otherStylesAreNotUppercasedNorTracked(_ row: TypeScaleRow) {
    #expect(!row.style.isUppercase)
    #expect(row.style.trackingEm == 0)
}
