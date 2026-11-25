import Foundation
import Testing
import EFDomain
import EFData

// STORY-054 (FR-027 "Un article déjà ouvert se relit hors ligne", NFR-002, ADR-007 "Cache hors ligne").
// Assumed API (EFData):
//   actor CachedArticleContentSource: ArticleContentSource {
//     init(wrapping source: any ArticleContentSource, directory: URL, parserVersion: Int = SiteTemplate.v1.parserVersion,
//          maxAge: TimeInterval = 3600, limit: Int = 100, now: @escaping @Sendable () -> Date = Date.init)
//   }
// Decisions pinned here (ADR-007, made single-call: there is no "show now, refresh later" channel in
// `content(at:)`):
// - one JSON copy per article key (`…-10675/` and `…-10675/?utm_source=x` share it), on disk: a new
//   instance on the same directory finds it;
// - a copy less than an hour old is returned without asking the source;
// - an older copy, or a copy of another parser version, is refreshed from the source; if the source
//   fails (offline, unreadable page), the copy is returned as it is;
// - no copy: the source's error reaches the caller unchanged (offline ≠ unreadable for the screen);
// - at most 100 articles; storing one more removes the one stored longest ago.

private final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 1_795_000_000)

    func now() -> Date { lock.withLock { current } }
    func advance(by seconds: TimeInterval) { lock.withLock { current += seconds } }
}

/// A source whose answer the test chooses, and which counts the calls.
private actor ScriptedSource: ArticleContentSource {
    private(set) var calls = 0
    private var script: @Sendable (URL) throws -> ArticleContent

    init(_ answer: @escaping @Sendable (URL) throws -> ArticleContent) { script = answer }

    func answer(with new: @escaping @Sendable (URL) throws -> ArticleContent) { script = new }

    func content(at url: URL) async throws -> ArticleContent {
        calls += 1
        return try script(url)
    }
}

private func article(_ url: URL, title: String = "Titre", parserVersion: Int = 1) -> ArticleContent {
    ArticleContent(
        key: ArticleKey(url: url), url: url, title: title, chapo: nil, category: .actu, author: nil, festival: nil,
        publishedAt: Date(timeIntervalSince1970: 1_794_000_000), modifiedAt: nil, readingMinutes: nil, cover: nil,
        blocks: [.paragraph([InlineRun(text: "Texte de \(title).")])], tags: [], related: [], isSponsored: false,
        parserVersion: parserVersion)
}

private func articleURL(_ number: Int) -> URL { URL(string: "https://esprit-festivalier.fr/un-article-\(number)/")! }

private func cacheDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "CachedArticleContentSourceTests-\(UUID().uuidString)")
}

private let offline = URLError(.notConnectedToInternet)

@Suite struct CachedArticleContentSourceTests {
    @Test func anArticleReadOnceOpensAgainOffline() async throws {
        let directory = cacheDirectory()
        let clock = ManualClock()
        let url = articleURL(10675)
        let online = ScriptedSource { article($0, title: "Orelsan à Nantes") }
        _ = try await CachedArticleContentSource(wrapping: online, directory: directory, now: { clock.now() }).content(at: url)
        clock.advance(by: 2 * 3600)

        let source = ScriptedSource { _ in throw offline }
        let reopened = try await CachedArticleContentSource(wrapping: source, directory: directory, now: { clock.now() })
            .content(at: url)

        #expect(reopened == article(url, title: "Orelsan à Nantes"))
    }

