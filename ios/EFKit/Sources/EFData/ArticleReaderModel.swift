import EFDomain
import Foundation
import Observation

/// Where a link in an article opens (ADR-007 "Liens internes").
public enum ReaderDestination: Equatable, Sendable {
    /// E11 by address.
    case article(URL)
    case festival(slug: String), author(slug: String), artist(slug: String)
    case category(slug: String), tag(slug: String)
    /// Safari sheet: http and https only.
    case external(URL)
    /// `openURL`: Mail for `mailto:`, Phone for `tel:`.
    case system(URL)
    /// Never opened (`javascript:`, `file:`, `data:`…).
    case ignored
}

/// E11: the feed article at once, then its full text read through an `ArticleContentSource` (FR-027).
/// A failure keeps the excerpt; « Ouvrir sur le site » only after a page that cannot be read (ADR-007).
@MainActor @Observable
public final class ArticleReaderModel {
    public enum State: Equatable {
        case loading
        case loaded(ArticleContent)
        case failed(Failure)
    }

    public enum Failure: Equatable, Sendable {
        /// No network and no copy: « Article complet indisponible hors ligne ».
        case offline
        /// Any other failure: « Impossible d'afficher cet article dans l'app ».
        case unreadable
    }

    public let article: Article
    public private(set) var state = State.loading
    private let source: any ArticleContentSource
    private var activeEmbeds: Set<URL> = []

    public init(article: Article, source: any ArticleContentSource) {
        self.article = article
        self.source = source
    }

    public var showsOpenOnSite: Bool { state == .failed(.unreadable) }

    /// The full text is on screen: the signal read counting listens to (FR-036).
    public var fullTextDisplayed: Bool {
        guard case .loaded(let content) = state else { return false }
        return content.blocks.contains { if case .paragraph = $0 { true } else { false } }
    }

    public func load() async {
        do {
            state = .loaded(try await source.content(at: article.link))
        } catch {
            // Leaving the screen cancels the load: not a failure.
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            state = .failed(Self.offlineCodes.contains((error as? URLError)?.code) ? .offline : .unreadable)
        }
    }

    public func retry() async {
        state = .loading
        await load()
    }

    public func isEmbedActive(_ id: URL) -> Bool { activeEmbeds.contains(id) }

    public func activateEmbed(_ id: URL) { activeEmbeds.insert(id) }

    public func destination(for url: URL) -> ReaderDestination {
        switch SiteLink(url: url) {
        case .article: .article(SiteLink.site(url) ?? url)
        case .festival(let slug): .festival(slug: slug)
        case .author(let slug): .author(slug: slug)
        case .artist(let slug): .artist(slug: slug)
        case .category(let slug): .category(slug: slug)
        case .tag(let slug): .tag(slug: slug)
        case .page(let page): .external(page)
        case .external(let other): .external(other)
        case .mail(let address), .phone(let address): .system(address)
        case .unsupported: .ignored
        }
    }

    private static let offlineCodes: Set<URLError.Code?> = [
        .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
        .dataNotAllowed
    ]
}
