import Foundation
import Testing
import EFDomain
import EFData

// STORY-022 "Connexion et Profil" in mock-first mode: no server, no Better Auth yet (STORY-021).
// FR-007 (compte Apple ou e-mail, suppression depuis l'app), UX P6 / E12 / E13, NFR-008 (the mock is
// swapped later for the Better Auth client without touching the screens).
// Helper `temporaryDirectory` in FavoritesStoreTests.swift.
// Assumed API:
//   EFDomain:
//     struct AuthSession: Sendable, Codable, Hashable {
//       enum Provider: String, Codable, Sendable { case apple, email }
//       userId: String; provider: Provider; email: String? (nil for Apple); createdAt: Date
//       public init(userId:provider:email:createdAt:)
//     }
//     enum AuthError: Error, Equatable { case invalidAppleToken, invalidEmail, wrongCode }
//     protocol AuthService: Sendable {
//       var session: AuthSession? { get async }
//       func signInWithApple(identityToken: String) async throws -> AuthSession
//       func sendEmailCode(to email: String) async throws
//       func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession
//       func signOut() async throws
//       func deleteAccount() async throws
//     }
//   EFData:
//     MockAuthService: AuthService (actor or Sendable class)
//       init(directory: URL, userDataDirectories: [URL] = [], now: @escaping @Sendable () -> Date = { Date() })
//     `directory` holds the fake session file; `userDataDirectories` are the folders whose content
//     deleteAccount erases (in the app: the favorites/picks folder and the Offline folder).
// Decisions specified here:
// - signed out at first; any non-empty Apple token signs in (provider apple, no email); empty -> invalidAppleToken;
// - sendEmailCode: simple rules, one "@", a "." in the domain, no space; else invalidEmail; it does not sign in;
// - verifyEmailCode: only the demo code "000000" signs in (provider email, the given email); else wrongCode;
// - the session survives a new instance on the same directory; signOut clears it, keeps the local data;
// - deleteAccount clears the session and erases the content of the given directories, nothing else;
// - signOut and deleteAccount twice do not throw.

private let demoCode = "000000"
private let signInDate = try! Date("2026-11-25T09:30:00Z", strategy: .iso8601)

private func makeAuth(in directory: URL, userData: [URL] = []) -> MockAuthService {
    MockAuthService(directory: directory, userDataDirectories: userData, now: { signInDate })
}

private func contents(of directory: URL) -> [String] {
    (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
}

@Suite struct MockAuthServiceSignInTests {
    @Test func theMockIsAnAuthService() {
        let service: any AuthService = makeAuth(in: temporaryDirectory())
        _ = service
    }

    @Test func aNewServiceIsSignedOut() async {
        #expect(await makeAuth(in: temporaryDirectory()).session == nil)
    }

    @Test func anyAppleTokenSignsIn() async throws {
        let auth = makeAuth(in: temporaryDirectory())

        let session = try await auth.signInWithApple(identityToken: "any-identity-token")

        #expect(session.provider == .apple)
        #expect(session.email == nil)
        #expect(!session.userId.isEmpty)
        #expect(session.createdAt == signInDate)
        #expect(await auth.session == session)
    }

    @Test func anEmptyAppleTokenIsRefused() async {
        let auth = makeAuth(in: temporaryDirectory())

        await #expect(throws: AuthError.invalidAppleToken) {
            try await auth.signInWithApple(identityToken: "")
        }
        #expect(await auth.session == nil)
    }
}

@Suite struct MockAuthServiceEmailTests {
    @Test(arguments: ["fan@example.org", "prenom.nom@esprit-festivalier.fr", "a@b.co"])
    func aWellFormedEmailGetsACode(email: String) async throws {
        let auth = makeAuth(in: temporaryDirectory())

        try await auth.sendEmailCode(to: email)

        #expect(await auth.session == nil, "sending a code must not sign in")
    }

    @Test(arguments: [
        "", "fanexample.org", "fan@@example.org", "fan@exa@mple.org", "fan@example",
        "fan @example.org", "fan@example .org", "fan@exam\tple.org"
    ])
    func aMalformedEmailIsRefused(email: String) async {
        let auth = makeAuth(in: temporaryDirectory())

        await #expect(throws: AuthError.invalidEmail) {
            try await auth.sendEmailCode(to: email)
        }
    }

    @Test func theDemoCodeSignsInWithThatEmail() async throws {
        let auth = makeAuth(in: temporaryDirectory())
        try await auth.sendEmailCode(to: "fan@example.org")

        let session = try await auth.verifyEmailCode(demoCode, email: "fan@example.org")

        #expect(session.provider == .email)
        #expect(session.email == "fan@example.org")
        #expect(!session.userId.isEmpty)
        #expect(session.createdAt == signInDate)
        #expect(await auth.session == session)
    }

    @Test(arguments: ["123456", "000001", "00000", "0000000", ""])
    func anyOtherCodeIsWrongAndKeepsTheUserSignedOut(code: String) async throws {
        let auth = makeAuth(in: temporaryDirectory())
        try await auth.sendEmailCode(to: "fan@example.org")

        await #expect(throws: AuthError.wrongCode) {
            try await auth.verifyEmailCode(code, email: "fan@example.org")
        }
        #expect(await auth.session == nil)
    }

    @Test func aWrongCodeCanBeFollowedByTheRightOne() async throws {
        let auth = makeAuth(in: temporaryDirectory())
        try await auth.sendEmailCode(to: "fan@example.org")
        _ = try? await auth.verifyEmailCode("123456", email: "fan@example.org")

        let session = try await auth.verifyEmailCode(demoCode, email: "fan@example.org")

        #expect(await auth.session == session)
    }
}

