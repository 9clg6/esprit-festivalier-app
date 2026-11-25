import Foundation
import Testing
import EFDomain
import EFData

// STORY-026, FR-011: the articles come from the site's RSS feed (`/feed/`).
// Fixtures/feed.xml is the site's real feed fetched on 2026-11-25, cut to its
// first 5 items. It has one <category> per item (singular labels: "Actu",
// "Live report", "Décryptage", "Programmation"), an <enclosure> image, a plain
// text <description>, no content:encoded and no sponsored marking. The other
// cases (offset dates, HTML, body, errors) use small hand-written feeds.
//
// Decisions pinned here (open to the product owner, see the report):
// - id = the item's <guid>;
// - categories: the site label maps to the section of the same name; an unknown
//   label stays its own category (open set); no category at all means "Actu";
//   a known section wins over another label listed before it;
// - excerpt: HTML removed, entities decoded, spaces collapsed, at most 200
//   characters; when cut, it ends on a whole word followed by "…";
// - body (E11): one string per <p> of content:encoded, empty ones dropped;
//   without content:encoded, the whole description as one paragraph;
// - no author → ""; no image → nil; nothing marks sponsored → false;
// - an item without title, link or readable date is left out, not the feed.

enum RSSFeedFixture {
    /// The site's real feed, trimmed to 5 items.
    static func siteFeed() throws -> Data {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/feed.xml")
        return try Data(contentsOf: url)
    }

