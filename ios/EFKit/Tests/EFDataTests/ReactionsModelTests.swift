import Foundation
import Testing
import EFDomain
import EFData

// Review of PR #24 (Opus), finding 1: a quick double tap on the same pill did not remove the reaction.
// `ReactionBar` decided the target from `summary`, which only changed after the disk write, so both taps
// wrote "active". Need, like the favorites heart (`FavoritesModel.toggle`, app target): the tap applies
// the target state at once, the writes reach the service in tap order, and a failed or stale write never
// undoes a newer tap. A failed write says nothing (UX "Réactions : états"): the pill goes back to what is
// stored. `FavoritesModel` lives in the app target, which has no test target, so its toggle has no spec;
// the reactions state moves to EFData (next to `LocalReactionService`, the stateful layer of EFKit; EFDomain
// keeps values and pure rules) where it can be tested against a scripted `ReactionService`.
// Assumed API (EFData):
//   @MainActor @Observable public final class ReactionsModel {
//     public init(article: ArticleKey, service: any ReactionService)   // ADR-007 key, not the URL
//     public private(set) var summary: ReactionSummary?   // nil until loaded; what the bar shows
//     public func load() async
//     /// Applies the target at once; the returned task ends when this tap's write is done.
//     @discardableResult public func toggle(_ reaction: Reaction) -> Task<Void, Never>
//   }

private let article = ArticleKey(rawValue: "10675")

/// A reaction service whose writes the test lets through, holds or fails, counted in arrival order.
private actor ScriptedReactionService: ReactionService {
    struct Write: Equatable {
        let reaction: Reaction
        let active: Bool
    }

    struct Refused: Error {}

    private(set) var writes: [Write] = []
    private(set) var stored: Set<Reaction>
    private let held: Set<Int>
    private let failing: Set<Int>
    private var released: Set<Int> = []
    private var waiting: [Int: CheckedContinuation<Void, Never>] = [:]

    init(stored: Set<Reaction> = [], held: Set<Int> = [], failing: Set<Int> = []) {
        self.stored = stored
        self.held = held
        self.failing = failing
    }

    func summary(for article: ArticleKey) -> ReactionSummary {
        ReactionSummary(mine: stored, counts: nil, isDemo: false)
    }

    func set(_ reaction: Reaction, active: Bool, on article: ArticleKey) async throws -> ReactionSummary {
        let index = writes.count
        writes.append(Write(reaction: reaction, active: active))
        if held.contains(index), !released.contains(index) {
            await withCheckedContinuation { waiting[index] = $0 }
        }
        if failing.contains(index) { throw Refused() }
        if active { stored.insert(reaction) } else { stored.remove(reaction) }
        return summary(for: article)
    }

    /// Lets the write of this index go on, now or when it arrives.
    func release(_ index: Int) {
        released.insert(index)
        waiting.removeValue(forKey: index)?.resume()
    }
}

private func on(_ reaction: Reaction) -> ScriptedReactionService.Write { .init(reaction: reaction, active: true) }
private func off(_ reaction: Reaction) -> ScriptedReactionService.Write { .init(reaction: reaction, active: false) }

/// Waits (up to about a second) until the service has received `count` writes.
private func untilWrites(_ count: Int, on service: ScriptedReactionService) async {
    var tries = 0
    while await service.writes.count < count, tries < 1000 {
        tries += 1
        try? await Task.sleep(for: .milliseconds(1))
    }
}

@MainActor
private func loadedModel(_ service: ScriptedReactionService) async -> ReactionsModel {
    let model = ReactionsModel(article: article, service: service)
    await model.load()
    return model
}

@MainActor
private func mine(_ model: ReactionsModel) -> Set<Reaction> { model.summary?.mine ?? [] }

@MainActor @Suite struct ReactionsModelTests {
    @Test func loadingShowsTheStoredReactions() async {
        let model = await loadedModel(ScriptedReactionService(stored: [.fire]))

        #expect(mine(model) == [.fire])
    }

    @Test func aTapShowsTheReactionAsMineBeforeTheWriteEnds() async {
        let service = ScriptedReactionService(held: [0])
        let model = await loadedModel(service)

        let write = model.toggle(.love)

        #expect(mine(model) == [.love])
        await service.release(0)
        await write.value
        #expect(mine(model) == [.love])
        #expect(await service.stored == [.love])
    }

