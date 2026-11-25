import Foundation
import Testing
import EFDomain
import EFData

// STORY-055 (E11 native reader, FR-027), with the link routing of STORY-056 (FR-028) and the
// "full text displayed" signal STORY-066 (FR-036) will count. Sources: sprint plan STORY-055/056/066,
// UX E11, architecture ADR-007 ("Échec : jamais d'ouverture silencieuse de Safari", "Liens internes",
// "Contenus tiers").
//
// Assumed API (EFData):
//   @MainActor @Observable public final class ArticleReaderModel {
//     public enum State: Equatable { case loading, loaded(ArticleContent), failed(Failure) }
//     public enum Failure: Equatable, Sendable {
//       case offline      // URLError notConnectedToInternet, timedOut, networkConnectionLost, cannotFindHost,
//                         // cannotConnectToHost, dataNotAllowed, and no copy: "Article complet indisponible hors ligne"
//       case unreadable   // any other read failure (ArticleContentError.*, other errors):
//                         // "Impossible d'afficher cet article dans l'app"
//     }
//     public init(article: Article, source: any ArticleContentSource)
//     public let article: Article              // the feed article: title, hero, excerpt shown at once
//     public private(set) var state: State     // .loading until the first answer
//     public var showsOpenOnSite: Bool { get }  // "Ouvrir sur le site ↗": only on .failed(.unreadable)
//     public var fullTextDisplayed: Bool { get } // loaded with at least one paragraph (read counting)
//     public func load() async                 // asks `source` for `article.link`; leaving the screen (the
//                                              // task cancelled) is not a failure; a `URLError(.cancelled)`
//                                              // without task cancellation (session invalidated) is .unreadable
//     public func retry() async                // loading again, then loaded or failed
//     public func destination(for url: URL) -> ReaderDestination
//   }
//   No embed activation state (review of PR #26): the embed card opens `Embed.url` in a Safari sheet.
//   Rendered blocks: ArticleReaderRenderingTests.swift.
//   public enum ReaderDestination: Equatable, Sendable {
//     case article(URL)                       // E11 by address (new route `articleURL`)
//     case festival(slug: String), author(slug: String), artist(slug: String)
//     case category(slug: String), tag(slug: String)
//     case external(URL)                      // Safari sheet (http/https only: it crashes on other schemes)
//     case system(URL)                        // openURL: Mail for mailto:, Phone for tel:
//     case ignored                            // nothing opens (javascript:, file:, data:…)
//   }

private let feedArticle = Article(
    id: "10675", title: "Orelsan enflamme Terres du Son",
    link: URL(string: "https://esprit-festivalier.fr/orelsan-terres-du-son-10675/")!, category: .liveReport,
    author: "Mano Le Bris", publishedAt: Date(timeIntervalSince1970: 1_794_000_000),
    imageURL: URL(string: "https://esprit-festivalier.fr/_img/orelsan.jpg?w=960"),
    excerpt: "Deux heures de show devant 15 000 personnes.")

private let photo = ArticleImage(
    url: URL(string: "https://esprit-festivalier.fr/_img/vald.jpg")!, width: 1600, height: 1067, alt: nil,
    caption: "Vald @odieuxboby")

private func fullText(_ blocks: [ArticleBlock] = [.paragraph([InlineRun(text: "Le Zénith était plein.")])])
    -> ArticleContent {
    ArticleContent(
        key: ArticleKey(url: feedArticle.link), url: feedArticle.link, title: feedArticle.title, chapo: nil,
        category: .liveReport, author: nil, festival: nil, publishedAt: feedArticle.publishedAt, modifiedAt: nil,
        readingMinutes: 3, cover: nil, blocks: blocks, tags: [], related: [], isSponsored: false, parserVersion: 1)
}

private let offline = URLError(.notConnectedToInternet)

/// Answers in order; the last answer repeats. Records the addresses it was asked for.
private actor ScriptedSource: ArticleContentSource {
    private var answers: [Result<ArticleContent, any Error>]
    private(set) var requested: [URL] = []

    init(_ answers: Result<ArticleContent, any Error>...) { self.answers = answers }

    func content(at url: URL) async throws -> ArticleContent {
        requested.append(url)
        let answer = answers.count > 1 ? answers.removeFirst() : answers[0]
        return try answer.get()
    }
}

