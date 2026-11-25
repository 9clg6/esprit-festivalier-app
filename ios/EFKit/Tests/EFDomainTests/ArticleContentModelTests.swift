import Foundation
import Testing
import EFDomain

// STORY-053 (FR-027, ADR-007 "Modèle en blocs"): an article read from the site becomes typed blocks
// that the native reader (E11) shows and the offline cache stores as JSON.
// Assumed API (EFDomain), from the architecture doc:
//   struct ArticleKey: RawRepresentable<String>, Codable, Hashable { init(rawValue:); init(url: URL);
//                                                                     init?(numbered: URL) }
//   struct InlineRun { text; bold = false; italic = false; link: URL? }   init(text:bold:italic:link:)
//   enum ArticleBlock { paragraph([InlineRun]); heading(level: Int, [InlineRun]); image(ArticleImage);
//                       quote([InlineRun], source: String?); list(ordered: Bool, items: [[InlineRun]]);
//                       embed(Embed); readAlso(ArticleSummary); separator }
//   struct ArticleImage { url; width: Int?; height: Int?; alt: String?; caption: String? }
//   struct Embed { provider: Embed.Provider (.youtube, .spotify, .instagram, .other); url; title: String? }
//   struct ArticleSummary { key; url; title }   (more optional fields allowed, defaulted in init)
//   struct AuthorRef { slug; name; avatarURL: URL?; bio: String? }
//   struct FestivalRef { slug; name }
//   struct ArticleContent { key, url, title, chapo, category, author, festival, publishedAt, modifiedAt,
//                           readingMinutes, cover, blocks, tags, related, isSponsored, parserVersion }
//   protocol ArticleContentSource: Sendable { func content(at url: URL) async throws -> ArticleContent }
//   enum ArticleContentError: Error, Equatable { case unreadable; case notSiteAddress(URL) }
// Decision pinned here: the key of an article is the number at the end of its address
// ("…-10675/" → "10675"), otherwise its path (ADR-007).

private func everyKindOfBlock() -> [ArticleBlock] {
    let link = URL(string: "https://esprit-festivalier.fr/artiste/orelsan/")!
    let readAlso = URL(string: "https://esprit-festivalier.fr/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673/")!
    return [
        .paragraph([
            InlineRun(text: "Le pic de la prestation ? "),
            InlineRun(text: "« L'odeur de l'essence. »", italic: true),
            InlineRun(text: " Et ", bold: true),
            InlineRun(text: "Orelsan", link: link)
        ]),
        .heading(level: 3, [InlineRun(text: "Infos pratiques")]),
        .image(ArticleImage(
            url: URL(string: "https://esprit-festivalier.fr/media/2026/11/c-9e7ff1e0.png")!,
            width: 543, height: 723, alt: nil, caption: "Christophe Maé - (c)Mr Brainwash")),
        .quote([InlineRun(text: "« Boucher le haut-parleur ne fait pas disparaître ce qui s'exprime derrière. »")],
               source: "Stéphane Krasniewski"),
        .list(ordered: true, items: [[InlineRun(text: "Arriver tôt")], [InlineRun(text: "Monter la tente")]]),
        .embed(Embed(provider: .youtube, url: URL(string: "https://www.youtube.com/embed/tFhwD-9Zhzg")!,
                     title: "Orelsan - Mentir au psy")),
        .readAlso(ArticleSummary(
            key: ArticleKey(rawValue: "10673"), url: readAlso,
            title: "Superbus : près de deux heures de tubes à l'Accor Arena")),
        .separator
    ]
}

private func sampleContent() -> ArticleContent {
    let url = URL(string: "https://esprit-festivalier.fr/terres-du-son-2027-orelsan-vald-et-christophe-mae-en-tetes-d-affiche-10672/")!
    return ArticleContent(
        key: ArticleKey(url: url), url: url,
        title: "Terres du Son 2027 : Orelsan, Vald et Christophe Maé en têtes d'affiche",
        chapo: "Terres du Son revient du vendredi 9 au dimanche 11 juillet 2027.",
        category: .programmation,
        author: AuthorRef(slug: "jules-deloison", name: "Jules Deloison",
                          avatarURL: URL(string: "https://esprit-festivalier.fr/_avatar/8f2dd5dad2bea141ee48a8125fddd67f.jpg"),
                          bio: "Reporter bénévole pour Esprit Festivalier"),
        festival: FestivalRef(slug: "terres-du-son", name: "Terres du Son 2027"),
        publishedAt: Date(timeIntervalSince1970: 1_795_105_680),
        modifiedAt: nil,
        readingMinutes: 3,
        cover: ArticleImage(url: URL(string: "https://esprit-festivalier.fr/media/2026/11/cover.png")!,
                            width: 1200, height: 675, alt: nil, caption: "Terres du son"),
        blocks: everyKindOfBlock(),
        tags: [],
        related: [],
        isSponsored: false,
        parserVersion: 1
    )
}