    @Test func aQuickDoubleTapRemovesTheReaction() async {
        let service = ScriptedReactionService()
        let model = await loadedModel(service)

        let first = model.toggle(.love)
        let second = model.toggle(.love)

        #expect(mine(model).isEmpty, "the second tap undoes the first at once")
        await first.value
        await second.value
        #expect(await service.writes == [on(.love), off(.love)])
        #expect(await service.stored.isEmpty)
        #expect(mine(model).isEmpty)
    }

    @Test func aTapOnAStoredReactionRemovesIt() async {
        let service = ScriptedReactionService(stored: [.clap])
        let model = await loadedModel(service)

        await model.toggle(.clap).value

        #expect(await service.writes == [off(.clap)])
        #expect(mine(model).isEmpty)
    }

    @Test func writesReachTheServiceInTapOrder() async {
        let service = ScriptedReactionService(held: [0])
        let model = await loadedModel(service)

        let first = model.toggle(.love)
        let second = model.toggle(.love)
        await untilWrites(1, on: service)
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await service.writes == [on(.love)], "the second write waits for the first")
        await service.release(0)
        await first.value
        await second.value
        #expect(await service.writes == [on(.love), off(.love)])
        #expect(await service.stored.isEmpty)
    }

    @Test func aStaleWriteDoesNotUndoANewerTap() async {
        let service = ScriptedReactionService(held: [0, 1])
        let model = await loadedModel(service)
        let first = model.toggle(.love)
        let second = model.toggle(.love)

        await service.release(0)
        await first.value

        #expect(mine(model).isEmpty, "the first write's result (love on) is older than the second tap")
        await service.release(1)
        await second.value
        #expect(mine(model).isEmpty)
        #expect(await service.stored.isEmpty)
    }

    @Test func aWriteOnOneReactionDoesNotUndoATapOnAnother() async {
        let service = ScriptedReactionService(held: [0, 1])
        let model = await loadedModel(service)
        let love = model.toggle(.love)
        let fire = model.toggle(.fire)

        await service.release(0)
        await love.value

        #expect(mine(model) == [.love, .fire], "love's write returned before fire was stored")
        await service.release(1)
        await fire.value
        #expect(mine(model) == [.love, .fire])
        #expect(await service.stored == [.love, .fire])
    }

    @Test func aFailedWriteShowsWhatIsStored() async {
        let service = ScriptedReactionService(failing: [0])
        let model = await loadedModel(service)

        let write = model.toggle(.love)
        #expect(mine(model) == [.love])
        await write.value

        #expect(mine(model).isEmpty)
        #expect(await service.stored.isEmpty)
    }

    @Test func aFailedWriteDoesNotUndoANewerTap() async {
        let service = ScriptedReactionService(held: [1], failing: [0])
        let model = await loadedModel(service)
        let first = model.toggle(.love)   // on, fails
        _ = model.toggle(.love)           // off, held
        let third = model.toggle(.love)   // on

        await first.value

        #expect(mine(model) == [.love], "the last tap is on: the failure of the first does not put it back off")
        await service.release(1)
        await third.value
        #expect(await service.writes == [on(.love), off(.love), on(.love)])
        #expect(await service.stored == [.love])
        #expect(mine(model) == [.love])
    }

    // Review of PR #24 (Opus): the bar of the same article opened from another address (new slug,
    // tracking query, http) shows the reactions made from the first one (ADR-007 key).
    @Test func theSameArticleOpenedFromAnotherAddressShowsMyReaction() async throws {
        let service = LocalReactionService(directory: temporaryDirectory())
        let first = try #require(
            ArticleKey(numbered: URL(string: "https://esprit-festivalier.fr/ancien-titre-10675/")!)
        )
        let again = try #require(
            ArticleKey(numbered: URL(string: "http://esprit-festivalier.fr/nouveau-titre-10675/?utm_source=rss")!)
        )
        await ReactionsModel(article: first, service: service).toggle(.fire).value

        let reopened = ReactionsModel(article: again, service: service)
        await reopened.load()

        #expect(mine(reopened) == [.fire])
    }
}
