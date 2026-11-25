import Foundation
import Testing
import EFDomain
import EFData

// Regression specs from the review of PR #15 (STORY-018). Helpers live in FavoritesStoreTests.swift.
//
// Bug 1, data loss: a `favorites.json` that exists, is not empty and cannot be decoded (corrupt
// bytes, or a file written by a future version) used to be overwritten by the next write.
// Rule: its bytes are kept, unchanged, in `favorites.corrupt.json` next to it, so they can be
// recovered; the store still starts empty and works. An empty file has nothing to keep.
// Forward compatibility: an entry with an unknown extra field still decodes.

private func writeFavoritesFile(_ bytes: Data, in directory: URL) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try bytes.write(to: directory.appending(path: "favorites.json"))
}

private func corruptCopy(in directory: URL) -> Data? {
    try? Data(contentsOf: directory.appending(path: "favorites.corrupt.json"))
}

@Suite struct FavoritesStoreRecoveryTests {
    @Test func corruptBytesAreKeptAsideBeforeTheFirstWrite() async throws {
        let directory = temporaryDirectory()
        let unreadable = Data("{ not json".utf8)
        try writeFavoritesFile(unreadable, in: directory)

        let store = makeStore(in: directory)
        #expect(await store.favoriteIDs.isEmpty)
        try await store.add("a")

        #expect(corruptCopy(in: directory) == unreadable)
        #expect(await makeStore(in: directory).favoriteIDs == ["a"])
    }

    @Test func aFileFromAFutureSchemaIsKeptAsideBeforeTheFirstWrite() async throws {
        let directory = temporaryDirectory()
        let future = Data("""
        {"version":2,"favorites":[{"festivalId":"hellfest","updatedAt":"2026-11-01T10:00:00Z","deleted":false}]}
        """.utf8)
        try writeFavoritesFile(future, in: directory)

        let store = makeStore(in: directory)
        #expect(await store.entries.isEmpty)
        try await store.add("a")

        #expect(corruptCopy(in: directory) == future)
        #expect(await store.favoriteIDs == ["a"])
    }

    @Test func anEmptyFileIsNotKeptAside() async throws {
        let directory = temporaryDirectory()
        try writeFavoritesFile(Data(), in: directory)

        try await makeStore(in: directory).add("a")

        #expect(corruptCopy(in: directory) == nil)
    }

    @Test func anEntryWithAnUnknownFieldStillDecodes() async throws {
        let directory = temporaryDirectory()
        try writeFavoritesFile(Data("""
        [{"festivalId":"hellfest","updatedAt":"2026-11-01T10:00:00Z","deleted":false,"syncedBy":"device-2"}]
        """.utf8), in: directory)

        let store = makeStore(in: directory)

        #expect(await store.favoriteIDs == ["hellfest"])
        #expect(corruptCopy(in: directory) == nil)
    }
}
