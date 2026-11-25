import EFData
import EFDesign
import EFDomain
import Observation
import SwiftUI

@MainActor @Observable
final class TimetableModel {
    enum State {
        case loading, failed
        case loaded(FestivalDetail, Timetable, artistNames: [Artist.ID: String])
    }

    private(set) var state = State.loading
    private let id: Festival.ID
    private let festivals: any FestivalSource
    private let artists: any ArtistSource

    init(id: Festival.ID, festivals: any FestivalSource, artists: any ArtistSource) {
        self.id = id
        self.festivals = festivals
        self.artists = artists
    }

    func load() async {
        do {
            let detail = try await festivals.festival(id: id)
            // An artist that cannot load shows as "Artiste à confirmer", the timetable still opens.
            let names = ((try? await artists.artists(ids: detail.performances.map(\.artistId))) ?? [])
                .map { ($0.id, $0.name) }
            state = .loaded(
                detail, Timetable(detail, calendar: AppEnvironment.calendar),
                artistNames: Dictionary(names, uniquingKeysWith: { first, _ in first })
            )
        } catch is CancellationError {
            // Leaving the screen cancels the load.
        } catch {
            state = .failed
        }
    }
}

/// E6: the festival's sets by day and stage; ☆/★ picks a set, "Moi" shows only the picked ones.
struct TimetableView: View {
    @Environment(PicksModel.self) private var picks
    @State private var model: TimetableModel
    @State private var day: Date?
    @State private var onlyMine = false
    private let isDemo: Bool

    init(id: Festival.ID, environment: AppEnvironment) {
        isDemo = environment.isDemo
        _model = State(initialValue: TimetableModel(
            id: id, festivals: environment.festivals, artists: environment.artists
        ))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed:
                EmptyState(
                    systemImage: "wifi.exclamationmark", title: "Impossible de charger la timetable",
                    message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
                ) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
            case .loaded(let detail, let timetable, let names):
                // Re-evaluated every minute for "Maintenant".
                TimelineView(.everyMinute) { context in
                    content(detail, timetable, names, now: appNow(context.date))
                }
            }
        }
        .background(EFColorToken.bg.color)
        .navigationTitle("Timetable")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle("Moi", isOn: $onlyMine)
                    .toggleStyle(.button)
                    .accessibilityHint("Seulement mes concerts")
            }
        }
        .task { await model.load() }
    }

    @ViewBuilder
    private func content(_ detail: FestivalDetail, _ timetable: Timetable, _ names: [Artist.ID: String], now: Date)
        -> some View {
        if timetable.days.isEmpty {
            EmptyState(
                systemImage: "music.note.list", title: "Pas encore d'horaires",
                message: "La timetable de ce festival n'est pas encore publiée."
            )
            .frame(maxHeight: .infinity)
        } else {
            let selected = timetable.days.first { $0.date == day } ?? defaultDay(timetable, now: now)
            let conflicts = timetable.conflicts(in: picks.ids)
            let playing = Set(timetable.nowPlaying(at: now).map(\.id))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    // The demo times are invented, even for real festivals.
                    if isDemo { DemoCaption().padding(.top, 8) }
                    dayPicker(timetable.days, selected: selected)
                    let stages = selected.stages.compactMap { stage in
                        let shown = stage.performances.filter { !onlyMine || picks.contains($0.id) }
                        return shown.isEmpty ? nil : (stage.stage, shown)
                    }
                    if stages.isEmpty {
                        Text("Aucun concert coché ce jour-là. Touche ☆ pour en ajouter.")
                            .efText(.bodySecondary)
                            .foregroundStyle(EFTextColor.ink2.color)
                            .padding(.top, 24)
                    }
                    ForEach(stages, id: \.0.id) { stage, performances in
                        SectionHeader(stage.name).padding(.top, 16)
                        ForEach(performances) { performance in
                            PerformanceCell(
                                time: Self.time.string(from: performance.start),
                                artist: names[performance.artistId] ?? "Artiste à confirmer",
                                isPicked: picks.contains(performance.id),
                                isNow: playing.contains(performance.id),
                                conflicts: (conflicts[performance.id] ?? []).map {
                                    names[$0.artistId] ?? "un autre concert"
                                }
                            ) { picks.toggle(performance.id) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func dayPicker(_ days: [TimetableDay], selected: TimetableDay) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.date) { item in
                    GenreChip(Self.dayLabel(item.date), isSelected: item.date == selected.date) { day = item.date }
                        .accessibilityLabel(Self.dayName.string(from: item.date))
                }
            }
        }
        .padding(.top, 8)
    }

    /// The festival day playing now, or the first one.
    private func defaultDay(_ timetable: Timetable, now: Date) -> TimetableDay {
        let today = Timetable.festivalDay(of: now, calendar: AppEnvironment.calendar)
        return timetable.days.first { $0.date == today } ?? timetable.days[0]
    }

    /// "Ven 13".
    private static func dayLabel(_ date: Date) -> String {
        let text = dayShort.string(from: date).replacingOccurrences(of: ".", with: "")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private static let time = formatter("HH:mm")
    private static let dayShort = formatter("EEE d")
    private static let dayName = formatter("EEEE d MMMM")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppEnvironment.calendar.locale
        formatter.timeZone = AppEnvironment.calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

#Preview("Light") { TimetablePreview() }
#Preview("Dark") { TimetablePreview().preferredColorScheme(.dark) }
#Preview("AX3") { TimetablePreview().dynamicTypeSize(.accessibility3) }

private struct TimetablePreview: View {
    var body: some View {
        let environment = AppEnvironment(kind: .mock)
        NavigationStack {
            TimetableView(id: "trans-musicales", environment: environment)
        }
        .environment(environment.picks)
    }
}
