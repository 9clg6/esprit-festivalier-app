import EFDesign
import EFDomain
import SwiftUI
import UserNotifications

/// E12: account, notifications, privacy, about (STORY-022, STORY-032).
struct ProfileView: View {
    @Environment(PicksModel.self) private var picks
    @Environment(AccountModel.self) private var account
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(PicksModel.leadKey) private var lead = ReminderLead.default.rawValue
    @State private var status: UNAuthorizationStatus?
    @State private var showsSignIn = false
    @State private var confirmsDeletion = false
    @State private var accountError: String?
    @State private var safariURL: SafariItem?

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                Section {
                    notifications
                    Picker("Prévenir", selection: $lead) {
                        ForEach(ReminderLead.allCases, id: \.rawValue) { lead in
                            Text("\(lead.rawValue) min avant").tag(lead.rawValue)
                        }
                    }
                } header: {
                    Text("Rappels de concerts")
                } footer: {
                    Text("Une notification avant chaque concert coché dans tes timetables, même sans réseau.")
                }
                privacySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(EFColorToken.bg.color)
            .navigationTitle("Profil")
            .onChange(of: lead) { picks.rescheduleReminders() }
        }
        .task(id: scenePhase) {
            // Back from Réglages: the status may have changed.
            if scenePhase == .active { status = await PicksModel.notificationStatus() }
        }
        #if DEBUG
        // Debug builds only: `-showSignIn YES`, `-confirmDeletion YES` (screenshots).
        .onAppear {
            showsSignIn = UserDefaults.standard.bool(forKey: "showSignIn")
            confirmsDeletion = UserDefaults.standard.bool(forKey: "confirmDeletion")
        }
        #endif
        .sheet(isPresented: $showsSignIn) { SignInSheet() }
        .sheet(item: $safariURL) { item in SafariView(url: item.url).ignoresSafeArea() }
        .confirmationDialog("Supprimer ton compte ?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
            Button("Supprimer mon compte", role: .destructive) { run(account.deleteAccount) }
        } message: {
            Text("Tes favoris, tes concerts cochés et les fiches gardées hors ligne sur ce téléphone seront effacés. "
                + "C'est définitif.")
        }
    }

    @ViewBuilder private var accountSection: some View {
        Section {
            if let session = account.session {
                LabeledContent("Connecté avec", value: session.provider == .apple ? "Apple" : "E-mail")
                if let email = session.email { LabeledContent("E-mail", value: email) }
                Button("Se déconnecter") { run(account.signOut) }
                Button("Supprimer mon compte", role: .destructive) { confirmsDeletion = true }
            } else {
                Button("Se connecter") { showsSignIn = true }
            }
        } header: {
            Text("Compte")
        } footer: {
            if let accountError {
                Text(accountError)
                    .onAppear { AccessibilityNotification.Announcement(accountError).post() }
            } else if account.session == nil {
                Text("Facultatif : tes favoris et tes concerts cochés marchent sans compte.")
            }
        }
    }

    private var privacySection: some View {
        Section("Confidentialité") {
            ShareLink(
                item: DataExportFile { [account] in try await account.exportFile() },
                preview: SharePreview("Mes données Esprit Festivalier")
            ) {
                Text("Exporter mes données")
            }
            LabeledContent("Synchronisation", value: syncText)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: version)
            Text("Le média des festivals, par ceux qui les vivent")
            link("Esprit Festivalier", "https://esprit-festivalier.fr/a-propos/")
            link("Rejoins la rédaction", "https://esprit-festivalier.fr/recrutements/")
            Text("Code source public, tous droits réservés")
                .foregroundStyle(EFTextColor.muted.color)
        } header: {
            Text("À propos")
        }
    }

    private func link(_ title: String, _ address: String) -> some View {
        Button(title) { if let url = URL(string: address) { safariURL = SafariItem(url: url) } }
    }

    private var syncText: String {
        switch account.syncStatus {
        case .none: ""
        case .unavailable: "Pas encore disponible"
        case .synced(let date): date.formatted(.relative(presentation: .named))
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "\(short) (\(build))"
    }

    /// A failed account action leaves a short message under the section.
    private func run(_ action: @escaping () async throws -> Void) {
        accountError = nil
        Task {
            do { try await action() } catch { accountError = "Impossible pour l'instant, réessaie." }
        }
    }

    /// UX P5 step 2: the state, and the way to change it.
    @ViewBuilder private var notifications: some View {
        LabeledContent("Notifications", value: statusText)
        switch status {
        case .notDetermined:
            Button("Activer") {
                Task {
                    await picks.requestNotifications()
                    status = await PicksModel.notificationStatus()
                }
            }
        case .denied:
            Button("Ouvrir Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        default:
            EmptyView()
        }
    }

    private var statusText: String {
        switch status {
        case .none: ""
        case .notDetermined: "Pas encore activées"
        case .denied: "Désactivées dans Réglages"
        default: "Activées"
        }
    }
}
