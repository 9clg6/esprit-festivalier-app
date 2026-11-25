import Foundation
import Testing
import EFDomain

// FR-028, ADR-007 "Liens internes": a link of the site opens the matching screen of the app; a link
// to another site is external (Safari sheet). One function classifies an address; the addresses below
// are taken from the fixtures (Tests/EFDataTests/Fixtures, pages of 2026-11-25).
// Assumed API (EFDomain):
//   enum SiteLink: Hashable, Codable, Sendable {
//     case article(ArticleKey), festival(slug: String), author(slug: String), artist(slug: String),
//          category(slug: String), tag(slug: String), page(URL), external(URL)
//     init(url: URL)
//   }

private func link(_ address: String) -> SiteLink { SiteLink(url: URL(string: address)!) }

@Suite struct SiteLinkTests {
    @Test(arguments: [
        ("https://esprit-festivalier.fr/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673/", "10673"),
        ("https://esprit-festivalier.fr/jour-2-a-musilac-entre-ambiance-funk-et-retour-dorelsan-10032/", "10032"),
        ("https://esprit-festivalier.fr/5-artistes-a-decouvrir-aux-trans-musicales-2026-10648/", "10648")
    ])
    func anArticleAddressOpensThatArticle(_ address: String, _ key: String) {
        #expect(link(address) == .article(ArticleKey(rawValue: key)))
    }

    @Test func anAuthorAddressOpensTheAuthorPage() {
        #expect(link("https://esprit-festivalier.fr/author/mano-le-bris/") == .author(slug: "mano-le-bris"))
    }

    @Test func aFestivalAddressOpensTheFestival() {
        #expect(link("https://esprit-festivalier.fr/festival/terres-du-son/") == .festival(slug: "terres-du-son"))
    }

    @Test func aCategoryAddressOpensTheCategory() {
        #expect(link("https://esprit-festivalier.fr/category/reports/") == .category(slug: "reports"))
    }

    @Test func anArtistAddressOpensTheArtist() {
        #expect(link("https://esprit-festivalier.fr/artiste/orelsan/") == .artist(slug: "orelsan"))
    }

    @Test func aKeywordAddressOpensTheKeyword() {
        #expect(link("https://esprit-festivalier.fr/tag/zenith-de-nantes/") == .tag(slug: "zenith-de-nantes"))
    }

    @Test func aKeywordEndingWithANumberIsStillAKeyword() {
        // Only an address at the root with a trailing number is an article.
        #expect(link("https://esprit-festivalier.fr/tag/printemps-2026/") == .tag(slug: "printemps-2026"))
    }

    @Test func anotherPageOfTheSiteStaysAPageOfTheSite() {
        let url = URL(string: "https://esprit-festivalier.fr/a-propos/")!

        #expect(SiteLink(url: url) == .page(url))
    }

    @Test(arguments: [
        "https://www.youtube.com/watch?v=tFhwD-9Zhzg",
        "https://www.instagram.com/marlokerleroux",
        "https://example.com/festival/terres-du-son/"
    ])
    func aLinkToAnotherSiteIsExternal(_ address: String) {
        let url = URL(string: address)!

        #expect(SiteLink(url: url) == .external(url))
    }

    // Review of PR #25: the Safari sheet opens only http(s); a mail or phone address is its own kind.
    // Assumed API: `case mail(…)` and `case phone(…)`, payload left to the implementation.
    @Test func aMailAddressIsAMailLinkNotExternal() {
        let found = link("mailto:redaction@esprit-festivalier.fr")

        #expect({ if case .mail = found { true } else { false } }(), "\(found)")
    }

    @Test func aPhoneNumberIsAPhoneLinkNotExternal() {
        let found = link("tel:+33102030405")

        #expect({ if case .phone = found { true } else { false } }(), "\(found)")
    }

    @Test(arguments: ["https://esprit-festivalier.fr.evil.com/festival/hellfest/", "https://evil-esprit-festivalier.fr/x-12/"])
    func aLookAlikeHostIsExternal(_ address: String) {
        let url = URL(string: address)!

        #expect(SiteLink(url: url) == .external(url))
    }

    @Test func aTrackingQueryDoesNotChangeTheDestination() {
        #expect(link("https://esprit-festivalier.fr/festival/hellfest/?utm_source=newsletter") == .festival(slug: "hellfest"))
    }
}