/// Holds each request until the test answers it; a cancelled request throws `cancellationError`
/// (URLSession throws `URLError(.cancelled)`, `Task.sleep` throws `CancellationError`).
private actor GatedSource: ArticleContentSource {
    private var pending: [CheckedContinuation<ArticleContent, any Error>] = []
    private(set) var requestCount = 0
    private let cancellationError: any Error

    init(cancellationError: any Error = CancellationError()) { self.cancellationError = cancellationError }

    func content(at url: URL) async throws -> ArticleContent {
        requestCount += 1
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending.append($0) }
        } onCancel: {
            Task { await self.cancelPending() }
        }
    }

    func answer(_ result: Result<ArticleContent, any Error>) { pending.removeFirst().resume(with: result) }

    private func cancelPending() {
        for continuation in pending { continuation.resume(throwing: cancellationError) }
        pending.removeAll()
    }

    /// False after about 2 s without the `count`-th request (instead of hanging the suite).
    func waitForRequest(_ count: Int) async -> Bool {
        var tries = 0
        while requestCount < count || pending.isEmpty, tries < 2000 {
            tries += 1
            try? await Task.sleep(for: .milliseconds(1))
        }
        return requestCount >= count && !pending.isEmpty
    }
}

@MainActor @Suite struct ArticleReaderModelTests {
    // MARK: Loading, loaded

    @Test func theFeedArticleShowsAtOnceWhileTheFullTextLoads() async throws {
        let source = GatedSource()
        let model = ArticleReaderModel(article: feedArticle, source: source)
        let loading = Task { await model.load() }
        try #require(await source.waitForRequest(1))

        #expect(model.state == .loading)
        #expect(model.article == feedArticle)
        #expect(!model.fullTextDisplayed)
        #expect(!model.showsOpenOnSite)

        await source.answer(.success(fullText()))
        await loading.value
    }

    @Test func theFullTextIsReadFromTheArticleAddress() async {
        let source = ScriptedSource(.success(fullText()))
        let model = ArticleReaderModel(article: feedArticle, source: source)

        await model.load()

        #expect(model.state == .loaded(fullText()))
        #expect(await source.requested == [feedArticle.link])
        #expect(!model.showsOpenOnSite)
    }