@Suite struct MockAuthServiceSessionTests {
    @Test func theSessionSurvivesANewInstance() async throws {
        let directory = temporaryDirectory()
        let session = try await makeAuth(in: directory).signInWithApple(identityToken: "token")

        #expect(await makeAuth(in: directory).session == session)
    }

    @Test func anEmailSessionSurvivesANewInstance() async throws {
        let directory = temporaryDirectory()
        let auth = makeAuth(in: directory)
        try await auth.sendEmailCode(to: "fan@example.org")
        let session = try await auth.verifyEmailCode(demoCode, email: "fan@example.org")

        #expect(await makeAuth(in: directory).session == session)
    }

    @Test func signOutClearsTheSessionForGood() async throws {
        let directory = temporaryDirectory()
        let auth = makeAuth(in: directory)
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.signOut()

        #expect(await auth.session == nil)
        #expect(await makeAuth(in: directory).session == nil)
    }

    @Test func signOutKeepsTheLocalFavoritesAndPicks() async throws {
        let data = temporaryDirectory()
        try await FavoritesStore(directory: data).add("hellfest")
        try await PicksStore(directory: data).setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        let auth = makeAuth(in: temporaryDirectory(), userData: [data])
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.signOut()

        #expect(await FavoritesStore(directory: data).favoriteIDs == ["hellfest"])
        #expect(await PicksStore(directory: data).pickedIDs == ["hellfest-iron-maiden"])
    }

    @Test func signOutTwiceIsFine() async throws {
        let auth = makeAuth(in: temporaryDirectory())
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.signOut()
        try await auth.signOut()

        #expect(await auth.session == nil)
    }

    @Test func signOutWhenSignedOutIsFine() async throws {
        let auth = makeAuth(in: temporaryDirectory())

        try await auth.signOut()

        #expect(await auth.session == nil)
    }
}

@Suite struct MockAuthServiceDeleteAccountTests {
    @Test func deleteAccountClearsTheSessionForGood() async throws {
        let directory = temporaryDirectory()
        let auth = makeAuth(in: directory)
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.deleteAccount()

        #expect(await auth.session == nil)
        #expect(await makeAuth(in: directory).session == nil)
    }

    @Test func deleteAccountErasesFavoritesPicksAndOfflineSheets() async throws {
        let data = temporaryDirectory()
        let offline = data.appending(path: "Offline")
        try await FavoritesStore(directory: data).add("hellfest")
        try await PicksStore(directory: data).setPicked("hellfest-iron-maiden", true, festivalId: "hellfest")
        try FileManager.default.createDirectory(at: offline, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: offline.appending(path: "hellfest.json"))
        try Data([0xFF, 0xD8]).write(to: offline.appending(path: "hellfest.image"))
        let auth = makeAuth(in: temporaryDirectory(), userData: [data, offline])
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.deleteAccount()

        #expect(await FavoritesStore(directory: data).entries.isEmpty, "no favorite, no tombstone")
        #expect(await PicksStore(directory: data).entries.isEmpty, "no pick, no tombstone")
        #expect(contents(of: offline).isEmpty)
        #expect(await OfflineCache(directory: offline, fetchImage: { _ in Data() }).storedFestivals().isEmpty)
    }

    @Test func deleteAccountLeavesDataItWasNotGiven() async throws {
        let given = temporaryDirectory()
        let other = temporaryDirectory()
        try await FavoritesStore(directory: given).add("hellfest")
        try await FavoritesStore(directory: other).add("vieilles-charrues")
        let auth = makeAuth(in: temporaryDirectory(), userData: [given])
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.deleteAccount()

        #expect(await FavoritesStore(directory: given).favoriteIDs.isEmpty)
        #expect(await FavoritesStore(directory: other).favoriteIDs == ["vieilles-charrues"])
    }

    @Test func deleteAccountWithAMissingDataDirectoryIsFine() async throws {
        let missing = temporaryDirectory().appending(path: "never-created")
        let auth = makeAuth(in: temporaryDirectory(), userData: [missing])
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.deleteAccount()

        #expect(await auth.session == nil)
    }

    @Test func deleteAccountTwiceIsFine() async throws {
        let data = temporaryDirectory()
        try await FavoritesStore(directory: data).add("hellfest")
        let auth = makeAuth(in: temporaryDirectory(), userData: [data])
        _ = try await auth.signInWithApple(identityToken: "token")

        try await auth.deleteAccount()
        try await auth.deleteAccount()

        #expect(await auth.session == nil)
        #expect(await FavoritesStore(directory: data).favoriteIDs.isEmpty)
    }
}
