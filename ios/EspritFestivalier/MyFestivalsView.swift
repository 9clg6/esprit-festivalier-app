import EFData
import EFDesign
import EFDomain
import SwiftUI

/// E9: the favorites, with the next one on top.
struct MyFestivalsView: View {
    private enum Load {
        case loading, failed
        case loaded([Festival])
    }

    @Environment(FavoritesModel.self) private var favorites
    @State private var load = Load.loading
    @State private var path: [Route] = []
    private let environment: AppEnvironment
    private let explore: () -> Void
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.timeZone = TimeZone(identifier: "Europe/Paris") ?? .current
        return calendar
    }()

    init(environment: AppEnvironment, explore: @escaping () -> Void) {
        self.environment = environment
        self.explore = explore
    }

    var body: some View {
        NavigationStack(path: $path) {
            // Re-evaluated every minute, so "Demain" becomes "Aujourd'hui" without leaving the tab.
            TimelineView(.everyMinute) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) { content(now: Self.now(context.date)) }
                        .padding(.horizontal, 16)
                }
            }
            .background(EFColorToken.bg.color)
            .navigationTitle("Mes festivals")
            .routes(environment)
        }
        .task { await refresh() }
    }

    /// Debug builds only: `-fakeNow 2026-12-01T12:00:00Z` shows the "Prochain" card with the demo data.
    private static func now(_ date: Date) -> Date {
        #if DEBUG
        if let text = UserDefaults.standard.string(forKey: "fakeNow"), let fake = try? Date(text, strategy: .iso8601) {
            return fake
        }
        #endif
        return date
    }

    private func refresh() async {
        do {
            load = .loaded(try await environment.festivals.festivals(updatedSince: nil))
        } catch is CancellationError {
            // Leaving the tab keeps what is shown.
        } catch {
            if case .loaded = load { return }
            load = .failed
        }
    }

    @ViewBuilder private func content(now: Date) -> some View {
        switch load {
        case .loading:
            ForEach(0..<3, id: \.self) { _ in SkeletonBlock(cornerRadius: 16).frame(height: 88) }
        case .failed:
            EmptyState(
                systemImage: "wifi.exclamationmark", title: "Impossible de charger tes festivals",
                message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
            ) { Task { await refresh() } }
        case .loaded(let festivals):
            let byID = Dictionary(festivals.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let sections = MyFestivals.sections(
                favorites: favorites.ids.compactMap { byID[$0] }, now: now, calendar: calendar
            )
            if sections.isEmpty, !favorites.ids.isEmpty {
                // Favorites saved, none in the catalogue (removed, or not loaded yet): not "no favorite".
                Text("Tes favoris ne figurent pas dans le catalogue actuel.")
                    .efText(.bodySecondary)
                    .foregroundStyle(EFTextColor.ink2.color)
                    .padding(.top, 24)
            } else if sections.isEmpty {
                EmptyState(
                    systemImage: "heart", title: "Pas encore de favori",
                    message: "Ajoute des festivals en favori pour les retrouver ici, même sans réseau.",
                    actionTitle: "Explorer les festivals", action: explore
                )
            } else {
                if let next = sections.next { nextCard(next) }
                list("À VENIR", sections.upcoming, isPast: false)
                list("PASSÉS", sections.past, isPast: true)
            }
        }
    }

    @ViewBuilder private func list(_ title: String, _ festivals: [Festival], isPast: Bool) -> some View {
        if !festivals.isEmpty {
            SectionHeader(title).padding(.top, 20)
            ForEach(festivals) { festival in
                Button { path.append(.festival(festival.id)) } label: {
                    FestivalRow(
                        name: festival.name, startDate: festival.startDate, endDate: festival.endDate,
                        city: festival.city, imageURL: festival.imageURL, genres: Array(festival.genres.prefix(2)),
                        favorite: (favorites.contains(festival.id), { favorites.toggle(festival.id) }),
                        isPast: isPast
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func nextCard(_ next: NextFestival) -> some View {
        let festival = next.festival
        return Button { path.append(.festival(festival.id)) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(next.when.title.uppercased(with: calendar.locale))
                    .efText(.sectionHeader)
                Text(festival.name)
                    .efText(.title2)
                Text("\(FestivalDates.text(from: festival.startDate, to: festival.endDate)) · \(festival.city)")
                    .efText(.bodySecondary)
                Text("Voir la fiche")
                    .efText(.strongLabel)
                    .foregroundStyle(EFTextColor.onSun.color)
                    .padding(.horizontal, 24)
                    .frame(minHeight: 44)
                    .background(EFColorToken.sun.color, in: Capsule())
                    .padding(.top, 8)
            }
            .foregroundStyle(EFTextColor.onFill.color)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EFColorToken.deep.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
    }
}
