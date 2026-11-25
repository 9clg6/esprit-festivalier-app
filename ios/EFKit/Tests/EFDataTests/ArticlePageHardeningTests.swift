import Foundation
import Testing
import EFDomain
import EFData

// Opus review of PR #25 (STORY-053, ADR-007, NFR-005), each finding measured by a probe on 2026-11-25.
// Decisions pinned here:
// - a page nested 10 000 deep (divs or spans) never crashes the app and keeps its text; the reader is
//   linear: 4x more orphan closings or <hr> under 4x more open tags (10 000) read about 4x slower,
//   not 16x. They run in-process (exit tests need Swift 6.2, CI has 6.1): a
//   regression overflows the stack and crashes the runner, which fails CI;
// - only http/https addresses become links; javascript:, file:, data: are dropped (text kept);
//   mailto: and tel: stay links; tabs and new lines inside an href are removed, as browsers do;
// - only https images of the site are kept (body, cover, author avatar): no third-party load;
// - http://, www. and upper case site addresses are fetched at https://esprit-festivalier.fr/…;
//   a port, user info or another host is never fetched;
// - nothing disappears silently: an unclosed <svg> skips only itself, <!--> and <!---> are empty comments;
// - &#0;, surrogates and code points past U+10FFFF read as U+FFFD; "&#+65;" is not a reference;
// - an embed is YouTube or Spotify only on their own host or a subdomain of it;
// - the loader hands back the response too: a final address off the site (redirect) or a status
//   outside 200…299 is a typed error; the default loader gives up after 10 s and does not follow a
//   redirect off the site.
// Assumed API (EFData, EFDomain):
//   SitePageArticleContentSource.init(template: SiteTemplate = .v1,
//                                     load: @escaping @Sendable (URL) async throws -> (Data, URLResponse))
//   SitePageArticleContentSource.init(template: SiteTemplate = .v1)   // default loader, siteSession
//   static let siteSession: URLSession                                  // 10 s request timeout
//   static func followsRedirect(to url: URL) -> Bool                    // the redirect decision
//   ArticleContentError.redirectedOffSite(URL), ArticleContentError.httpStatus(Int)

// A ratio, not a bound in seconds: a slow or loaded runner (CI: Intel, debug, 2.16 s once against a 2 s
// bound) slows both sizes alike. Linear reads ~4x slower at 4x the size, quadratic ~16x (the old quadratic
// reader took 5-28 s at 20 000): 8 sits between them.
private let baseSize = 2_500
private let linearBound = 8.0

/// time(4n) / time(n), best of 3 reads each; `check` sees every read. The sizes alternate, so a burst of
/// load on the runner slows both, not only one.
private func growth(of body: (Int) -> String, checking check: ([ArticleBlock]) -> Void) async throws -> Double {
    let pages = [body(baseSize), body(4 * baseSize)]
    var best: [Duration] = [.seconds(3_600), .seconds(3_600)]
    for _ in 0..<3 {
        for (size, html) in pages.enumerated() {
            let start = ContinuousClock.now
            let found = try await blocks(ofBody: html)
            best[size] = min(best[size], ContinuousClock.now - start)
            check(found)
        }
    }
    return best[1] / best[0]
}

// MARK: - Deep nesting and linear time (in-process: a regression crashes the runner)

