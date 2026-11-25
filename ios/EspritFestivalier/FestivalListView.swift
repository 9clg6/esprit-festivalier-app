import EFDesign
import EFDomain
import Foundation
import Observation
import SwiftUI

@MainActor @Observable
final class FestivalListModel {
    enum State {
        case loading
        case loaded([FestivalListSection])
        case failed
    }

    private(set) var state = State.loading
    private let source: any FestivalSource
    private let calendar: Calendar

    init(source: any FestivalSource) {
        self.source = source
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        self.calendar = calendar
    }

    func load() async {
        do {
            let festivals = try await source.festivals(updatedSince: nil)
            state = .loaded(FestivalList.sections(from: festivals, now: Date(), calendar: calendar))
        } catch is CancellationError {
            // A cancelled pull-to-refresh keeps what is shown.
        } catch {
            state = .failed
        }
    }
}

/// E2: upcoming festivals, month by month.
struct FestivalListView: View {
    @State private var model: FestivalListModel

    init(source: any FestivalSource) {
        _model = State(initialValue: FestivalListModel(source: source))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Festivals")
                    .efText(.largeTitle)
                    .foregroundStyle(EFColorToken.accent.color)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await model.load() }
        .task { await model.load() }
        .background(EFColorToken.bg.color)
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .loading:
            ForEach(0..<6, id: \.self) { _ in
                SkeletonBlock(cornerRadius: 16).frame(height: 88)
            }
        case .failed:
            EmptyState(
                systemImage: "wifi.exclamationmark", title: "Impossible de charger les festivals",
                message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
            ) { Task { await model.load() } }
        case .loaded(let sections) where sections.isEmpty:
            EmptyState(
                systemImage: "calendar", title: "Aucun festival à venir",
                message: "Tire vers le bas pour actualiser la liste."
            )
        case .loaded(let sections):
            ForEach(sections) { section in
                SectionHeader(section.title).padding(.top, 20)
                ForEach(section.festivals) { festival in
                    FestivalRow(
                        name: festival.name, startDate: festival.startDate,
                        endDate: festival.endDate, city: festival.city
                    )
                }
            }
        }
    }
}
