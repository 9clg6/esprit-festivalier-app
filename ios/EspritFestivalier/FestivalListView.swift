import EFData
import EFDesign
import EFDomain
import SwiftUI

/// E2 and E4: upcoming festivals as a list or on a map, with search, quick chips and the E3 sheet.
struct FestivalListView: View {
    enum Mode: String, CaseIterable {
        case list = "Liste", map = "Carte"
    }

    @Environment(FavoritesModel.self) private var favorites
    @State private var model: FestivalListModel
    @State private var aroundMe = AroundMe()
    @State private var path: [Route] = Self.initialPath
    @State private var showFilters = Self.debugFlag("openFilters")
    @State private var mode = Self.debugFlag("mapMode") ? Mode.map : .list
    @State private var selectedOnMap: Festival.ID?
    @State private var recenter = 0
    /// Set by the home "Tout voir": the list opens on that period.
    @Binding private var requestedPeriod: FestivalFilter.Period?
    private let environment: AppEnvironment

    init(environment: AppEnvironment, requestedPeriod: Binding<FestivalFilter.Period?>) {
        self.environment = environment
        _requestedPeriod = requestedPeriod
        let model = FestivalListModel(source: environment.festivals)
        #if DEBUG
        model.filter = Self.debugFilter
        #endif
        _model = State(initialValue: model)
    }

    /// Debug builds only: `-openFestival <id>` opens a festival's detail at launch (simulator runs).
    private static var initialPath: [Route] {
        #if DEBUG
        UserDefaults.standard.string(forKey: "openFestival").map { [.festival($0)] } ?? []
        #else
        []
        #endif
    }

    /// Debug builds only: `-openFilters YES`, `-mapMode YES`.
    private static func debugFlag(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }

    #if DEBUG
    /// Debug builds only: `-search <text>`, `-initialAround <km>` (from Paris), `-initialGenre <name>`.
    private static var debugFilter: FestivalFilter {
        let defaults = UserDefaults.standard
        var filter = FestivalFilter(searchText: defaults.string(forKey: "search") ?? "")
        if let radius = FestivalFilter.Radius(rawValue: defaults.integer(forKey: "initialAround")) {
            filter.place = .around(Coordinate(latitude: 48.8566, longitude: 2.3522), radius: radius)
        }
        filter.genres = Set(defaults.string(forKey: "initialGenre").map { [$0] } ?? [])
        return filter
    }
    #endif

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $path) {
            screen
                .navigationTitle("Festivals")
                .navigationBarTitleDisplayMode(mode == .map ? .inline : .large)
                .searchable(
                    text: $model.filter.searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Rechercher un festival"
                )
                .autocorrectionDisabled()
                .routes(environment)
        }
        .task { await model.load() }
        .onChange(of: requestedPeriod, initial: true) {
            guard let period = requestedPeriod else { return }
            model.filter.period = period
            path = []
            requestedPeriod = nil
        }
        .sheet(isPresented: $showFilters) {
            FestivalFilterSheet(model: model, aroundMe: aroundMe)
        }
        .aroundMePrompts(aroundMe, isOn: !showFilters) { showFilters = true }
    }

    @ViewBuilder private var screen: some View {
        if mode == .map, case .loaded = model.state {
            VStack(spacing: 12) {
                controls.padding(.horizontal, 16)
                if model.upcoming.isEmpty {
                    ScrollView { noResult }
                } else {
                    mapArea
                }
            }
            .background(EFColorToken.bg.color)
        } else if !showsRows {
            // Empty states stay out of the List: in a List row, the whole row would trigger its buttons.
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    controls
                    content
                }
                .padding(.horizontal, 16)
            }
            .refreshable { await model.load() }
            .background(EFColorToken.bg.color)
        } else {
            // A List, for the swipe action on rows.
            List {
                Group {
                    controls
                    content
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await model.load() }
            .background(EFColorToken.bg.color)
        }
    }

    // MARK: Quick chips and Liste | Carte

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filtersChip
                    GenreChip("Ce week-end", isSelected: model.filter.period == .thisWeekend) {
                        model.filter.period = model.filter.period == .thisWeekend ? .any : .thisWeekend
                    }
                    GenreChip("Autour de moi", isSelected: isAround) { toggleAround() }
                    ForEach(model.availableGenres, id: \.self) { genre in
                        GenreChip(genre, isSelected: model.filter.genres.contains(genre)) {
                            if model.filter.genres.contains(genre) {
                                model.filter.genres.remove(genre)
                            } else {
                                model.filter.genres.insert(genre)
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
            Picker("Affichage", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var filtersChip: some View {
        let count = model.filter.activeCount
        return GenreChip(count == 0 ? "Filtres" : "Filtres · \(count)", isSelected: count > 0) { showFilters = true }
            .accessibilityLabel(count == 0 ? "Filtres" : "Filtres, \(count) \(count == 1 ? "actif" : "actifs")")
            .accessibilityHint("Ouvre les filtres")
    }

    private var showsRows: Bool {
        switch model.state {
        case .loading: true
        case .failed: false
        case .loaded: !model.upcoming.isEmpty
        }
    }

    private var isAround: Bool {
        if case .around = model.filter.place { true } else { false }
    }

    private func toggleAround() {
        if isAround {
            model.filter.place = .anywhere
        } else {
            aroundMe.activate { model.filter.place = .around($0, radius: .km50) }
        }
    }

    // MARK: List

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
        case .loaded(let festivals) where festivals.isEmpty:
            EmptyState(
                systemImage: "calendar", title: "Aucun festival à venir",
                message: "Tire vers le bas pour actualiser la liste."
            )
        case .loaded:
            if model.upcoming.isEmpty {
                noResult
            } else {
                ForEach(model.sections) { section in
                    SectionHeader(section.title).padding(.top, 20)
                    ForEach(section.festivals) { festival in
                        Button { path.append(.festival(festival.id)) } label: { row(festival) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) { swipeAction(festival) }
                    }
                }
            }
        }
    }

    private func row(_ festival: Festival) -> some View { FestivalRow(festival, favorites: favorites) }

    private func swipeAction(_ festival: Festival) -> some View {
        let isFavorite = favorites.contains(festival.id)
        return Button { favorites.toggle(festival.id) } label: {
            Label(
                isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                systemImage: isFavorite ? "heart.slash" : "heart"
            )
        }
        .tint(EFColorToken.accentFill.color)
    }

    /// P1: "Élargir à 100 km" when around me is on, otherwise "Effacer les filtres".
    private var noResult: some View {
        var widen: (() -> Void)?
        if case .around(let center, let radius) = model.filter.place, radius != .km100 {
            widen = { model.filter.place = .around(center, radius: .km100) }
        }
        return VStack(spacing: 4) {
            EmptyState(
                systemImage: "magnifyingglass", title: "Aucun festival avec ces filtres",
                message: "Essaie d'autres critères ou élargis la recherche.",
                actionTitle: widen == nil ? "Effacer les filtres" : "Élargir à 100 km",
                action: widen ?? { model.filter = FestivalFilter() }
            )
            if widen != nil {
                Button("Effacer les filtres") { model.filter = FestivalFilter() }
                    .efText(.strongLabel)
                    .foregroundStyle(EFTextColor.accentDark.color)
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: Map

    private var mapArea: some View {
        ZStack(alignment: .bottom) {
            FestivalMapView(
                festivals: model.upcoming, favoriteIDs: Set(favorites.ids), selection: $selectedOnMap,
                userCoordinate: aroundMe.isAuthorized ? aroundMe.coordinate : nil, recenter: recenter
            )
            VStack(alignment: .trailing, spacing: 12) {
                if aroundMe.isAuthorized, aroundMe.coordinate != nil {
                    Button { recenter += 1 } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(EFTextColor.onFill.color)
                            .frame(width: 44, height: 44)
                            .background(EFColorToken.accentFill.color, in: Circle())
                    }
                    .accessibilityLabel("Recentrer sur ma position")
                }
                if let festival = model.upcoming.first(where: { $0.id == selectedOnMap }) {
                    NavigationLink(value: Route.festival(festival.id)) { row(festival) }
                        .buttonStyle(.plain)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                }
            }
            .padding(16)
        }
    }
}