@Suite struct ArticleContentModelTests {
    @Test func anArticleReadOnceIsStoredAndReadBackUnchanged() throws {
        // The offline cache keeps ArticleContent as JSON (ADR-007 "Cache hors ligne").
        let content = sampleContent()

        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(ArticleContent.self, from: data)

        #expect(decoded == content)
    }

    @Test(arguments: everyKindOfBlock().indices)
    func everyKindOfBlockSurvivesTheCache(_ index: Int) throws {
        let block = everyKindOfBlock()[index]

        let decoded = try JSONDecoder().decode(ArticleBlock.self, from: JSONEncoder().encode(block))

        #expect(decoded == block)
    }

    @Test func styleAndLinkTellRunsApart() {
        let link = URL(string: "https://esprit-festivalier.fr/artiste/vald/")!

        #expect(InlineRun(text: "Vald") != InlineRun(text: "Vald", bold: true))
        #expect(InlineRun(text: "Vald") != InlineRun(text: "Vald", italic: true))
        #expect(InlineRun(text: "Vald") != InlineRun(text: "Vald", link: link))
        #expect(InlineRun(text: "Vald", bold: true, link: link) == InlineRun(text: "Vald", bold: true, link: link))
    }

    @Test func aRunIsPlainTextUnlessSaidOtherwise() {
        let run = InlineRun(text: "texte")

        #expect(!run.bold)
        #expect(!run.italic)
        #expect(run.link == nil)
    }
}

@Suite struct ArticleKeyTests {
    @Test(arguments: [
        ("/je-le-connais-de-nom-mais-j-ai-jamais-ecoute-a-nantes-orelsan-seduit-meme-les-novices-10675/", "10675"),
        ("/5-artistes-a-decouvrir-aux-trans-musicales-2026-10648/", "10648"),
        ("/francofolies-2027-le-programme-jour-par-jour-10632/", "10632"),
        ("/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673", "10673")
    ])
    func theKeyOfAnArticleIsTheNumberAtTheEndOfItsAddress(_ path: String, _ key: String) {
        #expect(ArticleKey(url: URL(string: "https://esprit-festivalier.fr" + path)!).rawValue == key)
    }

    @Test func theSameArticleReachedWithATrackingQueryHasTheSameKey() {
        let plain = URL(string: "https://esprit-festivalier.fr/les-festivals-peuvent-ils-encore-etre-politiques-10556/")!
        let tracked = URL(string: "https://esprit-festivalier.fr/les-festivals-peuvent-ils-encore-etre-politiques-10556/?utm_source=app#haut")!

        #expect(ArticleKey(url: tracked) == ArticleKey(url: plain))
    }

    @Test func anAddressWithoutANumberIsKeyedByItsPath() {
        #expect(ArticleKey(url: URL(string: "https://esprit-festivalier.fr/a-propos/")!).rawValue == "/a-propos/")
    }
}

// Review of PR #24 (Opus): reactions and reads (FR-030, FR-036) are kept and later sent under the article
// key of ADR-007, the number at the end of `/<slug>-<number>/`; the server only takes 1 to 9 digits
// ("Clés d'articles validées (numéro de 1 à 9 chiffres)"). The path fallback of `init(url:)` stays for the
// reader's cache (STORY-053); reactions and reads use the failable one and skip an article without a number.
// Assumed API (EFDomain): `ArticleKey.init?(numbered url: URL)`: the key of `/<slug>-<1…9 digits>/`, else nil.
@Suite struct NumberedArticleKeyTests {
    private func numbered(_ address: String) -> ArticleKey? { ArticleKey(numbered: URL(string: address)!) }

    @Test(arguments: [
        "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/",
        "https://esprit-festivalier.fr/a-nantes-orelsan-seduit-10675/",
        "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675",
        "https://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/?utm_source=rss&utm_medium=app",
        "http://esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/",
        "https://www.esprit-festivalier.fr/orelsan-seduit-meme-les-novices-10675/#reactions"
    ])
    func everyAddressOfTheArticleGivesItsNumber(_ address: String) {
        #expect(numbered(address)?.rawValue == "10675")
    }

    @Test func nineDigitsAreAKey() {
        #expect(numbered("https://esprit-festivalier.fr/un-article-123456789/")?.rawValue == "123456789")
    }

    @Test(arguments: [
        "https://esprit-festivalier.fr/a-propos/",
        "https://esprit-festivalier.fr/",
        "https://esprit-festivalier.fr/2026/",
        "https://esprit-festivalier.fr/festival/hellfest-2026/",
        "https://esprit-festivalier.fr/un-article-1234567890/"
    ])
    func anAddressThatIsNotANumberedArticleHasNoKey(_ address: String) {
        #expect(numbered(address) == nil)
    }
}
