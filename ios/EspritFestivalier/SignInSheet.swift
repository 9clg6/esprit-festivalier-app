import AuthenticationServices
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
    @State private var canResend = false
    @State private var resendDelay: Task<Void, Never>?

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
                request.requestedScopes = []
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
            TextField("prenom@exemple.fr", text: $email)
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
            TextField("Code à 6 chiffres", text: $code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(6)) }
            Text("Code de démonstration : \(MockAuthService.demoCode)")
                .efText(.bodySecondary)
                .foregroundStyle(EFTextColor.ink2.color)
            PrimaryButton("Vérifier", action: verify).disabled(code.count != 6)
            HStack {
                Button("Renvoyer le code", action: send).disabled(!canResend)
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

    /// "Renvoyer le code" waits 30 s after each sending (UX P6).
    private func startResendDelay() {
        canResend = false
        resendDelay?.cancel()
        resendDelay = Task {
            try? await Task.sleep(for: .seconds(30))
            if !Task.isCancelled { canResend = true }
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
            Task {
                do {
                    try await account.signInWithApple(identityToken: token)
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

    private func message(for error: any Error) -> String {
        switch error as? AuthError {
        case .wrongCode: "Code incorrect, vérifie le dernier e-mail reçu"
        case .invalidEmail: "Cette adresse e-mail ne semble pas valide"
        case .invalidAppleToken, nil: "Connexion impossible, réessaie dans un instant"
        }
    }
}
