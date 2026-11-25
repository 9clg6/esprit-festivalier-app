import Foundation
import Testing
import EFDomain
import EFData

// STORY-053 / STORY-054 (ADR-007): rules of the "page du site" reader beyond the real fixtures —
// blocks the feed's articles did not have, JSON-LD first, failures, SiteTemplate. Assumed API and
// decisions: see the header of SitePageArticleContentSourceTests.swift.

// MARK: - Blocks the feed's articles did not have (synthetic page, no JSON-LD)

@Suite struct SyntheticBlocksTests {
    private func content() async throws -> ArticleContent {
        try await readArticle(try ArticlePage.syntheticPage(), at: ArticlePage.synthetic)
    }

    @Test func everyKindOfBlockIsRead() async throws {
        let hellfest = site("/festival/hellfest/")

        #expect(merged(try await content().blocks) == [
            .paragraph([InlineRun(text: "Le Hellfest revient du 18 au 21 juin 2027.")]),
            .heading(level: 2, [InlineRun(text: "Avant de partir")]),
            .list(ordered: false, items: [
                [InlineRun(text: "Des bouchons d'oreilles")],
                [InlineRun(text: "Une gourde "), InlineRun(text: "vide", bold: true)],
                [InlineRun(text: "Un "), InlineRun(text: "plan du site", link: hellfest)]
            ]),
            .heading(level: 4, [InlineRun(text: "Le camping")]),
            .list(ordered: true, items: [[InlineRun(text: "Arriver tôt")], [InlineRun(text: "Monter la tente")]]),
            .quote([InlineRun(text: "« Boucher le haut-parleur ne fait pas disparaître ce qui s'exprime derrière. »")],
                   source: "Stéphane Krasniewski"),
            .separator,
            .embed(Embed(provider: .youtube, url: URL(string: "https://www.youtube.com/embed/tFhwD-9Zhzg")!,
                         title: "Orelsan - Mentir au psy")),
            .embed(Embed(provider: .spotify,
                         url: URL(string: "https://open.spotify.com/embed/playlist/37i9dQZF1DX4sWSpwq3LiO")!,
                         title: "Playlist Hellfest")),
            .embed(Embed(provider: .other, url: URL(string: "https://player.vimeo.com/video/76979871")!, title: "Teaser")),
            .paragraph([InlineRun(text: "Bon festival à toutes et à tous.")])
        ])
    }

    @Test func withoutJSONLDTheMetadataComesFromThePage() async throws {
        let article = try await content()

        #expect(article.title == "Hellfest 2027 : le guide de survie")
        #expect(article.chapo == "Tout ce qu'il faut savoir avant de partir à Clisson.")
        #expect(article.category == .guide)
        #expect(article.author?.name == "Chloé Magron")
        #expect(article.author?.slug == "chloe-magron")
        #expect(article.author?.bio == "Rédactrice bénévole pour Esprit Festivalier")
        #expect(abs(article.publishedAt.timeIntervalSince(isoDate("2026-11-20T10:00:00.000Z"))) < 0.001)
        #expect(article.readingMinutes == 4)
        #expect(article.festival == FestivalRef(slug: "hellfest", name: "Hellfest 2027"))
        #expect(article.cover?.caption == "La Warzone - Chloé Magron")
        #expect(article.related.isEmpty)
    }

    @Test func aSponsoredArticleIsMarked() async throws {
        // `.sponsored-tag` is defined by the site's style sheet; not seen on a real page yet (ADR-007).
        #expect(try await content().isSponsored)
    }
}

// MARK: - JSON-LD first

@Suite struct JSONLDMetadataTests {
    @Test func jsonLDWinsOverTheVisibleTemplate() async throws {
        let jsonLD = """
            {"@context":"https://schema.org","@type":"NewsArticle","headline":"Titre du JSON-LD",\
            "datePublished":"2026-11-01T08:00:00.000Z","dateModified":"2026-11-02T08:00:00.000Z",\
            "author":{"@type":"Person","name":"Nom JSON","url":"https://esprit-festivalier.fr/author/nom-json/"},\
            "articleSection":"Interview"}
            """
        let article = try await readArticle(ArticlePage.page(jsonLD: jsonLD, body: "<p>Texte.</p>"))

        #expect(article.title == "Titre du JSON-LD")
        #expect(article.category == .interview)
        #expect(article.author?.name == "Nom JSON")
        #expect(article.author?.slug == "nom-json")
        #expect(abs(article.publishedAt.timeIntervalSince(isoDate("2026-11-01T08:00:00.000Z"))) < 0.001)
        #expect(article.modifiedAt.map { abs($0.timeIntervalSince(isoDate("2026-11-02T08:00:00.000Z"))) < 0.001 } == true)
    }

