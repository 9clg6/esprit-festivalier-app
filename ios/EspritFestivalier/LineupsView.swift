import EFDesign
import EFDomain
import SwiftUI

/// "Annoncée le 24 novembre 2026".
private func announced(_ date: Date) -> String {
    "Annoncée le \(date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR"))))"
}

/// E7: lineup announcements, newest first. A card opens the festival's lineup.
struct LineupsView: View {
    let environment: AppEnvironment

    var body: some View {
        Loaded {
            let data = try await environment.lineupData()
            return Lineups.feed(lineups: data.lineups, festivals: data.festivals, artists: data.artists, now: Date())
        } content: { feed, reload in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if feed.isEmpty {
                        EmptyState(
                            systemImage: "music.mic", title: "Aucune programmation annoncée",
                            message: "Les nouvelles programmations apparaîtront ici."
                        )
                    }
                    ForEach(feed) { card in
                        NavigationLink(value: Route.festivalLineup(card.festival.id)) { LineupCard(card: card) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .refreshable { await reload() }
        }
        .navigationTitle("Programmations")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct LineupCard: View {
    let card: LineupAnnouncement

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FestivalVisual(imageURL: card.festival.imageURL)
            VStack(alignment: .leading, spacing: 6) {
                Text(card.festival.name).efText(.title3).foregroundStyle(EFTextColor.ink.color)
                Text(announced(card.announcedOn)).efText(.bodySecondary).foregroundStyle(EFTextColor.ink2.color)
                Text(artists).efText(.body).foregroundStyle(EFTextColor.ink.color)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EFColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(card.festival.name), \(announced(card.announcedOn)), \(card.artistNames.joined(separator: ", "))"
                + (card.remainingCount > 0 ? ", et \(card.remainingCount) autres" : "")
        )
    }

    private var artists: String {
        card.artistNames.joined(separator: " · ") + (card.remainingCount > 0 ? "  + \(card.remainingCount)" : "")
    }
}

/// E7, one festival: its lineup as a 2-column grid. An artist opens E8.
struct FestivalLineupView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let festivalId: Festival.ID
    let environment: AppEnvironment

    var body: some View {
        Loaded {
            let data = try await environment.lineupData()
            let lineup = data.lineups.first { $0.festivalId == festivalId }
            let byId = Dictionary(data.artists.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return (
                festival: data.festivals.first { $0.id == festivalId }, announcedOn: lineup?.announcedOn,
                artists: (lineup?.artistIds ?? []).compactMap { byId[$0] }
            )
        } content: { lineup, _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let announcedOn = lineup.announcedOn {
                        Text(announced(announcedOn)).efText(.bodySecondary).foregroundStyle(EFTextColor.ink2.color)
                    }
                    if lineup.artists.isEmpty {
                        EmptyState(
                            systemImage: "music.mic", title: "Programmation pas encore annoncée",
                            message: "Les artistes apparaîtront ici dès l'annonce."
                        )
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(lineup.artists) { artist in
                            NavigationLink(value: Route.artist(artist.id)) { tile(artist) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(lineup.festival?.name ?? "Programmation")
        }
        .navigationBarTitleDisplayMode(.large)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private func tile(_ artist: Artist) -> some View {
        VStack(spacing: 8) {
            ArtistAvatar(name: artist.name)
            Text(artist.name)
                .efText(.strongLabel)
                .foregroundStyle(EFTextColor.ink.color)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(EFColorToken.card.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// E8: the artist and their upcoming festivals. No photo, genres nor Apple Music link: the data has none yet.
struct ArtistView: View {
    @Environment(FavoritesModel.self) private var favorites
    let artistId: Artist.ID
    let environment: AppEnvironment

    var body: some View {
        Loaded {
            let data = try await environment.lineupData()
            let artist = try await environment.artists.artists(ids: [artistId]).first
            let festivals = Lineups.upcomingFestivals(
                of: artistId, lineups: data.lineups, festivals: data.festivals, now: Date()
            )
            return (name: artist?.name ?? "", festivals: festivals)
        } content: { artist, _ in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        ArtistAvatar(name: artist.name, size: 120)
                        Text(artist.name)
                            .efText(.title1)
                            .foregroundStyle(EFTextColor.ink.color)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("En festival")
                        if artist.festivals.isEmpty {
                            Text("Aucun festival à venir pour l'instant.")
                                .efText(.body).foregroundStyle(EFTextColor.ink2.color)
                        }
                        ForEach(artist.festivals) { festival in
                            NavigationLink(value: Route.festival(festival.id)) {
                                FestivalRow(festival, favorites: favorites)
                            }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension FestivalRow {
    /// The row of a festival, with its heart.
    @MainActor init(_ festival: Festival, favorites: FavoritesModel) {
        self.init(
            name: festival.name, startDate: festival.startDate, endDate: festival.endDate, city: festival.city,
            imageURL: festival.imageURL, genres: Array(festival.genres.prefix(2)),
            favorite: (favorites.contains(festival.id), { favorites.toggle(festival.id) })
        )
    }
}