// Serialized: these tests do not time each other.
@Suite(.serialized) struct DeepNestingTests {
    @Test func tenThousandUnclosedDivsKeepTheirText() async throws {
        let ratio = try await growth(of: { String(repeating: "<div>", count: $0) + "<p>Au fond</p>" },
                                     checking: { #expect(paragraphs($0) == ["Au fond"]) })
        #expect(ratio < linearBound, "4x the page read \(ratio)x slower")
    }

    @Test func tenThousandUnclosedSpansKeepTheirText() async throws {
        let ratio = try await growth(of: { "<p>" + String(repeating: "<span>", count: $0) + "Au fond</p>" },
                                     checking: { #expect(paragraphs($0) == ["Au fond"]) })
        #expect(ratio < linearBound, "4x the page read \(ratio)x slower")
    }

    @Test func orphanClosingsUnderOpenDivsReadInLinearTime() async throws {
        let ratio = try await growth(of: {
            String(repeating: "<div>", count: $0) + String(repeating: "</span>", count: $0) + "<p>Fin</p>"
        }, checking: { #expect(paragraphs($0) == ["Fin"]) })
        #expect(ratio < linearBound, "4x the page read \(ratio)x slower")
    }

    @Test func separatorsUnderOpenSpansReadInLinearTime() async throws {
        let ratio = try await growth(of: {
            String(repeating: "<span>", count: $0) + String(repeating: "<hr>", count: $0) + "Fin"
        }, checking: { #expect($0.map(text(of:)).joined().contains("Fin")) })
        #expect(ratio < linearBound, "4x the page read \(ratio)x slower")
    }
}

// MARK: - Links: only what the app can open

@Suite struct ArticleLinkSchemeTests {
    @Test(arguments: [
        "javascript:alert(1)", "JavaScript:alert(1)", " javascript:alert(1)", "java\nscript:alert(1)",
        "file:///etc/passwd", "data:text/html,<b>x</b>"
    ])
    func aLinkTheAppCannotOpenKeepsItsTextWithoutLink(_ href: String) async throws {
        let escaped = href.replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        let found = runs(try await blocks(ofBody: "<p>Voir <a href=\"\(escaped)\">ici</a> fin.</p>"))

        #expect(plain(found) == "Voir ici fin.")
        #expect(found.allSatisfy { $0.link == nil }, "\(found)")
    }

    @Test(arguments: ["mailto:redaction@esprit-festivalier.fr", "tel:+33102030405"])
    func mailAndPhoneLinksStayLinks(_ href: String) async throws {
        let found = runs(try await blocks(ofBody: "<p>Écrire <a href=\"\(href)\">ici</a></p>"))

        #expect(found.compactMap(\.link) == [URL(string: href)!])
    }

    @Test func webLinksOfOtherSitesStayLinks() async throws {
        let found = runs(try await blocks(ofBody: #"<p><a href="http://www.hellfest.fr/">Hellfest</a></p>"#))

        #expect(found.compactMap(\.link) == [URL(string: "http://www.hellfest.fr/")!])
    }

    @Test func tabsAndNewLinesInsideAnAddressAreRemoved() async throws {
        let found = runs(try await blocks(ofBody: """
            <p><a href="/festival/hell\n\tfest/">Hellfest</a> et <a href="  https://www.hell\nfest.fr/\n">le site</a></p>
            """))

        #expect(found.compactMap(\.link) == [site("/festival/hellfest/"), URL(string: "https://www.hellfest.fr/")!])
    }
}

// MARK: - Images: no third-party load (NFR-005)

@Suite struct ArticleImageOriginTests {
    @Test func onlyImagesOfTheSiteAreKept() async throws {
        let found = try await blocks(ofBody: """
            <p>Avant</p><img src="http://tracker.example/p.gif" width="1" height="1"><img src="file:///etc/passwd">\
            <img src="data:image/gif;base64,R0lGODlhAQABAAAAACw="><img src="https://tracker.example/p.gif">\
            <img src="/media/2026/11/scene.jpg" alt="La scène"><p>Après</p>
            """)

        #expect(images(found).map(\.url) == [site("/media/2026/11/scene.jpg")])
        #expect(paragraphs(found) == ["Avant", "Après"])
    }

    @Test func aCoverFromAnotherSiteIsNotKept() async throws {
        let head = ArticlePage.defaultHead
            + #"<figure class="article-cover"><img src="http://tracker.example/cover.jpg" alt="x"></figure>"#
        let article = try await readArticle(ArticlePage.page(head: head, body: "<p>Texte</p>"))

        #expect(article.cover == nil)
    }

    @Test(arguments: ["http://tracker.example/a.jpg", "file:///etc/passwd", "data:image/gif;base64,R0lG"])
    func anAvatarFromAnotherSiteIsNotKept(_ src: String) async throws {
        let head = ArticlePage.defaultHead.replacingOccurrences(
            of: #"<div class="byline">"#, with: #"<div class="byline"><img class="avatar" src="\#(src)" alt="">"#)
        let author = try #require(try await readArticle(ArticlePage.page(head: head, body: "<p>Texte</p>")).author)

        #expect(author.name == "Chloé Magron")
        #expect(author.avatarURL == nil)
    }
}

// MARK: - Site addresses: canonical, never another host

@Suite struct SiteAddressTests {
    @Test(arguments: [
        "http://www.esprit-festivalier.fr/x-12/", "https://Esprit-Festivalier.fr/x-12/",
        "https://www.esprit-festivalier.fr/x-12/", "http://esprit-festivalier.fr/x-12/"
    ])
    func aSiteAddressIsFetchedAtItsCanonicalAddress(_ address: String) async throws {
        let page = ArticlePage.page(body: "<p>Texte</p>")
        let asked = Recorder<URL>()
        let source = SitePageArticleContentSource(load: { url in
            await asked.append(url)
            return served(page, at: url)
        })

        _ = try await source.content(at: URL(string: address)!)

        #expect(await asked.values == [URL(string: "https://esprit-festivalier.fr/x-12/")!])
    }

    @Test(arguments: [
        "https://esprit-festivalier.fr:8443/x-12/", "https://user:secret@esprit-festivalier.fr/x-12/",
        "https://user@esprit-festivalier.fr/x-12/", "https://esprit-festivalier.fr.evil.com/x-12/",
        "ftp://esprit-festivalier.fr/x-12/"
    ])
    func anAddressWithPortUserInfoOrOtherHostIsNeverFetched(_ address: String) async throws {
        let url = URL(string: address)!
        let asked = Recorder<URL>()
        let source = SitePageArticleContentSource(load: { url in
            await asked.append(url)
            return served(ArticlePage.page(body: "<p>Texte</p>"), at: url)
        })

        await #expect(throws: ArticleContentError.notSiteAddress(url)) { try await source.content(at: url) }
        #expect(await asked.values.isEmpty)
    }
}

// MARK: - Loading: the response is checked, the default loader is bounded

@Suite struct SitePageLoadingTests {
    private let article = URL(string: "https://esprit-festivalier.fr/x-12/")!
    private let page = ArticlePage.page(body: "<p>Texte</p>")

    @Test(arguments: [404, 410, 500, 503])
    func aStatusOutsideSuccessIsATypedError(_ status: Int) async throws {
        let page = page
        let source = SitePageArticleContentSource(load: { url in served(page, at: url, status: status) })

        await #expect(throws: ArticleContentError.httpStatus(status)) { try await source.content(at: article) }
    }

    @Test(arguments: ["https://evil.example/x-12/", "https://esprit-festivalier.fr.evil.com/x-12/"])
    func aPageServedFromAnotherSiteAfterARedirectIsRefused(_ final: String) async throws {
        let page = page
        let finalURL = URL(string: final)!
        let source = SitePageArticleContentSource(load: { _ in served(page, at: finalURL) })

        await #expect(throws: ArticleContentError.redirectedOffSite(finalURL)) { try await source.content(at: article) }
    }

    @Test func aRedirectWithinTheSiteIsRead() async throws {
        let page = page
        let moved = URL(string: "https://esprit-festivalier.fr/x-renomme-12/")!
        let source = SitePageArticleContentSource(load: { _ in served(page, at: moved) })

        #expect(paragraphs(try await source.content(at: article).blocks) == ["Texte"])
    }

    @Test(arguments: [
        ("https://esprit-festivalier.fr/x-renomme-12/", true), ("https://evil.example/x-12/", false),
        ("https://esprit-festivalier.fr.evil.com/x-12/", false), ("https://esprit-festivalier.fr:8443/x-12/", false)
    ])
    func theDefaultLoaderFollowsARedirectOnlyWithinTheSite(_ target: String, _ follows: Bool) {
        #expect(SitePageArticleContentSource.followsRedirect(to: URL(string: target)!) == follows)
    }

    @Test func theDefaultLoaderGivesUpAfterTenSeconds() {
        #expect(SitePageArticleContentSource.siteSession.configuration.timeoutIntervalForRequest == 10)
    }

    @Test func theDefaultLoaderNeverFetchesAnotherSite() async throws {
        let url = URL(string: "https://evil.example/x-12/")!

        await #expect(throws: ArticleContentError.notSiteAddress(url)) {
            try await SitePageArticleContentSource().content(at: url)
        }
    }
}

// MARK: - Nothing disappears silently

@Suite struct ReaderKeepsTextTests {
    @Test func anUnclosedDrawingSkipsOnlyItself() async throws {
        let found = try await blocks(ofBody: "<p>A</p><svg viewBox='0 0 1 1'><path d='M0'/><p>B</p><p>C</p>")

        #expect(paragraphs(found) == ["A", "B", "C"])
    }

    @Test(arguments: ["<!-->", "<!--->"])
    func anAbruptCommentIsEmpty(_ comment: String) async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>A</p>\(comment)<p>B</p><p>C</p>")) == ["A", "B", "C"])
    }
}

// MARK: - Character references

@Suite struct CharacterReferenceTests {
    @Test(arguments: ["&#0;", "&#xD800;", "&#xDFFF;", "&#x110000;", "&#1114112;"])
    func aReferenceToNoCharacterReadsAsReplacementCharacter(_ reference: String) async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>a\(reference)b</p>")) == ["a\u{FFFD}b"])
    }

    @Test(arguments: ["&#+65;", "&#-65;"])
    func aSignedNumberIsNotAReference(_ reference: String) async throws {
        #expect(paragraphs(try await blocks(ofBody: "<p>a\(reference)b</p>")) == ["a\(reference)b"])
    }

    @Test func commonNamedEntitiesAreDecoded() async throws {
        let found = paragraphs(try await blocks(ofBody:
            "<p>&eacute;t&eacute; &euro; l&rsquo;an&hellip;&nbsp;&laquo;ok&raquo;</p>"))

        #expect(found == ["été € l’an…\u{A0}«ok»"])
    }
}

// MARK: - Embeds: provider by exact host or subdomain

@Suite struct EmbedProviderTests {
    private func embeds(_ blocks: [ArticleBlock]) -> [Embed] {
        blocks.compactMap { if case let .embed(embed) = $0 { embed } else { nil } }
    }

    @Test(arguments: [
        "https://youtube.evil.com/embed/x", "https://evilyoutube.com/embed/x",
        "https://evilspotify.com/embed/x", "https://spotify.com.evil.com/embed/x"
    ])
    func aLookAlikeHostIsNoKnownProvider(_ src: String) async throws {
        let found = embeds(try await blocks(ofBody: "<iframe src=\"\(src)\" title=\"T\"></iframe>"))

        #expect(found.map(\.provider) == [.other])
    }

    @Test(arguments: [
        ("https://youtube.com/embed/x", Embed.Provider.youtube), ("https://www.youtube.com/embed/x", .youtube),
        ("https://spotify.com/embed/x", .spotify), ("https://open.spotify.com/embed/x", .spotify)
    ])
    func theProviderHostOrASubdomainIsKnown(_ src: String, _ provider: Embed.Provider) async throws {
        let found = embeds(try await blocks(ofBody: "<iframe src=\"\(src)\" title=\"T\"></iframe>"))

        #expect(found.map(\.provider) == [provider])
    }
}
