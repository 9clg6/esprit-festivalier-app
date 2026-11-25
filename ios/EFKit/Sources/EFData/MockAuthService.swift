import CryptoKit
import EFDomain
import Foundation

/// Accounts without a server (mock first, until the Better Auth client of STORY-021): any Apple
/// token signs in, the e-mail code is always `000000`. The session is kept in `session.json`.
public actor MockAuthService: AuthService {
    public static let demoCode = "000000"
    private let sessionFile: URL
    private let userDataDirectories: [URL]
    private let now: @Sendable () -> Date
    public private(set) var session: AuthSession?

    /// `userDataDirectories`: the folders whose content `deleteAccount` erases.
    public init(directory: URL, userDataDirectories: [URL] = [], now: @escaping @Sendable () -> Date = { Date() }) {
        sessionFile = directory.appending(path: "session.json")
        self.userDataDirectories = userDataDirectories
        self.now = now
        session = (try? Data(contentsOf: sessionFile)).flatMap { try? Self.decoder.decode(AuthSession.self, from: $0) }
    }

    /// The same Apple identity gives the same user: the token's `sub` when readable, else a hash.
    /// Without a nonce the server could not check the token: same refusal as an empty token.
    public func signInWithApple(_ credential: AppleCredential) throws -> AuthSession {
        guard !credential.idToken.isEmpty, !credential.nonce.isEmpty else { throw AuthError.invalidAppleToken }
        let subject = Self.subject(ofJWT: credential.idToken) ?? Self.hash(credential.idToken)
        return try signIn(AuthSession(userId: "apple-\(subject)", provider: .apple, email: nil, createdAt: now()))
    }

    /// ponytail: no e-mail is sent; the demo code works for any address.
    public func sendEmailCode(to email: String) throws {
        _ = try Self.parse(email: email)
    }

    /// Verifying without sending first is accepted (demo).
    public func verifyEmailCode(_ code: String, email: String) throws -> AuthSession {
        let address = try Self.parse(email: email)
        guard code == Self.demoCode else { throw AuthError.wrongCode }
        return try signIn(AuthSession(
            userId: "email-\(Self.hash(address.lowercased()))", provider: .email, email: address, createdAt: now()
        ))
    }

    /// The local favorites and picks stay.
    public func signOut() throws {
        if FileManager.default.fileExists(atPath: sessionFile.path) {
            try FileManager.default.removeItem(at: sessionFile)
        }
        session = nil
    }

    /// The data first, the session last: if erasing fails the user is still signed in and can retry.
    /// The session's own folder is skipped when it sits inside a data folder.
    public func deleteAccount() throws {
        let sessionFolder = sessionFile.deletingLastPathComponent().standardizedFileURL
        for directory in userDataDirectories {
            let items = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for item in items ?? [] where item.standardizedFileURL != sessionFolder {
                try FileManager.default.removeItem(at: item)
            }
        }
        try signOut()
    }

    private func signIn(_ new: AuthSession) throws -> AuthSession {
        let directory = sessionFile.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // A session must not come back on another device from a backup; only this folder is excluded.
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var folder = directory
        try folder.setResourceValues(excluded)
        try Self.encoder.encode(new).write(to: sessionFile, options: .atomic)
        session = new
        return new
    }

    /// Trimmed; one "@" with something before it, a dotted domain, no space inside.
    static func parse(email: String) throws -> String {
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty,
              parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !address.contains(where: \.isWhitespace) else { throw AuthError.invalidEmail }
        return address
    }

    /// The `sub` claim of a JWT, without checking its signature (the server will).
    private static func subject(ofJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var payload = parts[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = claims["sub"] as? String, !sub.isEmpty else { return nil }
        return sub
    }

    private static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
