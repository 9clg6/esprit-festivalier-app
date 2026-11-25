import Foundation

/// The signed-in account (FR-007). Apple accounts carry no e-mail.
public struct AuthSession: Sendable, Codable, Hashable {
    public enum Provider: String, Codable, Sendable { case apple, email }

    public let userId: String
    public let provider: Provider
    public let email: String?
    public let createdAt: Date

    public init(userId: String, provider: Provider, email: String?, createdAt: Date) {
        self.userId = userId
        self.provider = provider
        self.email = email
        self.createdAt = createdAt
    }
}

public enum AuthError: Error, Equatable {
    case invalidAppleToken, invalidEmail, wrongCode
}

/// Sign in with Apple or an e-mail code (UX P6). The screens only know this protocol (NFR-008).
public protocol AuthService: Sendable {
    var session: AuthSession? { get async }
    func signInWithApple(identityToken: String) async throws -> AuthSession
    func sendEmailCode(to email: String) async throws
    func verifyEmailCode(_ code: String, email: String) async throws -> AuthSession
    func signOut() async throws
    /// Clears the account and the personal data kept on the device.
    func deleteAccount() async throws
}

public enum SyncStatus: Sendable, Equatable {
    case unavailable
    case synced(at: Date)
}

/// Favorites, picks and preferences across devices (STORY-023).
public protocol SyncService: Sendable {
    /// nil: not synced yet.
    var lastSyncedAt: Date? { get async }
    func sync() async throws -> SyncStatus
}
