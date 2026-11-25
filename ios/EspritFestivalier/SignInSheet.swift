import AuthenticationServices
import CryptoKit
import EFData
import EFDesign
import EFDomain
import SwiftUI

/// E13: Apple or an e-mail code (UX P6). Mock first: the code is always `000000`.
struct SignInSheet: View {
    @Environment(AccountModel.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var step = Step.choose
    @State private var email = ""
    @State private var code = ""
    @State private var error: String?
    /// Seconds before "Renvoyer le code" works again (UX P6: 30 s after each sending).
    @State private var resendIn = 0
    @State private var resendDelay: Task<Void, Never>?
    /// The raw nonce of the Apple request in flight; Apple gets its SHA-256.
    @State private var nonce = ""

    private enum Step { case choose, email, code }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch step {
                    case .choose: choose
                    case .email: emailStep
                    case .code: codeStep
                    }
                    if let error {
                        Text(error)
                            .efText(.bodySecondary)
                            .foregroundStyle(EFTextColor.ink.color)
                            .multilineTextAlignment(.center)
                            .onAppear { AccessibilityNotification.Announcement(error).post() }
                    }
                }
                .padding(16)
            }
            .background(EFColorToken.bg.color)
            .navigationTitle(step == .choose ? "" : "Connexion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
        .onDisappear { resendDelay?.cancel() }
    }

    private var choose: some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200)
                .padding(.top, 24)
                .accessibilityLabel("Esprit Festivalier")
            Text("Garde tes festivals sur tous tes appareils")
                .efText(.title2)
                .foregroundStyle(EFTextColor.ink.color)
                .multilineTextAlignment(.center)
            SignInWithAppleButton(.continue) { request in
                nonce = Self.randomNonce()
                request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
                // The user may hide or relay the address: the account never depends on it.
                request.requestedScopes = [.email]
            } onCompletion: { result in
                appleCompleted(result)
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .clipShape(Capsule())
            SecondaryButton("Continuer avec un e-mail") {
                error = nil
                step = .email
            }
            Text(
                "Compte de démonstration : tes données restent sur ce téléphone. "
                    + "La politique de confidentialité sera publiée avant l'ouverture des comptes."
            )
                .efText(.caption)
                .foregroundStyle(EFTextColor.muted.color)
                .multilineTextAlignment(.center)
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ton adresse e-mail").efText(.strongLabel).foregroundStyle(EFTextColor.ink.color)
            TextField("Adresse e-mail", text: $email, prompt: Text("prenom@exemple.fr"))
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .onSubmit(send)
                .textFieldStyle(.roundedBorder)
            PrimaryButton("Envoyer le code", action: send)
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Code envoyé à \(email.trimmingCharacters(in: .whitespacesAndNewlines))")
                .efText(.body)
                .foregroundStyle(EFTextColor.ink.color)
            TextField("Code à 6 chiffres", text: $code, prompt: Text("Code à 6 chiffres"))
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(6)) }
            Text("Code de démonstration : \(MockAuthService.demoCode)")
                .efText(.bodySecondary)
                .foregroundStyle(EFTextColor.ink2.color)
            PrimaryButton("Vérifier", action: verify).disabled(code.count != 6)
            HStack {
                Button(resendIn > 0 ? "Renvoyer le code (\(resendIn) s)" : "Renvoyer le code", action: send)
                    .disabled(resendIn > 0)
                    .accessibilityHint(resendIn > 0 ? "Possible dans \(resendIn) secondes" : "")
                Spacer()
                Button("Changer d'adresse") {
                    error = nil
                    code = ""
                    step = .email
                }
            }
            .efText(.bodySecondary)
            .tint(EFTextColor.accentDark.color)
        }
    }

    private func send() {
        error = nil
        Task {
            do {
                try await account.sendEmailCode(to: email)
                step = .code
                startResendDelay()
            } catch {
                self.error = message(for: error)
            }
        }
    }

    /// "Renvoyer le code" waits 30 s after each sending (UX P6), counting down.
    private func startResendDelay() {
        resendDelay?.cancel()
        resendIn = 30
        resendDelay = Task {
            while resendIn > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                resendIn -= 1
            }
        }
    }

    private func verify() {
        error = nil
        Task {
            do {
                try await account.verifyEmailCode(code, email: email)
                dismiss()
            } catch {
                self.error = message(for: error)
            }
        }
    }

    private func appleCompleted(_ result: Result<ASAuthorization, any Error>) {
        error = nil
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                error = message(for: AuthError.invalidAppleToken)
                return
            }
            let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            let apple = AppleCredential(idToken: token, nonce: nonce, authorizationCode: code)
            Task {
                do {
                    try await account.signInWithApple(apple)
                    dismiss()
                } catch {
                    self.error = message(for: error)
                }
            }
        case .failure(let failure):
            // Closing the Apple sheet is not an error.
            if (failure as? ASAuthorizationError)?.code != .canceled { error = message(for: failure) }
        }
    }

    /// 32 random bytes in hex (the system generator is cryptographically secure).
    private static func randomNonce() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    private func message(for error: any Error) -> String {
        switch error as? AuthError {
        case .wrongCode: "Code incorrect, vérifie le dernier e-mail reçu"
        case .invalidEmail: "Cette adresse e-mail ne semble pas valide"
        case .invalidAppleToken, nil: "Connexion impossible, réessaie dans un instant"
        }
    }
}
