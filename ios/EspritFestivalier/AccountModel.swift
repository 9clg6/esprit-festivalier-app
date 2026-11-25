import CoreTransferable
import EFData
import EFDomain
import Foundation
import Observation
import UniformTypeIdentifiers

/// The account shown in Profil and the E13 sheet (STORY-022), and the data export (STORY-032).
@MainActor @Observable
final class AccountModel {
    private(set) var session: AuthSession?
    /// nil until the first answer of the sync service.
    private(set) var syncStatus: SyncStatus?
    private let auth: any AuthService
    private let sync: any SyncService
    private let favorites: FavoritesModel
    private let picks: PicksModel

    init(auth: any AuthService, sync: any SyncService, favorites: FavoritesModel, picks: PicksModel) {
        self.auth = auth
        self.sync = sync
        self.favorites = favorites
        self.picks = picks
    }

    func load() async {
        #if DEBUG
        // Debug builds only: `-seedSession apple` or `-seedSession fan@example.org` (screenshots).
        if await auth.session == nil, let seed = UserDefaults.standard.string(forKey: "seedSession") {
            if seed == "apple" {
                _ = try? await auth.signInWithApple(
                    AppleCredential(idToken: "debug-seed", nonce: "debug", authorizationCode: nil)
                )
            } else {
                _ = try? await auth.verifyEmailCode(MockAuthService.demoCode, email: seed)
            }
        }
        #endif
        session = await auth.session
        syncStatus = try? await sync.sync()
    }

    func signInWithApple(_ credential: AppleCredential) async throws {
        session = try await auth.signInWithApple(credential)
    }

    func sendEmailCode(to email: String) async throws {
        try await auth.sendEmailCode(to: email)
    }

    func verifyEmailCode(_ code: String, email: String) async throws {
        session = try await auth.verifyEmailCode(code, email: email)
    }

    func signOut() async throws {
        try await auth.signOut()
        session = nil
    }

    /// Erases favorites, picks and offline copies on this device; the reminders go with the picks.
    func deleteAccount() async throws {
        try await auth.deleteAccount()
        session = nil
        await favorites.reloadAfterErase()
        await picks.reloadAfterErase()
    }

    /// The export, written to a temporary file for the share sheet.
    func exportFile() async throws -> URL {
        let export = LocalDataExport(
            account: session, favorites: await favorites.entries(), picks: await picks.entries(),
            // ponytail: no per-type notification switch exists yet (STORY-024).
            reminderLead: PicksModel.lead, notifications: [:], exportedAt: Date()
        )
        let file = FileManager.default.temporaryDirectory.appending(path: "esprit-festivalier-mes-donnees.json")
        try export.json().write(to: file, options: .atomic)
        return file
    }
}

/// The export, built only when the user shares it.
struct DataExportFile: Transferable {
    let make: @Sendable () async throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { SentTransferredFile(try await $0.make()) }
    }
}
