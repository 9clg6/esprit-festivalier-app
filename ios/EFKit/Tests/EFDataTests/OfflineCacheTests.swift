import Foundation
import Testing
import EFDomain
import EFData

// STORY-008 "Fiches favorites hors ligne" (NFR-003; architecture: favorite sheets and their images
// copied to Application Support, not Caches). Helper `temporaryDirectory` in FavoritesStoreTests.swift.
// Assumed API (EFData):
//   actor OfflineCache {
//     init(directory: URL, fetchImage: @escaping @Sendable (URL) async throws -> Data)
//     func save(_ detail: FestivalDetail) async throws     // on favorite
//     func remove(_ id: Festival.ID) throws                // on unfavorite
//     func detail(_ id: Festival.ID) -> FestivalDetail?
//     func imageData(_ id: Festival.ID) -> Data?
//     func isAvailableOffline(_ id: Festival.ID) -> Bool   // "Disponible hors ligne"
//     func festival(id: Festival.ID, from source: any FestivalSource) async throws -> FestivalDetail
//   }
// Decisions specified here:
// - save stores the detail and the bytes of `festival.imageURL` (fetched once, through the closure);
//   no image URL -> no fetch, no image; an image that cannot be fetched does not lose the sheet;
// - everything survives a new instance on the same directory, with no fetch on read;
// - remove deletes the sheet and its image from disk; removing an unknown id is fine;
// - `festival(id:from:)`: the source answers -> its detail, and the stored copy of a saved festival is
//   refreshed; the source fails -> the stored copy; nothing stored -> the source's error;
//   a festival that was never saved is not stored by reading it.

private func date(_ iso: String) -> Date {
    try! Date(iso, strategy: .iso8601)
}

private func sheet(_ id: Festival.ID, image: URL? = URL(string: "https://example.org/poster.jpg"),
                   summary: String = "À propos") -> FestivalDetail {
    let festival = Festival(
        id: id, name: "Festival \(id)", city: "Clisson", latitude: 47.09, longitude: -1.27,
        startDate: date("2027-06-17T00:00:00+02:00"), endDate: date("2027-06-20T23:59:00+02:00"),
        website: URL(string: "https://example.org")!, description: "Démo", imageURL: image
    )
    let stage = Stage(id: "\(id)-main", festivalId: id, name: "Mainstage 1")
    let performance = Performance(
        id: "\(id)-act", festivalId: id, stageId: stage.id, artistId: "act",
        start: date("2027-06-17T18:00:00+02:00"), end: date("2027-06-17T19:15:00+02:00")
    )
    return FestivalDetail(
        festival: festival, stages: [stage], performances: [performance], summary: summary,
        practicalInfo: [PracticalInfo(title: "Navettes", text: "Depuis Nantes")]
    )
}

/// Records the image URLs asked for; answers with fixed bytes, or fails.
private final class ImageServer: @unchecked Sendable {
    private let lock = NSLock()
    private var requested: [URL] = []
    private let failing: Bool
    let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x01, 0x02])

    init(failing: Bool = false) { self.failing = failing }

    var requests: [URL] { lock.withLock { requested } }

    func fetch(_ url: URL) throws -> Data {
        lock.withLock { requested.append(url) }
        if failing { throw URLError(.notConnectedToInternet) }
        return bytes
    }
}

private struct OnlineSource: FestivalSource {
    let detail: FestivalDetail
    func festivals(updatedSince: Date?) async throws -> [Festival] { [detail.festival] }
    func festival(id: Festival.ID) async throws -> FestivalDetail { detail }
}

private struct OfflineSource: FestivalSource {
    func festivals(updatedSince: Date?) async throws -> [Festival] { throw URLError(.notConnectedToInternet) }
    func festival(id: Festival.ID) async throws -> FestivalDetail { throw URLError(.notConnectedToInternet) }
}

private func makeCache(in directory: URL, images: ImageServer = ImageServer()) -> OfflineCache {
    OfflineCache(directory: directory, fetchImage: { try images.fetch($0) })
}

