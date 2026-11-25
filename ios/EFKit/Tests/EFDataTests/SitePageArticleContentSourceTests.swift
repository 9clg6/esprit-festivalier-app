import Foundation
import Testing
import EFDomain
import EFData

// STORY-053 / STORY-054 (FR-027, FR-011, ADR-007 "Contenu des articles"): the full article is read
// from its page on the site and shown natively. Fixtures and helpers: ArticlePageTestSupport.swift.
// Assumed API (EFData):
//   struct SiteTemplate: Sendable { var mainID: String; var parserVersion: Int; … every marker;
//                                   static let v1 }               // parserVersion 1
//   struct SitePageArticleContentSource: ArticleContentSource {
//     init(template: SiteTemplate = .v1, load: @escaping @Sendable (URL) async throws -> Data)
//   }
//   EFDomain: ArticleContent, ArticleBlock, InlineRun, ArticleContentError (see ArticleContentModelTests).
// Decisions pinned here (from ADR-007 unless said):
// - metadata from the NewsArticle JSON-LD when present (title, author, category, dates); chapô, cover,
//   captions, festival, author presentation, related, sponsored and reading time from the template;
//   without JSON-LD, everything from the template;
// - body = `div.article-body` up to `div.read-end`; nothing else of the page becomes a block;
// - h2 to h4 keep their level; a bold-only paragraph under 120 characters becomes a level 3 heading;
// - links and images are absolute addresses on the site; image addresses carry no `?w=` size;
// - caption = the whole figcaption text, credit included, whitespace collapsed (spec'd here: the ADR
//   gives no rule to split caption and credit); empty `alt` → nil;
// - empty paragraphs are dropped;
// - no title or empty body → ArticleContentError.unreadable (never a half-empty article);
// - only https://esprit-festivalier.fr/ addresses are downloaded; a loading error reaches the caller
//   unchanged (offline is not "unreadable": the screen says different things).

// MARK: - Live report (10675)

@Suite struct OrelsanLiveReportTests {
    private func content() async throws -> ArticleContent {
        try await readArticle(try ArticlePage.orelsanPage(), at: ArticlePage.orelsan)
    }

    @Test func titleAndCategoryComeFromTheArticle() async throws {
        let article = try await content()

        #expect(article.title == "« Je le connais de nom mais j'ai jamais écouté » à Nantes, Orelsan séduit même les novices")
        #expect(article.category == .liveReport)
        #expect(article.key == ArticleKey(rawValue: "10675"))
        #expect(article.url == ArticlePage.orelsan)
    }

    @Test func theChapoIsWholeNotTheShortenedSummary() async throws {
        let chapo = try #require(try await content().chapo)

        #expect(chapo.hasPrefix("Ce lundi 23 novembre, Orelsan s’est produit au Zénith de Nantes"))
        #expect(chapo.hasSuffix("« C’était quelque chose de vraiment cool. »"))
    }

    @Test func theAuthorIsNamedAndLinkedToTheirPage() async throws {
        let author = try #require(try await content().author)

        #expect(author.name == "Mano Le Bris")
        #expect(author.slug == "mano-le-bris")
        #expect(author.avatarURL == nil, "initials avatar, no photo")
        #expect(author.bio == "Reporter bénévole pour Esprit Festivalier")
    }

    @Test func datesAndReadingTimeAreKept() async throws {
        let article = try await content()
        let published = isoDate("2026-11-25T09:01:49.034Z")

        #expect(abs(article.publishedAt.timeIntervalSince(published)) < 0.001)
        #expect(article.modifiedAt.map { abs($0.timeIntervalSince(published)) < 0.001 } == true)
        #expect(article.readingMinutes == 3)
    }

    @Test func theCoverPhotoKeepsItsCreditAndSize() async throws {
        let cover = try #require(try await content().cover)

        #expect(cover.url == site("/media/2026/11/fond-d-ecran-bf60094a.jpg"))
        #expect(cover.caption == "Orelsan / Mano Le Bris @manoverso")
        #expect(cover.alt == "Orelsan lors de son concert au Zénith de Nantes, lundi 23 novembre -")
        #expect(cover.width == 6024)
        #expect(cover.height == 4024)
    }

