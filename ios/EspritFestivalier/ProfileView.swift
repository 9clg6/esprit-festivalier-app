import EFDesign
import EFDomain
import SwiftUI
import UserNotifications

/// E12, reduced to the concert reminders until accounts come (STORY-022).
struct ProfileView: View {
    @Environment(PicksModel.self) private var picks
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(PicksModel.leadKey) private var lead = ReminderLead.default.rawValue
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        NavigationStack {
            Form {
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
