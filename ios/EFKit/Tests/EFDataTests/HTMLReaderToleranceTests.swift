import Foundation
import Testing
import EFDomain
import EFData

// STORY-053 (ADR-007 "Lecture du HTML : choix"): a small tolerant HTML reader, no third-party code.
// Rules from the ADR: void elements (img, br, hr, source, wbr), p and li closed implicitly, comments
// ignored, script/style/svg skipped, orphan closing tags ignored, entities decoded with the decoder of
// RSSArticleSource; unknown element → its text in a paragraph ("rien ne disparaît en silence");
// never a crash on a truncated page. Tested through SitePageArticleContentSource (the reader has no
// public surface of its own). Helpers: ArticlePageTestSupport.swift.
// Decisions pinned here: an unknown entity stays as written; tag and attribute names are
// case-insensitive; attributes may be unquoted, single- or double-quoted, in any order.

@Suite struct HTMLReaderToleranceTests {
    @Test func anUnclosedParagraphEndsWhereTheNextOneStarts() async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>Un<p>Deux</p>")) == ["Un", "Deux"])
    }

    @Test func unclosedListItemsEndAtTheNextItem() async throws {
        let found = merged(try await blocks(ofBody: "<ul><li>Vendredi<li>Samedi</ul>"))

        #expect(found == [.list(ordered: false, items: [[InlineRun(text: "Vendredi")], [InlineRun(text: "Samedi")]])])
    }

    @Test func anOrphanClosingTagIsIgnored() async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>Avant</span> après</em></p><p>Suite</p>")) == ["Avant après", "Suite"])
    }

    @Test func anUnclosedInlineTagDoesNotSwallowTheNextParagraph() async throws {
        let found = merged(try await blocks(ofBody: "<p>Un <strong>mot</p><p>Libre</p>"))

        #expect(found == [
            .paragraph([InlineRun(text: "Un "), InlineRun(text: "mot", bold: true)]),
            .paragraph([InlineRun(text: "Libre")])
        ])
    }

    @Test func entitiesAreDecoded() async throws {
        let found = paragraphs(try await blocks(ofBody: "<p>Rock &amp; folk, &#233;t&#xE9; l&rsquo;an&nbsp;2027 &laquo;&#8239;ok&#8239;&raquo;</p>"))

        #expect(found == ["Rock & folk, été l’an\u{A0}2027 «\u{202F}ok\u{202F}»"])
    }

    @Test func anUnknownEntityStaysAsWritten() async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>A &nope; B &#; C & D</p>")) == ["A &nope; B &#; C & D"])
    }

    @Test func entitiesInAttributesAreDecoded() async throws {
        let found = runs(try await blocks(ofBody: #"<p><a href="/festival/hellfest/?a=1&amp;b=2">Hellfest</a></p>"#))

        #expect(found.first?.link == URL(string: "https://esprit-festivalier.fr/festival/hellfest/?a=1&b=2"))
    }

    @Test func attributesInAnyOrderAndQuotingAreRead() async throws {
        let found = try await blocks(ofBody: """
            <p><a class=lien href=/festival/hellfest/>Hellfest</a> et <a target=_blank href='https://www.hellfest.fr/'>le site</a></p>\
            <img height='300' alt="Main stage" width=400 src='/media/2026/11/main-stage.jpg'>
            """)

        let links = runs(found).compactMap(\.link)
        #expect(links == [site("/festival/hellfest/"), URL(string: "https://www.hellfest.fr/")!])
        let image = try #require(images(found).first)
        #expect(image.url == site("/media/2026/11/main-stage.jpg"))
        #expect(image.width == 400)
        #expect(image.height == 300)
        #expect(image.alt == "Main stage")
    }

    @Test func tagNamesAreCaseInsensitive() async throws {
        let found = merged(try await blocks(ofBody: "<P>Un <STRONG>mot</Strong></P><H3>Titre</H3>"))

        #expect(found == [
            .paragraph([InlineRun(text: "Un "), InlineRun(text: "mot", bold: true)]),
            .heading(level: 3, [InlineRun(text: "Titre")])
        ])
    }

    @Test func commentsAreIgnored() async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>Visible</p><!-- <p>Caché</p> --><p>Aussi</p>")) == ["Visible", "Aussi"])
    }

    @Test func scriptsStylesAndDrawingsAreSkipped() async throws {
        let found = try await blocks(ofBody: """
            <p>Avant</p><script>document.write("<p>Faux</p>")</script><style>p { color: red }</style>\
            <svg viewBox="0 0 24 24"><text>Logo</text></svg><p>Après</p>
            """)

        #expect(found.map(text(of:)) == ["Avant", "Après"])
    }

    @Test func voidElementsDoNotSwallowWhatFollows() async throws {
        let found = try await blocks(ofBody: #"<p>Ligne 1<br>Ligne 2<wbr></p><img src="/media/b.jpg"><hr><p>Suite</p>"#)

        try #require(found.count == 4, "\(found)")
        #expect(text(of: found[0]).contains("Ligne 1"))
        #expect(text(of: found[0]).contains("Ligne 2"))
        #expect(images([found[1]]).first?.url == site("/media/b.jpg"))
        #expect(found[2] == .separator)
        #expect(text(of: found[3]) == "Suite")
    }

    @Test func anUnknownElementKeepsItsTextInAParagraph() async throws {
        let found = try await blocks(ofBody: #"<p>Avant</p><section class="encart"><span>Texte d'un bloc inconnu</span></section>"#)

        #expect(paragraphs(found) == ["Avant", "Texte d'un bloc inconnu"])
    }

    @Test func aShortBoldOnlyParagraphIsAHeading() async throws {
        #expect(headings(try await blocks(ofBody: "<p><strong>Infos pratiques</strong></p>")) == [Heading(level: 3, text: "Infos pratiques")])
    }

    @Test func aLongBoldOnlyParagraphStaysAParagraph() async throws {
        let long = String(repeating: "Un texte entièrement en gras mais bien trop long. ", count: 3)
        try #require(long.count >= 120)

        let found = merged(try await blocks(ofBody: "<p><strong>\(long)</strong></p>"))

        #expect(headings(found).isEmpty)
        #expect(paragraphs(found) == [collapse(long)])
        let allBold = runs(found).allSatisfy { $0.bold }
        #expect(allBold)
    }

    @Test func aBoldParagraphOfOnlySpacesIsDropped() async throws {
        #expect(try await blocks(ofBody: "<p><strong> </strong></p><p>Texte</p>").map(text(of:)) == ["Texte"])
    }

    @Test func anImageInsideAParagraphIsNotLost() async throws {
        let found = try await blocks(ofBody: #"<p>Avant <img src="/media/c.jpg" width="10" height="20"> après</p>"#)

        #expect(images(found).map(\.url) == [site("/media/c.jpg")])
        #expect(found.map(text(of:)).joined(separator: " ").contains("Avant"))
        #expect(found.map(text(of:)).joined(separator: " ").contains("après"))
    }

    @Test func aBodyWithoutReadEndStillEndsAtTheBody() async throws {
        // The end marker missing (template change, cut page): the body ends with its own element.
        let page = Data("""
            <main id="contenu"><article><header class="article-head">\(ArticlePage.defaultHead)</header>\
            <div class="article-body"><p>Seul paragraphe.</p></div>\
            <aside class="author-box"><p>Rédactrice bénévole</p></aside></article></main>
            """.utf8)

        #expect(paragraphs(try await readArticle(page).blocks) == ["Seul paragraphe."])
    }

    @Test func aTruncatedPageNeverCrashes() async throws {
        // Every cut of a real page: either an article or `unreadable`, never a crash or another error.
        let page = try ArticlePage.terresDuSonPage()
        for length in stride(from: 0, to: page.count, by: 211) {
            do {
                let article = try await readArticle(page.prefix(length), at: ArticlePage.terresDuSon)
                #expect(!article.title.isEmpty, "cut at \(length)")
                #expect(!article.blocks.isEmpty, "cut at \(length)")
            } catch let error as ArticleContentError {
                #expect(error == .unreadable, "cut at \(length)")
            } catch {
                Issue.record("cut at \(length): \(error)")
            }
        }
    }

    @Test func aPageCutInsideAParagraphKeepsWhatWasRead() async throws {
        let page = Data("""
            <main id="contenu"><article><header class="article-head">\(ArticlePage.defaultHead)</header>\
            <div class="article-body"><p>Complet.</p><p>Début <strong>gras <a href="/festival/hell
            """.utf8)

        let texts = try await readArticle(page).blocks.map(text(of:))

        #expect(texts.first == "Complet.")
    }
}