    @Test func theBodyStartsWithTheFirstParagraphNotTheChapo() async throws {
        let first = try #require(try await content().blocks.first)

        guard case let .paragraph(runs) = first else {
            Issue.record("first block is \(first)")
            return
        }
        #expect(plain(runs).hasPrefix("À 21 ans, Adrien n'est pas vraiment ce qu'on pourrait appeler un grand connaisseur d'Orelsan."))
    }

    @Test func boldOnlyParagraphsBecomeHeadings() async throws {
        let found = headings(try await content().blocks)

        #expect(found == [
            Heading(level: 3, text: "« C'est presque plus un spectacle qu'un concert »"),
            Heading(level: 3, text: "Une première rencontre qui donne envie d'en découvrir davantage")
        ])
    }

    @Test func aParagraphMixingBoldAndPlainTextStaysAParagraph() async throws {
        let texts = paragraphs(try await content().blocks)

        #expect(texts.contains { $0.hasPrefix("« Je savais qu'Orelsan avait fait un film (NDLR : Yoroï)") })
    }

    @Test func boldItalicQuotesKeepBothStyles() async throws {
        let quote = try #require(runs(try await content().blocks).first {
            $0.text.contains("Je connaissais surtout son nom et quelques morceaux par-ci par-là.")
        })

        #expect(quote.bold)
        #expect(quote.italic)
    }

    @Test func italicAloneIsItalicNotBold() async throws {
        let run = try #require(runs(try await content().blocks).first { $0.text.contains("L'odeur de l'essence.") })

        #expect(run.italic)
        #expect(!run.bold)
    }

    @Test func externalLinksKeepTheirAddress() async throws {
        let all = runs(try await content().blocks)
        let mentir = try #require(all.first { $0.text == "Mentir au psy" })
        let peon = try #require(all.first { $0.text == "Péon" })

        #expect(mentir.link == URL(string: "https://www.youtube.com/watch?v=tFhwD-9Zhzg"))
        #expect(peon.link == URL(string: "https://www.youtube.com/watch?v=j3YH00VSCro"))
        #expect(mentir.link.map(SiteLink.init(url:)) == .external(URL(string: "https://www.youtube.com/watch?v=tFhwD-9Zhzg")!))
    }

    @Test func aLinkToAnArtistOfTheSiteIsRecognised() async throws {
        let run = try #require(runs(try await content().blocks).first { $0.text == "le rappeur continuera sa tournée" })

        #expect(run.link.map(SiteLink.init(url:)) == .artist(slug: "orelsan"))
    }

    @Test func readAlsoPointsToTheOtherArticle() async throws {
        let readAlso = try await content().blocks.compactMap { block -> ArticleSummary? in
            if case let .readAlso(summary) = block { summary } else { nil }
        }

        #expect(readAlso.map(\.title) == ["Superbus : près de deux heures de tubes à l'Accor Arena"])
        #expect(readAlso.map(\.key) == [ArticleKey(rawValue: "10673")])
        #expect(readAlso.map(\.url) == [site("/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673/")])
    }

    @Test func theBodyEndsWithItsLastParagraph() async throws {
        let last = try #require(try await content().blocks.last)

        #expect(text(of: last) == "Co-écrit par Adrien Favrie et Mano Le Bris")
    }

    @Test func nothingAroundTheBodyBecomesABlock() async throws {
        // Breadcrumb, share widgets, tags, author box and related cards are outside the body.
        let all = try await content().blocks.map(text(of:)).joined(separator: "\n")

        for outside in ["Accueil", "Partager", "Copier le lien", "Reporter bénévole", "Articles connexes",
                        "Kodaline", "Découverte musicale", "Lire aussi"] {
            #expect(!all.contains(outside), "\(outside)")
        }
    }

    @Test func relatedArticlesAreListedWithDecodedTitles() async throws {
        let related = try await content().related

        #expect(related.count == 6)
        #expect(related.first?.title == "Superbus : près de deux heures de tubes à l'Accor Arena")
        #expect(related.map(\.title).contains("Bigflo & Oli au Mans : Soprano, le MSB et un avant-goût de Karma 2"))
        #expect(related.allSatisfy { SiteLink(url: $0.url) == .article($0.key) })
    }

    @Test func anArticleWithoutFestivalOrSponsorSaysSo() async throws {
        let article = try await content()

        #expect(article.festival == nil)
        #expect(!article.isSponsored)
    }

    @Test func theParserVersionIsTheTemplates() async throws {
        #expect(try await content().parserVersion == SiteTemplate.v1.parserVersion)
        #expect(SiteTemplate.v1.parserVersion == 1)
    }
}

