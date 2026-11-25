import EFData
import EFDomain
import Foundation
import Observation

@MainActor @Observable
final class ArticlesModel {
    enum State {
        case loading
        case loaded([Article])
        case failed
    }

    /// Chip label (plural) and the category it shows; `nil` is "Tout".
    static let chips: [(label: String, category: Article.Category?)] = [
        ("Tout", nil), ("Live reports", .liveReport), ("Programmations", .programmation),
        ("Interviews", .interview), ("Actus", .actu), ("Guides", .guide),
        ("Décryptages", .decryptage), ("Chroniques", .chronique)
    ]

    private(set) var state = State.loading
    /// Set when the shown articles come from the copy kept on the device.
    private(set) var offlineSince: Date?
    var category: Article.Category?
    private let source: any ArticleSource
    private let feed: SiteFeed?

    init(source: any ArticleSource, feed: SiteFeed?) {
        self.source = source
        self.feed = feed
    }

    func load() async {
        do {
            state = .loaded(try await source.articles(category: nil))
            offlineSince = await feed?.offlineSince
        } catch is CancellationError {
            // A cancelled pull-to-refresh keeps what is shown.
        } catch {
            state = .failed
        }
    }

    var shown: [Article] {
        guard case .loaded(let articles) = state else { return [] }
        guard let category else { return articles }
        return articles.filter { $0.category == category }
    }
}