private func storedFiles(in directory: URL) -> [URL] {
    let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])
    return (enumerator?.allObjects as? [URL] ?? []).filter {
        (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}

@Suite struct OfflineCacheSaveTests {
    @Test func anUnsavedFestivalIsNotAvailableOffline() async {
        let cache = makeCache(in: temporaryDirectory())

        #expect(await cache.detail("hellfest") == nil)
        #expect(await cache.imageData("hellfest") == nil)
        #expect(await !cache.isAvailableOffline("hellfest"))
    }

    @Test func aSavedFavoriteKeepsItsWholeSheetAndItsImage() async throws {
        let images = ImageServer()
        let cache = makeCache(in: temporaryDirectory(), images: images)

        try await cache.save(sheet("hellfest"))

        #expect(await cache.detail("hellfest") == sheet("hellfest"))
        #expect(await cache.imageData("hellfest") == images.bytes)
        #expect(await cache.isAvailableOffline("hellfest"))
        #expect(images.requests == [URL(string: "https://example.org/poster.jpg")!])
    }

    @Test func aFestivalWithoutImageIsSavedWithoutFetching() async throws {
        let images = ImageServer()
        let cache = makeCache(in: temporaryDirectory(), images: images)

        try await cache.save(sheet("hellfest", image: nil))

        #expect(await cache.detail("hellfest") == sheet("hellfest", image: nil))
        #expect(await cache.imageData("hellfest") == nil)
        #expect(images.requests.isEmpty)
    }

    @Test func anImageThatCannotBeFetchedDoesNotLoseTheSheet() async throws {
        let cache = makeCache(in: temporaryDirectory(), images: ImageServer(failing: true))

        try await cache.save(sheet("hellfest"))

        #expect(await cache.detail("hellfest") == sheet("hellfest"))
        #expect(await cache.imageData("hellfest") == nil)
        #expect(await cache.isAvailableOffline("hellfest"))
    }

    @Test func savedFestivalsStayApart() async throws {
        let cache = makeCache(in: temporaryDirectory())

        try await cache.save(sheet("hellfest", summary: "Metal"))
        try await cache.save(sheet("trans-musicales", summary: "Découvertes"))

        #expect(await cache.detail("hellfest")?.summary == "Metal")
        #expect(await cache.detail("trans-musicales")?.summary == "Découvertes")
    }

    @Test func savingAgainReplacesTheSheet() async throws {
        let cache = makeCache(in: temporaryDirectory())
        try await cache.save(sheet("hellfest", summary: "Ancien"))

        try await cache.save(sheet("hellfest", summary: "Nouveau"))

        #expect(await cache.detail("hellfest")?.summary == "Nouveau")
    }

    @Test func theSheetAndImageSurviveANewInstanceWithoutNetwork() async throws {
        let directory = temporaryDirectory()
        let images = ImageServer()
        try await makeCache(in: directory, images: images).save(sheet("hellfest"))
        let offline = ImageServer(failing: true)

        let reopened = makeCache(in: directory, images: offline)

        #expect(await reopened.detail("hellfest") == sheet("hellfest"))
        #expect(await reopened.imageData("hellfest") == images.bytes)
        #expect(await reopened.isAvailableOffline("hellfest"))
        #expect(offline.requests.isEmpty)
    }
}

@Suite struct OfflineCacheRemoveTests {
    @Test func anUnfavoritedFestivalIsNoLongerAvailableOffline() async throws {
        let directory = temporaryDirectory()
        let cache = makeCache(in: directory)
        try await cache.save(sheet("hellfest"))

        try await cache.remove("hellfest")

        #expect(await cache.detail("hellfest") == nil)
        #expect(await cache.imageData("hellfest") == nil)
        #expect(await !cache.isAvailableOffline("hellfest"))
        #expect(await makeCache(in: directory).detail("hellfest") == nil)
    }

    @Test func removingFreesTheDisk() async throws {
        let directory = temporaryDirectory()
        let cache = makeCache(in: directory)
        try await cache.save(sheet("hellfest"))
        #expect(!storedFiles(in: directory).isEmpty)

        try await cache.remove("hellfest")

        #expect(storedFiles(in: directory).isEmpty)
    }

    @Test func removingOneFestivalKeepsTheOthers() async throws {
        let cache = makeCache(in: temporaryDirectory())
        try await cache.save(sheet("hellfest"))
        try await cache.save(sheet("trans-musicales"))

        try await cache.remove("hellfest")

        #expect(await cache.detail("trans-musicales") == sheet("trans-musicales"))
        #expect(await cache.imageData("trans-musicales") != nil)
    }

    @Test func removingAnUnknownFestivalIsFine() async throws {
        try await makeCache(in: temporaryDirectory()).remove("never-saved")
    }
}

@Suite struct OfflineCacheFallbackTests {
    @Test func theSourceAnswerIsShownWhenOnline() async throws {
        let cache = makeCache(in: temporaryDirectory())
        try await cache.save(sheet("hellfest", summary: "Ancien"))

        let shown = try await cache.festival(id: "hellfest", from: OnlineSource(detail: sheet("hellfest", summary: "Neuf")))

        #expect(shown.summary == "Neuf")
    }

    @Test func theStoredSheetIsShownWhenTheSourceFails() async throws {
        let cache = makeCache(in: temporaryDirectory())
        try await cache.save(sheet("hellfest"))

        let shown = try await cache.festival(id: "hellfest", from: OfflineSource())

        #expect(shown == sheet("hellfest"))
    }

    @Test func aFreshAnswerRefreshesTheStoredCopyOfAFavorite() async throws {
        let directory = temporaryDirectory()
        let cache = makeCache(in: directory)
        try await cache.save(sheet("hellfest", summary: "Ancien"))

        _ = try await cache.festival(id: "hellfest", from: OnlineSource(detail: sheet("hellfest", summary: "Neuf")))

        #expect(try await makeCache(in: directory).festival(id: "hellfest", from: OfflineSource()).summary == "Neuf")
    }

    @Test func withoutAStoredSheetTheSourceErrorComesThrough() async {
        let cache = makeCache(in: temporaryDirectory())

        await #expect(throws: URLError.self) {
            try await cache.festival(id: "hellfest", from: OfflineSource())
        }
    }

    @Test func readingANonFavoriteDoesNotStoreIt() async throws {
        let cache = makeCache(in: temporaryDirectory())

        _ = try await cache.festival(id: "hellfest", from: OnlineSource(detail: sheet("hellfest")))

        #expect(await !cache.isAvailableOffline("hellfest"))
        #expect(await cache.detail("hellfest") == nil)
    }

    @Test func anUnfavoritedFestivalFailsOfflineAgain() async throws {
        let cache = makeCache(in: temporaryDirectory())
        try await cache.save(sheet("hellfest"))
        try await cache.remove("hellfest")

        await #expect(throws: URLError.self) {
            try await cache.festival(id: "hellfest", from: OfflineSource())
        }
    }

    @Test func aDemoFavoriteOpensOfflineWithItsImage() async throws {
        let demo = try await MockFestivalSource().festival(id: "hellfest")
        let images = ImageServer()
        let cache = makeCache(in: temporaryDirectory(), images: images)
        try await cache.save(demo)

        #expect(try await cache.festival(id: "hellfest", from: OfflineSource()) == demo)
        #expect(await cache.imageData("hellfest") == images.bytes)
        #expect(images.requests == [try #require(demo.festival.imageURL)])
    }
}