    @Test func aCopyLessThanAnHourOldIsShownWithoutDownloading() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0) }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        let url = articleURL(10672)
        _ = try await cache.content(at: url)

        clock.advance(by: 59 * 60)
        let again = try await cache.content(at: url)

        #expect(again == article(url))
        #expect(await source.calls == 1)
    }

    @Test func aCopyOlderThanAnHourIsRefreshed() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: "Première version") }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        let url = articleURL(10672)
        _ = try await cache.content(at: url)

        clock.advance(by: 61 * 60)
        await source.answer { article($0, title: "Corrigée") }
        let refreshed = try await cache.content(at: url)

        #expect(refreshed.title == "Corrigée")
        #expect(await source.calls == 2)
    }

    @Test func theRefreshedCopyReplacesTheOldOne() async throws {
        let directory = cacheDirectory()
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: "Première version") }
        let cache = CachedArticleContentSource(wrapping: source, directory: directory, now: { clock.now() })
        let url = articleURL(10672)
        _ = try await cache.content(at: url)
        clock.advance(by: 2 * 3600)
        await source.answer { article($0, title: "Corrigée") }
        _ = try await cache.content(at: url)

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw offline }
        let offlineCopy = try await cache.content(at: url)

        #expect(offlineCopy.title == "Corrigée")
    }

    @Test func offlineWithoutACopyTheNetworkErrorReachesTheScreen() async throws {
        let cache = CachedArticleContentSource(
            wrapping: ScriptedSource { _ in throw offline }, directory: cacheDirectory(), now: { Date(timeIntervalSince1970: 1_795_000_000) })

        await #expect(throws: offline) { try await cache.content(at: articleURL(10556)) }
    }

    @Test func anUnreadablePageWithoutACopyIsUnreadable() async throws {
        let cache = CachedArticleContentSource(
            wrapping: ScriptedSource { _ in throw ArticleContentError.unreadable }, directory: cacheDirectory(),
            now: { Date(timeIntervalSince1970: 1_795_000_000) })

        await #expect(throws: ArticleContentError.unreadable) { try await cache.content(at: articleURL(10556)) }
    }

    @Test func anUnreadablePageAfterATemplateChangeStillShowsTheCopy() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: "Lu avant le changement") }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        let url = articleURL(10556)
        _ = try await cache.content(at: url)

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw ArticleContentError.unreadable }

        #expect(try await cache.content(at: url).title == "Lu avant le changement")
    }

    @Test func aCopyOfAnotherParserVersionIsReloadedEvenWhenRecent() async throws {
        let directory = cacheDirectory()
        let clock = ManualClock()
        let url = articleURL(10675)
        _ = try await CachedArticleContentSource(
            wrapping: ScriptedSource { article($0, title: "v1", parserVersion: 1) }, directory: directory,
            parserVersion: 1, now: { clock.now() }
        ).content(at: url)

        clock.advance(by: 60)
        let source = ScriptedSource { article($0, title: "v2", parserVersion: 2) }
        let upgraded = try await CachedArticleContentSource(
            wrapping: source, directory: directory, parserVersion: 2, now: { clock.now() }
        ).content(at: url)

        #expect(upgraded.title == "v2")
        #expect(await source.calls == 1)
    }

    @Test func aCopyOfAnotherParserVersionIsShownAsItIsOffline() async throws {
        let directory = cacheDirectory()
        let clock = ManualClock()
        let url = articleURL(10675)
        _ = try await CachedArticleContentSource(
            wrapping: ScriptedSource { article($0, title: "v1", parserVersion: 1) }, directory: directory,
            parserVersion: 1, now: { clock.now() }
        ).content(at: url)

        let shown = try await CachedArticleContentSource(
            wrapping: ScriptedSource { _ in throw offline }, directory: directory, parserVersion: 2, now: { clock.now() }
        ).content(at: url)

        #expect(shown == article(url, title: "v1", parserVersion: 1))
    }

    @Test func eachArticleHasItsOwnCopy() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: $0.lastPathComponent) }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        _ = try await cache.content(at: articleURL(1))
        _ = try await cache.content(at: articleURL(2))

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw offline }

        #expect(try await cache.content(at: articleURL(1)).title == "un-article-1")
        #expect(try await cache.content(at: articleURL(2)).title == "un-article-2")
        await #expect(throws: offline) { try await cache.content(at: articleURL(3)) }
    }

    @Test func theSameArticleReachedFromANotificationLinkUsesTheSameCopy() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: "Orelsan à Nantes") }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        _ = try await cache.content(at: articleURL(10675))

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw offline }
        let tracked = URL(string: "https://esprit-festivalier.fr/un-article-10675/?utm_source=notification")!

        #expect(try await cache.content(at: tracked).title == "Orelsan à Nantes")
    }

    @Test func atMostAHundredArticlesAreKeptAndTheOldestGoesFirst() async throws {
        let clock = ManualClock()
        let source = ScriptedSource { article($0, title: $0.lastPathComponent) }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), now: { clock.now() })
        for number in 1...101 {
            _ = try await cache.content(at: articleURL(number))
            clock.advance(by: 1)
        }

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw offline }

        await #expect(throws: offline) { try await cache.content(at: articleURL(1)) }
        #expect(try await cache.content(at: articleURL(2)).title == "un-article-2")
        #expect(try await cache.content(at: articleURL(101)).title == "un-article-101")
    }

    // Review of PR #25: copies are named after a hash of the key, so two keys never share a file.
    @Test func pathsThatLookAlikeNeverShareACopy() async throws {
        let source = ScriptedSource { article($0, title: $0.path()) }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory())
        _ = try await cache.content(at: URL(string: "https://esprit-festivalier.fr/a/b/")!)

        let other = try await cache.content(at: URL(string: "https://esprit-festivalier.fr/a_b/")!)

        #expect(other.title == "/a_b/")
        #expect(await source.calls == 2)
    }

    @Test func theRootAddressHasARealCopyCountedByTheLimit() async throws {
        let clock = ManualClock()
        let root = URL(string: "https://esprit-festivalier.fr")!
        let source = ScriptedSource { article($0, title: $0.absoluteString) }
        let cache = CachedArticleContentSource(wrapping: source, directory: cacheDirectory(), limit: 1, now: { clock.now() })
        _ = try await cache.content(at: root)
        clock.advance(by: 1)
        _ = try await cache.content(at: articleURL(1))

        clock.advance(by: 2 * 3600)
        await source.answer { _ in throw offline }

        await #expect(throws: offline) { try await cache.content(at: root) }
        #expect(try await cache.content(at: articleURL(1)).url == articleURL(1))
    }

    @Test func aCopyOfAnotherArticleIsIgnored() async throws {
        let mine = cacheDirectory()
        let theirs = cacheDirectory()
        _ = try await CachedArticleContentSource(wrapping: ScriptedSource { article($0) }, directory: mine)
            .content(at: articleURL(1))
        _ = try await CachedArticleContentSource(wrapping: ScriptedSource { article($0) }, directory: theirs)
            .content(at: articleURL(2))
        let manager = FileManager.default
        let myFile = try #require(try manager.contentsOfDirectory(at: mine, includingPropertiesForKeys: nil).first)
        let theirFile = try #require(try manager.contentsOfDirectory(at: theirs, includingPropertiesForKeys: nil).first)
        try Data(contentsOf: theirFile).write(to: myFile)

        let cache = CachedArticleContentSource(wrapping: ScriptedSource { _ in throw offline }, directory: mine)

        await #expect(throws: offline) { try await cache.content(at: articleURL(1)) }
    }

    @Test func aCorruptedCopyIsTreatedAsNoCopy() async throws {
        let directory = cacheDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in ["10675.json", "10675"] {
            try Data("{ pas du JSON".utf8).write(to: directory.appending(path: name))
        }
        let source = ScriptedSource { article($0, title: "Frais") }
        let cache = CachedArticleContentSource(wrapping: source, directory: directory, now: { Date(timeIntervalSince1970: 1_795_000_000) })

        #expect(try await cache.content(at: articleURL(10675)).title == "Frais")
    }
}

// The cache wraps the real page source too (the app's chain): an article read from its page opens offline.
@Test func anArticleReadFromItsPageOpensAgainOffline() async throws {
    let directory = cacheDirectory()
    let clock = ManualClock()
    let page = try ArticlePage.orelsanPage()
    let read = try await CachedArticleContentSource(
        wrapping: SitePageArticleContentSource(load: { url in served(page, at: url) }), directory: directory, now: { clock.now() }
    ).content(at: ArticlePage.orelsan)

    clock.advance(by: 2 * 3600)
    let reopened = try await CachedArticleContentSource(
        wrapping: SitePageArticleContentSource(load: { _ in throw URLError(.notConnectedToInternet) }),
        directory: directory, now: { clock.now() }
    ).content(at: ArticlePage.orelsan)

    #expect(reopened == read)
}

// STORY-053: the mock source shows the full text of the demo articles without network.
@Test func theMockSourceHasTheFullTextOfEveryDemoArticle() async throws {
    let source = MockArticleContentSource()

    for listed in try await MockArticleSource().articles(category: nil) {
        let content = try await source.content(at: listed.link)
        #expect(content.title == listed.title, "\(listed.link)")
        #expect(!content.blocks.isEmpty, "\(listed.link)")
    }
}