// MARK: - Programmation with photos (10672)

@Suite struct TerresDuSonProgrammationTests {
    private func content() async throws -> ArticleContent {
        try await readArticle(try ArticlePage.terresDuSonPage(), at: ArticlePage.terresDuSon)
    }

    @Test func theFestivalOfTheArticleIsKnown() async throws {
        let festival = try #require(try await content().festival)

        #expect(festival.slug == "terres-du-son")
        #expect(festival.name == "Terres du Son 2027")
    }

    @Test func metadata() async throws {
        let article = try await content()

        #expect(article.title == "Terres du Son 2027 : Orelsan, Vald et Christophe Maé en têtes d'affiche")
        #expect(article.category == .programmation)
        #expect(abs(article.publishedAt.timeIntervalSince(isoDate("2026-11-24T16:28:00.000Z"))) < 0.001)
        #expect(article.readingMinutes == 3)
    }

    @Test func aPhotoAvatarIsAnAbsoluteAddress() async throws {
        let author = try #require(try await content().author)

        #expect(author.slug == "jules-deloison")
        #expect(author.avatarURL == site("/_avatar/8f2dd5dad2bea141ee48a8125fddd67f.jpg"))
    }

    @Test func h3AndBoldOnlyParagraphsAreHeadingsInOrder() async throws {
        let found = headings(try await content().blocks)

        #expect(found == [
            Heading(level: 3, text: "Le retour au domaine de Candé"),
            Heading(level: 3, text: "Vendredi 9 juillet : Orelsan en ouverture"),
            Heading(level: 3, text: "Samedi 10 juillet : un trio de rap en bloc"),
            Heading(level: 3, text: "Dimanche 11 juillet : Christophe Maé et les sons reggae"),
            Heading(level: 3, text: "Infos pratiques")
        ])
    }

    @Test func aHeadingKeepsTheLinkItHolds() async throws {
        let heading = try #require(try await content().blocks.first {
            if case .heading = $0 { text(of: $0).hasPrefix("Vendredi 9 juillet") } else { false }
        })
        guard case let .heading(_, runs) = heading else { return }

        #expect(runs.first { $0.text == "Orelsan" }?.link == site("/artiste/orelsan/"))
    }

    @Test func everyPhotoOfTheBodyIsKeptWithItsCredit() async throws {
        let found = images(try await content().blocks)

        #expect(found.map(\.caption) == [
            nil,
            "Vald @odieuxboby",
            "Christophe Maé - (c)Mr Brainwash",
            "Marguerite - ©MG",
            "Annonce programmation Terres du Son 2027"
        ])
    }

    @Test func aPhotoWithoutFigureIsStillAnImage() async throws {
        let bare = try #require(images(try await content().blocks).first)

        #expect(bare.url == site("/media/2026/11/orelsan-c-felix-aaa-a6d9acfa.webp"))
        #expect(bare.width == 759)
        #expect(bare.height == 506)
        #expect(bare.alt == nil)
    }

    @Test func aPhotoKeepsItsAltText() async throws {
        let marguerite = try #require(images(try await content().blocks).first { $0.caption == "Marguerite - ©MG" })

        #expect(marguerite.alt == "M")
        #expect(marguerite.url == site("/media/2026/11/m-97c78cfb.png"))
    }

    @Test func relativeLinksBecomeAddressesOnTheSite() async throws {
        let run = try #require(runs(try await content().blocks).first { $0.text == "Terres du Son" })

        #expect(run.link == site("/festival/terres-du-son/"))
        #expect(run.link.map(SiteLink.init(url:)) == .festival(slug: "terres-du-son"))
    }

    @Test func anAbsoluteLinkToAnotherArticleIsAnArticle() async throws {
        let run = try #require(runs(try await content().blocks).first { $0.text.hasPrefix("Le rappeur caennais a déjà fait étape en 2026 à Musilac") })

        #expect(run.link.map(SiteLink.init(url:)) == .article(ArticleKey(rawValue: "10032")))
    }

    @Test func boldInsideAParagraphIsBoldAndLinkedWhenItIsALink() async throws {
        let all = runs(try await content().blocks)
        let vald = try #require(all.first { $0.text == "Vald" })

        #expect(vald.bold)
        #expect(vald.link == site("/artiste/vald/"))
        #expect(all.contains { $0.text == "La fuite en avant" && $0.italic })
    }

    @Test func emptyParagraphsAreDropped() async throws {
        let blocks = try await content().blocks

        #expect(!blocks.contains { if case .paragraph = $0 { text(of: $0).isEmpty } else { false } })
        #expect(paragraphs(blocks).last == "De nouveaux artistes viendront enrichir cette affiche dès le début de l'année 2027, alors un peu de patience avant de découvrir la suite !")
    }

    @Test func relatedCardsAreArticlesOnly() async throws {
        let related = try await content().related

        #expect(related.count == 6)
        #expect(related.first?.title == "La Nuit de l’Erdre dévoile les premiers noms de sa programmation 2027")
    }

    @Test func theFestivalWidgetIsNotPartOfTheArticle() async throws {
        let all = try await content().blocks.map(text(of:)).joined(separator: "\n")

        #expect(!all.contains("Nos autres articles"))
        #expect(!all.contains("prochaine édition 9 au 11 juillet 2027"))
    }
}

