import Foundation
import Testing
import EFDomain
import EFData

// Review of PR #26 (E11, STORY-055): the cover of the Sum 41 article (10678) shows « deryck 650.png »
// as its caption: the editor left the file name in the figcaption. Decision (review of 2026-11-25): a
// caption that is only a file name is no caption (nil), for the cover and for the photos of the body.
// "Only a file name" = ends with .png, .jpg, .jpeg, .webp, .gif or .avif (any case), or is the last
// path component of the image's address. Any other caption is kept whole (SitePageArticleContentSourceTests).

private func cover(src: String = "/media/2026/11/deryck-650.png-3bd1712d.webp", caption: String) -> String {
    """
    <figure class="article-cover"><img src="\(src)" alt="Deryck Whibley" width="650" height="433">\
    <figcaption>\(caption)</figcaption></figure>
    """
}

private func bodyFigure(src: String = "/media/2026/11/deryck-650.png-3bd1712d.webp", caption: String) -> String {
    """
    <p>Le chanteur de Sum 41 revient seul.</p>\
    <figure class="wp-block-image"><img src="\(src)" width="650" height="433"><figcaption>\(caption)</figcaption></figure>
    """
}

private func coverCaption(_ caption: String, src: String = "/media/2026/11/deryck-650.png-3bd1712d.webp")
    async throws -> ArticleImage? {
    let page = ArticlePage.page(head: ArticlePage.defaultHead + cover(src: src, caption: caption), body: "<p>Texte.</p>")
    return try await readArticle(page).cover
}

private func bodyImage(_ caption: String, src: String = "/media/2026/11/deryck-650.png-3bd1712d.webp")
    async throws -> ArticleImage? {
    images(try await blocks(ofBody: bodyFigure(src: src, caption: caption))).first
}

@Suite struct FileNameCaptionTests {
    @Test func theCoverOfTheSum41ArticleHasNoFileNameCaption() async throws {
        let image = try #require(try await coverCaption("deryck 650.png"))

        #expect(image.caption == nil)
        #expect(image.url == site("/media/2026/11/deryck-650.png-3bd1712d.webp"), "the photo itself is kept")
        #expect(image.alt == "Deryck Whibley")
    }

    @Test(arguments: [
        "deryck 650.png", "DSC_0042.JPG", "affiche.jpeg", "IMG_1234.Webp", "teaser.gif", "scene.avif",
        // Whitespace around it is not a caption either.
        "  deryck 650.png \n"
    ])
    func aFileNameIsNotACaptionOfTheCover(_ caption: String) async throws {
        let image = try #require(try await coverCaption(caption))

        #expect(image.caption == nil)
    }

    @Test(arguments: ["deryck 650.png", "DSC_0042.JPG", "affiche.jpeg", "IMG_1234.Webp", "teaser.gif", "scene.avif"])
    func aFileNameIsNotACaptionOfABodyPhoto(_ caption: String) async throws {
        let image = try #require(try await bodyImage(caption))

        #expect(image.caption == nil)
        #expect(image.url == site("/media/2026/11/deryck-650.png-3bd1712d.webp"), "the photo itself is kept")
    }

    @Test func theNameOfTheImageFileIsNotACaption() async throws {
        // An extension outside the list, but the caption is the file the image is served from.
        let src = "/media/2026/11/hellfest-warzone-2026.heic"

        #expect(try #require(try await coverCaption("hellfest-warzone-2026.heic", src: src)).caption == nil)
        #expect(try #require(try await bodyImage("hellfest-warzone-2026.heic", src: src)).caption == nil)
    }

    @Test(arguments: [
        "Deryck Whibley au Bataclan - Mano Le Bris",
        // A file name inside a sentence is a sentence.
        "La photo deryck.png a fait le tour des réseaux",
        "Orelsan / Mano Le Bris @manoverso"
    ])
    func aRealCaptionIsKept(_ caption: String) async throws {
        #expect(try #require(try await coverCaption(caption)).caption == caption)
        #expect(try #require(try await bodyImage(caption)).caption == caption)
    }
}