    @Test func entitiesInTheJSONLDAreDecoded() async throws {
        let jsonLD = """
            {"@type":"NewsArticle","headline":"Bigflo \\u0026 Oli : l\\u2019avant-go\\u00fbt",\
            "datePublished":"2026-11-01T08:00:00.000Z","articleSection":"Live report"}
            """
        let article = try await readArticle(ArticlePage.page(jsonLD: jsonLD, body: "<p>Texte.</p>"))

        #expect(article.title == "Bigflo & Oli : l’avant-goût")
    }
}

// MARK: - Failures the screen must tell apart (ADR-007 "Échec : jamais d'ouverture silencieuse de Safari")

@Suite struct ArticleReadingFailureTests {
    @Test func aPageThatIsNotAnArticleIsUnreadable() async throws {
        await #expect(throws: ArticleContentError.unreadable) {
            try await readArticle(try ArticlePage.authorPage(), at: ArticlePage.author)
        }
    }

    @Test func anArticleWithoutTitleIsUnreadable() async throws {
        let page = ArticlePage.page(head: #"<a class="cat" href="/category/actu/">Actu</a>"#, body: "<p>Texte.</p>")

        await #expect(throws: ArticleContentError.unreadable) { try await readArticle(page) }
    }

    @Test func anArticleWithAnEmptyBodyIsUnreadable() async throws {
        await #expect(throws: ArticleContentError.unreadable) {
            try await readArticle(ArticlePage.page(body: "<p></p>  "))
        }
    }

    @Test func aCaptivePortalPageIsUnreadable() async throws {
        let portal = Data("<html><body><h1>Connexion au Wi-Fi</h1><form></form></body></html>".utf8)

        await #expect(throws: ArticleContentError.unreadable) { try await readArticle(portal) }
    }

    @Test func bytesThatAreNotTextAreUnreadable() async throws {
        await #expect(throws: ArticleContentError.unreadable) { try await readArticle(Data([0xFF, 0xFE, 0x00, 0xD8])) }
    }

    @Test func offlineIsNotUnreadable() async throws {
        let source = SitePageArticleContentSource(load: { _ in throw URLError(.notConnectedToInternet) })

        await #expect(throws: URLError(.notConnectedToInternet)) { try await source.content(at: ArticlePage.orelsan) }
    }

    @Test func theArticleIsDownloadedFromItsOwnAddress() async throws {
        let page = try ArticlePage.orelsanPage()
        let asked = Recorder<URL>()
        let source = SitePageArticleContentSource(load: { url in
            await asked.append(url)
            return page
        })

        _ = try await source.content(at: ArticlePage.orelsan)

        #expect(await asked.values == [ArticlePage.orelsan])
    }

    @Test(arguments: [
        "http://esprit-festivalier.fr/je-le-connais-de-nom-mais-j-ai-jamais-ecoute-a-nantes-orelsan-seduit-meme-les-novices-10675/",
        "https://example.com/un-article-10675/",
        "https://esprit-festivalier.fr.example.com/un-article-10675/"
    ])
    func onlyTheSiteIsEverDownloaded(_ address: String) async throws {
        let url = URL(string: address)!
        let asked = Recorder<URL>()
        let source = SitePageArticleContentSource(load: { url in
            await asked.append(url)
            return try ArticlePage.orelsanPage()
        })

        await #expect(throws: ArticleContentError.notSiteAddress(url)) { try await source.content(at: url) }
        #expect(await asked.values.isEmpty)
    }
}

// MARK: - SiteTemplate: every marker in one place

@Suite struct SiteTemplateTests {
    @Test func theReaderLooksForTheMainRegionNamedByTheTemplate() async throws {
        var template = SiteTemplate.v1
        template.mainID = "autre-contenu"

        await #expect(throws: ArticleContentError.unreadable) {
            try await readArticle(try ArticlePage.orelsanPage(), at: ArticlePage.orelsan, template: template)
        }
    }

    @Test func theV1TemplateReadsTheMainRegionOfTheSite() {
        #expect(SiteTemplate.v1.mainID == "contenu")
    }

    @Test func aNewTemplateVersionIsCarriedByTheContent() async throws {
        var template = SiteTemplate.v1
        template.parserVersion = 2

        let article = try await readArticle(try ArticlePage.orelsanPage(), at: ArticlePage.orelsan, template: template)

        #expect(article.parserVersion == 2)
    }
}

actor Recorder<Value: Sendable> {
    private(set) var values: [Value] = []
    func append(_ value: Value) { values.append(value) }
}
