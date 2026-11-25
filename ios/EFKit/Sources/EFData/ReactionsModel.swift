import EFDomain
import Observation

/// The reaction bar's state (FR-030), like the favorites heart: a tap shows its target at once, the
/// writes reach the service one after the other in tap order, and a stale or failed write never undoes
/// a newer tap. A failed write says nothing (UX "Réactions : états"): the pill goes back to what is stored.
@MainActor @Observable
public final class ReactionsModel {
    private let article: ArticleKey
    private let service: any ReactionService
    /// What the service last said.
    private var stored: ReactionSummary?
    /// Taps whose write is not done yet, shown over `stored`; the last tap on a reaction wins.
    private var tapped: [Reaction: Bool] = [:]
    /// Bumped by each tap on a reaction: only its last tap's write clears the override.
    private var generation: [Reaction: Int] = [:]
    /// The last service call: each one waits for it, so they run in order.
    private var queue: Task<Void, Never>?

    public init(article: ArticleKey, service: any ReactionService) {
        self.article = article
        self.service = service
    }

    /// nil until loaded (and no tap yet). Demo counts move with my taps.
    public var summary: ReactionSummary? {
        guard stored != nil || !tapped.isEmpty else { return nil }
        let base = stored ?? ReactionSummary(mine: [], counts: nil, isDemo: false)
        var mine = base.mine
        var counts = base.counts
        for (reaction, active) in tapped where active != base.mine.contains(reaction) {
            if active { mine.insert(reaction) } else { mine.remove(reaction) }
            if let count = counts?[reaction] { counts?[reaction] = max(0, count + (active ? 1 : -1)) }
        }
        return ReactionSummary(mine: mine, counts: counts, isDemo: base.isDemo)
    }

    /// Queued like a write, so an older read never replaces a newer write's result.
    public func load() async {
        await enqueue { [self] in
            if let loaded = try? await service.summary(for: article) { stored = loaded }
        }.value
    }

    /// Applies the target at once; the returned task ends when this tap's write is done.
    @discardableResult
    public func toggle(_ reaction: Reaction) -> Task<Void, Never> {
        let target = !(summary?.mine.contains(reaction) ?? false)
        let token = (generation[reaction] ?? 0) + 1
        generation[reaction] = token
        tapped[reaction] = target
        return enqueue { [self] in
            do {
                stored = try await service.set(reaction, active: target, on: article)
            } catch {
                stored = (try? await service.summary(for: article)) ?? stored
            }
            if generation[reaction] == token { tapped[reaction] = nil }
        }
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = queue
        let next = Task {
            await previous?.value
            await work()
        }
        queue = next
        return next
    }
}
