import Foundation
import Testing
import EFDomain

// Review of PR #26 (E11, STORY-055): the reader strips `?w=` from the site's images, so the screen
// must ask the site for a size: a full-resolution photo (6024 px) in a list costs memory for nothing.
// Rule: width = displayed points × screen scale, rounded up to the smallest bucket (240, 320, 480, 720, 960, 1600),
// capped at 1600; the full-screen photo asks 1600. Appended as `?w=<n>`, replacing any `w` already
// there and keeping the other query items. Only the site's images: another host is left as is.
// Assumed API (EFDomain), chosen here because the feed's hero is a bare URL (`Article.imageURL`) and
// the reader's images are `ArticleImage.url`: one function on URL serves both.
//   public enum SiteImage {
//     public static let widths: [Int]                        // [240, 320, 480, 720, 960, 1600]
//     public static func url(_ url: URL, pointWidth: Double, scale: Double) -> URL
//     public static func fullscreenURL(_ url: URL) -> URL     // `?w=1600`
//   }

private let photo = URL(string: "https://esprit-festivalier.fr/media/2026/11/fond-d-ecran-bf60094a.jpg")!

private func width(of url: URL) -> [String] {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.filter { $0.name == "w" }
        .compactMap(\.value) ?? []
}

@Suite struct SiteImageTests {
    @Test func theBucketsAreTheSizesTheSiteServes() {
        #expect(SiteImage.widths == [240, 320, 480, 720, 960, 1600])
    }

    @Test(arguments: [
        // iPhone 15 (390 pt, @3x) edge to edge: 1170 px > 960 → 1600.
        (390.0, 3.0, "1600"),
        // Same width @2x: 780 px > 720 → 960.
        (390.0, 2.0, "960"),
        // A card: 160 pt @3x = 480 px, a size the site serves: not rounded up.
        (160.0, 3.0, "480"),
        // A thumbnail: 100 pt @2x = 200 px → the smallest size.
        (100.0, 2.0, "240"),
        // Each served size is kept, the next pixel goes to the next one.
        (240.0, 1.0, "240"),
        (240.5, 1.0, "320"),
        (360.0, 2.0, "720"),
        (361.0, 2.0, "960"),
        // iPad, larger than the largest size: capped.
        (760.0, 3.0, "1600"),
        // Not measured yet (0 pt): the smallest size, never `w=0`.
        (0.0, 3.0, "240")
    ])
    func aSiteImageAsksTheSizeItIsShownAt(points: Double, scale: Double, expected: String) {
        let sized = SiteImage.url(photo, pointWidth: points, scale: scale)

        #expect(width(of: sized) == [expected])
        #expect(sized.host() == photo.host())
        #expect(sized.path() == photo.path())
    }

    @Test func theFullScreenPhotoAsksTheLargestSize() {
        #expect(width(of: SiteImage.fullscreenURL(photo)) == ["1600"])
        #expect(SiteImage.fullscreenURL(photo).path() == photo.path())
    }

    @Test func aSizeAlreadyInTheAddressIsReplacedNotRepeated() throws {
        // The feed's hero comes with a `w` already.
        let hero = try #require(URL(string: "https://esprit-festivalier.fr/media/2026/11/deryck-650.png-3bd1712d.webp?w=480"))

        let sized = SiteImage.url(hero, pointWidth: 375, scale: 2)

        #expect(width(of: sized) == ["960"])
        #expect(width(of: SiteImage.fullscreenURL(hero)) == ["1600"])
    }

    @Test func otherQueryItemsAreKept() throws {
        let versioned = try #require(URL(string: "https://esprit-festivalier.fr/media/2026/11/m-97c78cfb.png?v=2&w=240"))

        let sized = SiteImage.url(versioned, pointWidth: 390, scale: 3)
        let items = URLComponents(url: sized, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(Set(items) == [URLQueryItem(name: "v", value: "2"), URLQueryItem(name: "w", value: "1600")])
    }

    @Test(arguments: [
        "https://i.ytimg.com/vi/tFhwD-9Zhzg/hqdefault.jpg",
        "https://i.ytimg.com/vi/tFhwD-9Zhzg/hqdefault.jpg?w=960",
        // Looks like the site, is not the site.
        "https://esprit-festivalier.fr.example.com/media/2026/11/photo.jpg"
    ])
    func anImageOfAnotherHostIsLeftAsIs(_ address: String) throws {
        let other = try #require(URL(string: address))

        #expect(SiteImage.url(other, pointWidth: 393, scale: 3) == other)
        #expect(SiteImage.fullscreenURL(other) == other)
    }
}