    @Test func theFullTextOnScreenIsTheSignalForReadCounting() async {
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.success(fullText())))

        await model.load()

        #expect(model.fullTextDisplayed)
    }

    @Test func anArticleWithoutAParagraphIsNotCountedAsRead() async {
        let blocks: [ArticleBlock] = [.heading(level: 3, [InlineRun(text: "En images")]), .image(photo), .separator]
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.success(fullText(blocks))))

        await model.load()

        #expect(model.state == .loaded(fullText(blocks)))
        #expect(!model.fullTextDisplayed)
    }

    // MARK: Failure: excerpt, message, « Réessayer », « Ouvrir sur le site ↗ »

    // Unreadable: the page, the status, the host or any error that is not "no network".
    @Test(arguments: [
        ArticleContentError.unreadable as any Error,
        ArticleContentError.httpStatus(404),
        ArticleContentError.httpStatus(503),
        ArticleContentError.redirectedOffSite(URL(string: "https://login.example.com/")!),
        ArticleContentError.notSiteAddress(URL(string: "https://example.com/")!),
        URLError(.badServerResponse),
        CocoaError(.fileReadCorruptFile)
    ])
    func aPageThatCannotBeReadKeepsTheExcerptAndOffersTheSite(error: any Error) async {
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.failure(error)))

        await model.load()

        #expect(model.state == .failed(.unreadable))
        #expect(model.article.excerpt == feedArticle.excerpt)
        #expect(model.showsOpenOnSite)
        #expect(!model.fullTextDisplayed)
    }

    // Offline: the network codes of URLSession, and nothing else.
    @Test(arguments: [
        URLError.Code.notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost, .dataNotAllowed
    ])
    func noNetworkWithoutACopyKeepsTheExcerptWithoutSendingToTheSite(code: URLError.Code) async {
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.failure(URLError(code))))

        await model.load()

        #expect(model.state == .failed(.offline))
        #expect(model.article.excerpt == feedArticle.excerpt)
        #expect(!model.showsOpenOnSite)
        #expect(!model.fullTextDisplayed)
    }

    @Test func retryShowsLoadingAgainUntilTheAnswer() async throws {
        let source = GatedSource()
        let model = ArticleReaderModel(article: feedArticle, source: source)
        let first = Task { await model.load() }
        try #require(await source.waitForRequest(1))
        await source.answer(.failure(ArticleContentError.unreadable))
        await first.value
        try #require(model.state == .failed(.unreadable))

        let retrying = Task { await model.retry() }
        try #require(await source.waitForRequest(2))

        #expect(model.state == .loading)

        await source.answer(.success(fullText()))
        await retrying.value
    }

    @Test func openOnSiteIsHiddenWhileARetryLoadsAndBackIfItFails() async throws {
        let source = GatedSource()
        let model = ArticleReaderModel(article: feedArticle, source: source)
        let first = Task { await model.load() }
        try #require(await source.waitForRequest(1))
        await source.answer(.failure(ArticleContentError.httpStatus(500)))
        await first.value
        try #require(model.showsOpenOnSite)

        let retrying = Task { await model.retry() }
        try #require(await source.waitForRequest(2))

        #expect(!model.showsOpenOnSite)

        await source.answer(.failure(ArticleContentError.unreadable))
        await retrying.value

        #expect(model.state == .failed(.unreadable))
        #expect(model.showsOpenOnSite)
    }

    @Test func aSuccessfulRetryClearsTheFailure() async {
        let source = ScriptedSource(.failure(ArticleContentError.unreadable), .success(fullText()))
        let model = ArticleReaderModel(article: feedArticle, source: source)
        await model.load()

        await model.retry()

        #expect(model.state == .loaded(fullText()))
        #expect(!model.showsOpenOnSite)
        #expect(model.fullTextDisplayed)
        #expect(await source.requested == [feedArticle.link, feedArticle.link])
    }

    @Test func aFailedRetryShowsTheNewFailure() async {
        let source = ScriptedSource(.failure(offline), .failure(ArticleContentError.unreadable))
        let model = ArticleReaderModel(article: feedArticle, source: source)
        await model.load()

        await model.retry()

        #expect(model.state == .failed(.unreadable))
        #expect(model.showsOpenOnSite)
    }

    // MARK: Offline copy (through the protocol)

    @Test func offlineWithACopyShowsTheCopy() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ArticleReaderModelTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let online = CachedArticleContentSource(wrapping: ScriptedSource(.success(fullText())), directory: directory)
        await ArticleReaderModel(article: feedArticle, source: online).load()

        // maxAge 0: the copy is old, the source is asked and is offline.
        let cached = CachedArticleContentSource(
            wrapping: ScriptedSource(.failure(offline)), directory: directory, maxAge: 0)
        let model = ArticleReaderModel(article: feedArticle, source: cached)
        await model.load()

        #expect(model.state == .loaded(fullText()))
        #expect(model.fullTextDisplayed)
        #expect(!model.showsOpenOnSite)
    }

    // MARK: Links in the text (SiteLink)

    @Test(arguments: [
        ("https://esprit-festivalier.fr/superbus-deux-heures-10612/",
         ReaderDestination.article(URL(string: "https://esprit-festivalier.fr/superbus-deux-heures-10612/")!)),
        ("https://esprit-festivalier.fr/festival/terres-du-son/", .festival(slug: "terres-du-son")),
        // http:// and www. addresses of the site are the site.
        ("http://www.esprit-festivalier.fr/festival/x/", .festival(slug: "x")),
        ("http://www.esprit-festivalier.fr/author/mano-le-bris/", .author(slug: "mano-le-bris")),
        ("https://esprit-festivalier.fr/author/mano-le-bris/", .author(slug: "mano-le-bris")),
        ("https://esprit-festivalier.fr/artiste/orelsan/", .artist(slug: "orelsan")),
        ("https://esprit-festivalier.fr/category/live-report/", .category(slug: "live-report")),
        ("https://esprit-festivalier.fr/tag/concert/", .tag(slug: "concert")),
        ("https://esprit-festivalier.fr/recrutements/",
         .external(URL(string: "https://esprit-festivalier.fr/recrutements/")!)),
        ("https://www.youtube.com/watch?v=abc", .external(URL(string: "https://www.youtube.com/watch?v=abc")!)),
        // Mail and Phone, never the Safari sheet (it only takes http and https).
        ("mailto:redaction@esprit-festivalier.fr",
         .system(URL(string: "mailto:redaction@esprit-festivalier.fr")!)),
        ("tel:+33600000000", .system(URL(string: "tel:+33600000000")!)),
        ("javascript:alert(1)", .ignored),
        ("file:///etc/passwd", .ignored),
        ("data:text/plain,x", .ignored)
    ])
    func aLinkInTheTextOpensWhereItBelongs(address: String, expected: ReaderDestination) throws {
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.success(fullText())))
        let url = try #require(URL(string: address))

        #expect(model.destination(for: url) == expected)
    }

    // Review of PR #26: « Lire aussi » goes through `destination(for:)` like any link; the editor can
    // point it to a festival or another site, not only to an article.
    @Test(arguments: [
        ("/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673/",
         ReaderDestination.article(site("/superbus-pres-de-deux-heures-de-tubes-a-l-accor-arena-10673/"))),
        ("/festival/hellfest/", .festival(slug: "hellfest")),
        ("/artiste/orelsan/", .artist(slug: "orelsan")),
        ("https://www.youtube.com/watch?v=abc", .external(URL(string: "https://www.youtube.com/watch?v=abc")!))
    ])
    func readAlsoOpensWhereItsLinkBelongs(href: String, expected: ReaderDestination) async throws {
        let page = ArticlePage.page(body: """
            <p>Texte.</p><aside class="read-also"><span>Lire aussi</span><a href="\(href)">À lire</a></aside>
            """)
        let content = try await readArticle(page)
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.success(content)))
        await model.load()
        let summary = try #require(content.blocks.compactMap { block -> ArticleSummary? in
            if case let .readAlso(summary) = block { summary } else { nil }
        }.first)

        #expect(model.destination(for: summary.url) == expected)
    }

    // MARK: Leaving the screen

    @Test(arguments: [CancellationError() as any Error, URLError(.cancelled)])
    func leavingTheScreenWhileLoadingIsNotAFailure(cancellation: any Error) async throws {
        let source = GatedSource(cancellationError: cancellation)
        let model = ArticleReaderModel(article: feedArticle, source: source)
        let loading = Task { await model.load() }
        try #require(await source.waitForRequest(1))

        loading.cancel()
        await loading.value

        #expect(model.state == .loading)
        #expect(!model.showsOpenOnSite)
    }

    @Test func comingBackAfterLeavingReadsTheArticle() async throws {
        let source = GatedSource()
        let model = ArticleReaderModel(article: feedArticle, source: source)
        let left = Task { await model.load() }
        try #require(await source.waitForRequest(1))
        left.cancel()
        await left.value

        let back = Task { await model.load() }
        try #require(await source.waitForRequest(2))
        await source.answer(.success(fullText()))
        await back.value

        #expect(model.state == .loaded(fullText()))
    }

    // Review of PR #26: URLSession also throws `URLError(.cancelled)` when the session is invalidated
    // while the screen is still open. That is a failure the reader can retry, never an endless loading.
    @Test func aCancelledRequestWhileTheScreenIsOpenIsAFailureNotAnEndlessLoading() async {
        let model = ArticleReaderModel(article: feedArticle, source: ScriptedSource(.failure(URLError(.cancelled))))

        await model.load()

        #expect(model.state == .failed(.unreadable))
        #expect(model.article.excerpt == feedArticle.excerpt)
        #expect(model.showsOpenOnSite)
        #expect(!model.fullTextDisplayed)
    }

    @Test func aCancelledRequestWhileTheScreenIsOpenCanBeRetried() async {
        let source = ScriptedSource(.failure(URLError(.cancelled)), .success(fullText()))
        let model = ArticleReaderModel(article: feedArticle, source: source)
        await model.load()

        await model.retry()

        #expect(model.state == .loaded(fullText()))
        #expect(model.fullTextDisplayed)
        #expect(await source.requested == [feedArticle.link, feedArticle.link])
    }
}
