import EFDesign
import EFDomain
import SwiftUI

/// E3: place, period and genres, with a live "Voir N festivals" button.
struct FestivalFilterSheet: View {
    let model: FestivalListModel
    let aroundMe: AroundMe
    @Environment(\.dismiss) private var dismiss
    @State private var from = Date()
    @State private var until = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                section("Où") { place }
                section("Quand") { period }
                if !model.availableGenres.isEmpty {
                    section("Genres") { genres }
                }
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            let count = model.count(for: model.filter)
            let title = count == 0 ? "Aucun festival" : "Voir \(count) festival\(count == 1 ? "" : "s")"
            PrimaryButton(title) { dismiss() }
                .padding(16)
                .background(EFColorToken.bg.color)
        }
        .background(EFColorToken.bg.color)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .aroundMePrompts(aroundMe, chooseRegion: {})
        .onAppear {
            if case .dates(let interval) = model.filter.period { (from, until) = (interval.start, interval.end) }
        }
    }

    private var header: some View {
        HStack {
            Text("Filtres")
                .efText(.title2)
                .foregroundStyle(EFTextColor.ink.color)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Effacer") {
                model.filter = FestivalFilter(searchText: model.filter.searchText)
            }
            .efText(.strongLabel)
            .foregroundStyle(EFTextColor.accentDark.color)
            .frame(minHeight: 44)
            .disabled(model.filter.activeCount == 0)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            content()
        }
    }

    // MARK: Où

    private var radius: FestivalFilter.Radius? {
        if case .around(_, let radius) = model.filter.place { radius } else { nil }
    }

    private var region: String? {
        if case .region(let name) = model.filter.place { name } else { nil }
    }

    private var place: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                radioRow("Autour de moi", isOn: radius != nil) {
                    if radius != nil {
                        model.filter.place = .anywhere
                    } else {
                        aroundMe.activate { model.filter.place = .around($0, radius: .km50) }
                    }
                }
                if let radius, case .around(let center, _) = model.filter.place {
                    Picker("Rayon", selection: Binding(
                        get: { radius }, set: { model.filter.place = .around(center, radius: $0) }
                    )) {
                        ForEach(FestivalFilter.Radius.allCases, id: \.self) { Text("\($0.rawValue) km").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(EFTextColor.accentDark.color)
                    .frame(minHeight: 44)
                }
            }
            HStack {
                radioRow("Région", isOn: region != nil) {
                    if region != nil {
                        model.filter.place = .anywhere
                    } else if let first = model.availableRegions.first {
                        model.filter.place = .region(first)
                    }
                }
                Picker("Région", selection: Binding(
                    get: { region ?? "" }, set: { model.filter.place = $0.isEmpty ? .anywhere : .region($0) }
                )) {
                    Text("Toutes").tag("")
                    ForEach(model.availableRegions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(EFTextColor.accentDark.color)
                .frame(minHeight: 44)
            }
            if aroundMe.isDenied {
                Text("La position est désactivée. Choisis une région, ou autorise la position dans Réglages.")
                    .efText(.caption)
                    .foregroundStyle(EFTextColor.muted.color)
            }
        }
    }

    private func radioRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(EFColorToken.accent.color)
                Text(title).efText(.body).foregroundStyle(EFTextColor.ink.color)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Quand

    private var period: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout {
                GenreChip("Ce week-end", isSelected: model.filter.period == .thisWeekend) { toggle(.thisWeekend) }
                GenreChip("Ce mois-ci", isSelected: model.filter.period == .thisMonth) { toggle(.thisMonth) }
                GenreChip("Choisir des dates", isSelected: isChosenDates) {
                    toggle(model.dates(from: from, to: until))
                }
            }
            if isChosenDates {
                DatePicker("Du", selection: $from, displayedComponents: .date)
                    .onChange(of: from) { _, new in
                        until = max(until, new)
                        model.filter.period = model.dates(from: new, to: until)
                    }
                DatePicker("Au", selection: $until, in: from..., displayedComponents: .date)
                    .onChange(of: until) { _, new in model.filter.period = model.dates(from: from, to: new) }
            }
        }
        .environment(\.calendar, model.calendar)
        .environment(\.locale, model.calendar.locale ?? .current)
        .environment(\.timeZone, model.calendar.timeZone)
        .efText(.body)
        .tint(EFColorToken.accentFill.color)
    }

    private var isChosenDates: Bool {
        if case .dates = model.filter.period { true } else { false }
    }

    private func toggle(_ period: FestivalFilter.Period) {
        let isOn = model.filter.period == period || (isChosenDates && period == model.dates(from: from, to: until))
        model.filter.period = isOn ? .any : period
    }

    // MARK: Genres

    private var genres: some View {
        FlowLayout {
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
}
