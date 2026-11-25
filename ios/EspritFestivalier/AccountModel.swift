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
    private let notifications: NotificationsModel
    private let reactions: LocalReactionService
    private let reads: ReadCounter

    init(
        auth: any AuthService, sync: any SyncService, favorites: FavoritesModel, picks: PicksModel,
        notifications: NotificationsModel, reactions: LocalReactionService, reads: ReadCounter
    ) {
        self.auth = auth
        self.sync = sync
        self.favorites = favorites
        self.picks = picks
        self.notifications = notifications
        self.reactions = reactions
        self.reads = reads
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
        removeExportFile()
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
        removeExportFile()
        try await auth.signOut()
        session = nil
    }

    /// Erases favorites, picks, reactions, queued reads, offline copies and notification switches on
    /// this device; the reminders go with them.
    /// On failure too, the screens show what is left on disk.
    func deleteAccount() async throws {
        removeExportFile()
        // Before the erase: a reaction or read written in between must not rewrite the old ones.
        await reactions.reset()
        await reads.reset()
        do {
            try await auth.deleteAccount()
        } catch {
            await reloadFromDisk()
            throw error
        }
        notifications.resetPermissionOffer()
        await reloadFromDisk()
    }

    private func reloadFromDisk() async {
        session = await auth.session
        await favorites.reloadAfterErase()
        await picks.reloadAfterErase()
        notifications.reloadAfterErase()
        await reactions.reload()
        await reads.reload()
    }

    /// The export, written to a temporary file for the share sheet.
    func exportFile() async throws -> URL {
        let export = LocalDataExport(
            account: session, favorites: await favorites.entries(), picks: await picks.entries(),
            reactions: await reactions.entries, reminderLead: PicksModel.lead,
            notifications: notifications.exportFlags, exportedAt: Date()
        )
        try export.json().write(to: Self.exportFile, options: .atomic)
        return Self.exportFile
    }

    /// ShareLink says nothing once the sheet closes: the copy goes at the next launch, sign-out or
    /// deletion, and each export replaces it.
    private static let exportFile = FileManager.default.temporaryDirectory
        .appending(path: "esprit-festivalier-mes-donnees.json")

    private func removeExportFile() { try? FileManager.default.removeItem(at: Self.exportFile) }
}

/// The export, built only when the user shares it.
struct DataExportFile: Transferable {
    let make: @Sendable () async throws -> URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { SentTransferredFile(try await $0.make()) }
    }
}
