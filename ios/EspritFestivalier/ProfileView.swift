import EFDesign
import EFDomain
import SwiftUI

/// E12, reduced to the concert reminders setting until accounts come (STORY-022).
struct ProfileView: View {
    @Environment(PicksModel.self) private var picks
    @AppStorage(PicksModel.leadKey) private var lead = ReminderLead.default.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
    }
}