    static func feed(_ items: String...) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/" \
        xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Esprit Festivalier</title>
          <link>https://esprit-festivalier.fr/</link>
          <description>Le média des festivals, par ceux qui les vivent</description>
        \(items.joined(separator: "\n"))
        </channel>
        </rss>
        """.utf8)
    }

    /// One item; pass `nil` to leave an element out. Strings go in as raw XML.
    static func item(
        id: String = "1",
        title: String? = "Un titre",
        link: String? = "https://esprit-festivalier.fr/un-titre-1/",
        pubDate: String? = "Wed, 25 Nov 2026 11:27:35 GMT",
        creator: String? = "Chloé Magron",
        categories: [String] = ["Actu"],
        description: String? = "Un résumé.",
        content: String? = nil,
        enclosure: String? = "https://esprit-festivalier.fr/media/2026/11/image.jpg"
    ) -> String {
        var lines = ["<item>", "<guid isPermaLink=\"false\">guid-\(id)</guid>"]
        if let title { lines.append("<title>\(title)</title>") }
        if let link { lines.append("<link>\(link)</link>") }
        if let pubDate { lines.append("<pubDate>\(pubDate)</pubDate>") }
        if let creator { lines.append("<dc:creator>\(creator)</dc:creator>") }
        lines += categories.map { "<category>\($0)</category>" }
        if let description { lines.append("<description>\(description)</description>") }
        if let content { lines.append("<content:encoded><![CDATA[\(content)]]></content:encoded>") }
        if let enclosure { lines.append("<enclosure url=\"\(enclosure)\" type=\"image/jpeg\" length=\"0\"/>") }
        lines.append("</item>")
        return lines.joined(separator: "\n")
    }
}

private func articles(from feed: Data, category: Article.Category? = nil) async throws -> [Article] {
    try await RSSArticleSource(load: { feed }).articles(category: category)
}

private func siteArticles() async throws -> [Article] {
    try await articles(from: try RSSFeedFixture.siteFeed())
}

private func date(_ iso: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: iso), "bad ISO date in the test: \(iso)")
}

// MARK: - The site's real feed

@Suite struct RSSArticleSourceSiteFeedTests {
    @Test func everyItemOfTheFeedBecomesAnArticle() async throws {
        #expect(try await siteArticles().count == 5)
    }

    @Test func anArticleKeepsItsTitleLinkAuthorAndImage() async throws {
        let first = try #require(try await siteArticles().first)

        #expect(first.title == "Sum 41, la suite en solo ! Deryck Whibley revient au Bataclan")
        #expect(first.link == URL(string: "https://esprit-festivalier.fr/sum-41-la-suite-en-solo-deryck-whibley-revient-au-bataclan-10678/"))
        #expect(first.author == "Chloé Magron")
        #expect(first.imageURL == URL(string: "https://esprit-festivalier.fr/media/2026/11/deryck-650.png-3bd1712d.webp"))
    }

    @Test func theIdIsTheItemGuid() async throws {
        let ids = try await siteArticles().map(\.id)

        #expect(ids.first == "https://esprit-festivalier.fr/sum-41-la-suite-en-solo-deryck-whibley-revient-au-bataclan-10678/")
        #expect(Set(ids).count == ids.count)
    }

    @Test func aTitleShowsItsApostropheNotTheEntity() async throws {
        let titles = try await siteArticles().map(\.title)

        #expect(titles.contains("« Je le connais de nom mais j'ai jamais écouté » à Nantes, Orelsan séduit même les novices"))
        #expect(titles.allSatisfy { !$0.contains("&#") && !$0.contains("&amp;") })
    }

    @Test func thePublicationDateIsTheGMTInstantOfTheFeed() async throws {
        let dates = try await siteArticles().map(\.publishedAt)

        #expect(dates.first == (try date("2026-11-25T11:27:35Z")))
        #expect(dates.last == (try date("2026-11-24T16:28:00Z")))
    }

    @Test func theSiteSectionsBecomeTheAppCategories() async throws {
        let categories = try await siteArticles().map(\.category)

        #expect(categories == [.actu, .liveReport, .decryptage, .liveReport, .programmation])
    }

    @Test func everyExcerptFitsInTwoHundredCharactersAndEndsOnAWholeWord() async throws {
        // The 5 real descriptions are all longer than 200 characters.
        for article in try await siteArticles() {
            #expect(article.excerpt.count <= 200, "\(article.title)")
            #expect(article.excerpt.hasSuffix("…"), "\(article.title)")
            let kept = String(article.excerpt.dropLast())
            let full = try #require(article.body.first, "\(article.title)")
            #expect(full.hasPrefix(kept), "\(article.title)")
            #expect(kept.last.map { !$0.isWhitespace } == true, "\(article.title)")
            let next = full.dropFirst(kept.count).first
            #expect(next.map { $0.isWhitespace } == true, "cut inside a word: \(article.title)")
        }
    }

    @Test func withoutFullContentTheBodyIsTheWholeDescription() async throws {
        let first = try #require(try await siteArticles().first)

        #expect(first.body == [
            "Le chanteur de Sum 41 prépare sa première tournée solo, la Diamonds Of The Night Tour, avec trois dates "
                + "annoncées en France au printemps 2027 : Paris, Strasbourg et Rouen. Au programme, les chansons du "
                + "groupe, réarrangées pour des salles plus intimes, après la fin de l'aventure collective. Tour d'horizon."
        ])
    }

    @Test func nothingInTheFeedMarksAnArticleAsSponsored() async throws {
        #expect(try await siteArticles().allSatisfy { !$0.isSponsored })
    }
}

// MARK: - Fields

@Suite struct RSSArticleSourceFieldTests {
    @Test func aDateWithAnOffsetIsTheSameInstantAsInGMT() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(pubDate: "Wed, 25 Nov 2026 12:27:35 +0100"))

        let first = try #require(try await articles(from: feed).first)

        #expect(first.publishedAt == (try date("2026-11-25T11:27:35Z")))
    }

    @Test(arguments: [
        ("Live report", Article.Category.liveReport),
        ("Programmation", .programmation),
        ("Interview", .interview),
        ("Actu", .actu),
        ("Guide", .guide),
        ("Décryptage", .decryptage),
        ("Chronique", .chronique),
    ])
    func eachSiteSectionHasItsCategory(label: String, category: Article.Category) async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(categories: [label]))

        #expect(try await articles(from: feed).first?.category == category)
    }

    @Test func aSectionTheAppDoesNotKnowYetStaysItsOwnCategory() async throws {
        // Article.Category is an open set: the site adds sections without an app release.
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(categories: ["Portrait"]))

        #expect(try await articles(from: feed).first?.category == Article.Category(rawValue: "Portrait"))
    }

    @Test func anItemWithoutCategoryIsAnActu() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(categories: []))

        #expect(try await articles(from: feed).first?.category == .actu)
    }

    @Test func aKnownSectionWinsOverAnotherLabelListedBeforeIt() async throws {
        // WordPress lists tags as <category> too.
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(categories: ["Orelsan", "Live report"]))

        #expect(try await articles(from: feed).first?.category == .liveReport)
    }

    @Test(arguments: [
        ("L&amp;rsquo;été des festivals", "L’été des festivals"),
        ("L&amp;#8217;été des festivals", "L’été des festivals"),
        ("Rock &amp;amp; Folk", "Rock & Folk"),
        ("<![CDATA[Rock &amp; Folk]]>", "Rock & Folk"),
        ("Rock &#038; Folk", "Rock & Folk"),
    ])
    func aTitleShowsTheCharacterNotTheHTMLEntity(raw: String, shown: String) async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(title: raw))

        #expect(try await articles(from: feed).first?.title == shown)
    }

    @Test func theExcerptIsPlainTextWithoutHTML() async throws {
        let html = "<![CDATA[<p>Un <a href=\"https://x.fr\">concert</a> &amp; <strong>une fête</strong>.</p>\n\n<p>La suite.</p>]]>"
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(description: html))

        #expect(try await articles(from: feed).first?.excerpt == "Un concert & une fête. La suite.")
    }

    @Test func aShortDescriptionIsTheWholeExcerpt() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(description: "Trois jours de rock à Rennes."))

        #expect(try await articles(from: feed).first?.excerpt == "Trois jours de rock à Rennes.")
    }

    @Test func aDescriptionOfExactlyTwoHundredCharactersIsNotCut() async throws {
        let text = String(repeating: "abcd ", count: 39) + "abcde" // 200 characters
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(description: text))

        #expect(try await articles(from: feed).first?.excerpt == text)
    }

    @Test func aSingleWordLongerThanTheLimitIsCutAnyway() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(description: String(repeating: "a", count: 300)))

        let excerpt = try #require(try await articles(from: feed).first?.excerpt)

        #expect(excerpt.count <= 200)
        #expect(excerpt.hasPrefix("aaaa"))
        #expect(excerpt.hasSuffix("…"))
    }

    @Test func fullContentBecomesTheParagraphsOfTheBody() async throws {
        let content = """
        <p>Premier paragraphe.</p>
        <p>Deuxième &amp; <em>dernier</em>
        paragraphe.</p>
        <p>&nbsp;</p><p></p>
        """
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(content: content))

        #expect(try await articles(from: feed).first?.body == ["Premier paragraphe.", "Deuxième & dernier paragraphe."])
    }

    @Test func theExcerptStillComesFromTheDescriptionWhenThereIsFullContent() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(description: "Le résumé.", content: "<p>Le texte.</p>"))

        #expect(try await articles(from: feed).first?.excerpt == "Le résumé.")
    }

    @Test func anArticleWithoutImageHasNoImageURL() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(enclosure: nil))

        let first = try #require(try await articles(from: feed).first)

        #expect(first.imageURL == nil)
    }

    @Test func anArticleWithoutAuthorHasAnEmptyAuthor() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item(creator: nil))

        #expect(try await articles(from: feed).first?.author == "")
    }

    @Test func anArticleIsNotSponsoredByDefault() async throws {
        let feed = RSSFeedFixture.feed(RSSFeedFixture.item())

        #expect(try await articles(from: feed).first?.isSponsored == false)
    }
}

// MARK: - List, errors

@Suite struct RSSArticleSourceListTests {
    @Test func theNewestArticleComesFirstWhateverTheFeedOrder() async throws {
        let feed = RSSFeedFixture.feed(
            RSSFeedFixture.item(id: "old", pubDate: "Sun, 01 Nov 2026 10:00:00 GMT"),
            RSSFeedFixture.item(id: "new", pubDate: "Tue, 03 Nov 2026 10:00:00 GMT"),
            RSSFeedFixture.item(id: "mid", pubDate: "Mon, 02 Nov 2026 10:00:00 GMT")
        )

        #expect(try await articles(from: feed).map(\.id) == ["guid-new", "guid-mid", "guid-old"])
    }

    @Test func filteringByACategoryKeepsOnlyThatCategoryInDateOrder() async throws {
        let feed = RSSFeedFixture.feed(
            RSSFeedFixture.item(id: "a", pubDate: "Sun, 01 Nov 2026 10:00:00 GMT", categories: ["Programmation"]),
            RSSFeedFixture.item(id: "b", pubDate: "Mon, 02 Nov 2026 10:00:00 GMT", categories: ["Actu"]),
            RSSFeedFixture.item(id: "c", pubDate: "Tue, 03 Nov 2026 10:00:00 GMT", categories: ["Programmation"])
        )

        #expect(try await articles(from: feed, category: .programmation).map(\.id) == ["guid-c", "guid-a"])
    }

    @Test func anEmptyChannelGivesAnEmptyList() async throws {
        #expect(try await articles(from: RSSFeedFixture.feed()).isEmpty)
    }

    @Test(arguments: [
        "<rss><channel><item><title>Coupé</channel>",
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>Connexion au Wi-Fi</title></head><body></body></html>",
        "<html><body><p>Connexion au Wi-Fi</p></body></html>",
        "",
    ])
    func aDocumentThatIsNotAReadableFeedThrowsMalformedFeed(document: String) async throws {
        await #expect(throws: SourceError.malformedFeed) {
            try await articles(from: Data(document.utf8))
        }
    }

    @Test func whenTheFeedCannotBeLoadedTheLoaderErrorReachesTheScreen() async throws {
        let source = RSSArticleSource(load: { throw URLError(.notConnectedToInternet) })

        let error = await #expect(throws: URLError.self) {
            try await source.articles(category: nil)
        }

        #expect(error?.code == .notConnectedToInternet)
    }

    @Test(arguments: [
        RSSFeedFixture.item(id: "bad", title: nil),
        RSSFeedFixture.item(id: "bad", link: nil),
        RSSFeedFixture.item(id: "bad", pubDate: nil),
        RSSFeedFixture.item(id: "bad", pubDate: "demain"),
    ])
    func anIncompleteItemIsLeftOutAndTheOthersStay(incomplete: String) async throws {
        let feed = RSSFeedFixture.feed(incomplete, RSSFeedFixture.item(id: "good"))

        #expect(try await articles(from: feed).map(\.id) == ["guid-good"])
    }
}
