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
    @State private var path: [Festival.ID] = Self.initialPath
    private let source: any FestivalSource
    private let artists: any ArtistSource

    init(source: any FestivalSource, artists: any ArtistSource) {
        self.source = source
        self.artists = artists
        _model = State(initialValue: FestivalListModel(source: source))
    }

    /// Debug builds only: `-openFestival <id>` opens a festival's detail at launch (simulator runs).
    private static var initialPath: [Festival.ID] {
        #if DEBUG
        UserDefaults.standard.string(forKey: "openFestival").map { [$0] } ?? []
        #else
        []
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            list
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Festival.ID.self) { id in
                    FestivalDetailView(id: id, festivals: source, artists: artists)
                }
        }
    }

    private var list: some View {
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
                    NavigationLink(value: festival.id) {
                        FestivalRow(
                            name: festival.name, startDate: festival.startDate,
                            endDate: festival.endDate, city: festival.city,
                            imageURL: festival.imageURL, genres: Array(festival.genres.prefix(2))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