// MARK: - Décryptage with h2 (10556)

@Suite struct FestivalsPolitiquesTests {
    private func content() async throws -> ArticleContent {
        try await readArticle(try ArticlePage.politiquesPage(), at: ArticlePage.politiques)
    }

    @Test func h2HeadingsKeepTheirLevel() async throws {
        #expect(headings(try await content().blocks) == [
            Heading(level: 2, text: "Une très vieille histoire"),
            Heading(level: 2, text: "Les financeurs publics entrent dans la danse"),
            Heading(level: 2, text: "La scène et la fosse aussi"),
            Heading(level: 2, text: "Qui tient le stylo ?")
        ])
    }

    @Test func firstAndLastParagraphs() async throws {
        let texts = paragraphs(try await content().blocks)

        #expect(texts.first?.hasPrefix("Des élus de gauche ont crié à la censure.") == true)
        #expect(texts.last?.hasPrefix("Un festival qui voudrait ne froisser personne aurait du mal à remplir une plaine.") == true)
    }

    @Test func photoCredits() async throws {
        let article = try await content()

        #expect(images(article.blocks).map(\.caption) == [
            "Solidays 2024 - Kobayashi_photos",
            "We Love Green 2025 - Mathieu Foucher",
            "Printemps de Bourges - Mathieu Foucher"
        ])
        #expect(article.cover?.caption == "C. Brule")
    }

    @Test func metadata() async throws {
        let article = try await content()

        #expect(article.title == "Les festivals peuvent-ils encore être politiques ?")
        #expect(article.category == .decryptage)
        #expect(article.readingMinutes == 5)
        #expect(article.author?.slug == "marlo-kerleroux")
        #expect(article.author?.bio == "Reporter bénévole pour Esprit Festivalier")
    }

    @Test func artistLinkInsideAParagraph() async throws {
        let run = try #require(runs(try await content().blocks).first { $0.text == "Kneecap" })

        #expect(run.link.map(SiteLink.init(url:)) == .artist(slug: "kneecap"))
    }
}
