import EFData
import EFDesign
import EFDomain
import Observation
import SafariServices
import SwiftUI

@MainActor @Observable
final class FestivalDetailModel {
    enum State {
        case loading
        case loaded(FestivalDetail, lineup: [String])
        case failed
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
            // A lineup that cannot load is hidden, like an empty one.
            let artistIds = detail.performances.sorted { $0.start < $1.start }.map(\.artistId)
            let names = Dictionary(
                ((try? await artists.artists(ids: artistIds)) ?? []).map { ($0.id, $0.name) },
                uniquingKeysWith: { first, _ in first }
            )
            var seen = Set<Artist.ID>()
            let lineup = artistIds.filter { seen.insert($0).inserted }.compactMap { names[$0] }
            state = .loaded(detail, lineup: lineup)
        } catch is CancellationError {
            // Leaving the screen cancels the load.
        } catch {
            state = .failed
        }
    }
}

/// E5: festival detail, loaded through the `FestivalSource`.
struct FestivalDetailView: View {
    @State private var model: FestivalDetailModel

    init(id: Festival.ID, festivals: any FestivalSource, artists: any ArtistSource) {
        _model = State(initialValue: FestivalDetailModel(id: id, festivals: festivals, artists: artists))
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ScrollView { FestivalDetailSkeleton() }
            case .failed:
                EmptyState(
                    systemImage: "wifi.exclamationmark", title: "Impossible de charger ce festival",
                    message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
                ) { Task { await model.load() } }
                .frame(maxHeight: .infinity)
            case .loaded(let detail, let lineup):
                FestivalDetailContent(detail: detail, lineup: lineup)
            }
        }
        .background(EFColorToken.bg.color)
        .task { await model.load() }
    }
}

private struct FestivalDetailSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(cornerRadius: 0).frame(height: 300)
            SkeletonBlock().frame(width: 120, height: 14).padding(.top, 8)
            SkeletonBlock().frame(height: 32)
            SkeletonBlock().frame(width: 200, height: 16)
            SkeletonBlock(cornerRadius: 25).frame(height: 50).padding(.top, 8)
            SkeletonBlock().frame(height: 80)
        }
        .padding(.bottom, 16)
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chargement")
    }
}

private struct FestivalDetailContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    @State private var safariURL: SafariItem?
    let detail: FestivalDetail
    let lineup: [String]

    private var festival: Festival { detail.festival }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                VStack(alignment: .leading, spacing: 24) {
                    header
                    actions
                    if let summary = detail.summary, !summary.isEmpty {
                        section("À propos") { Text(summary).efText(.body).foregroundStyle(EFTextColor.ink.color) }
                    }
                    if !lineup.isEmpty {
                        section("Programmation") {
                            Text("Données de démonstration (dernière édition)")
                                .efText(.caption)
                                .foregroundStyle(EFTextColor.muted.color)
                            // Tapping an artist does nothing yet (E8 comes later).
                            ForEach(lineup, id: \.self) { name in
                                Text(name).efText(.body).foregroundStyle(EFTextColor.ink.color)
                            }
                        }
                    }
                    if !detail.practicalInfo.isEmpty {
                        section("Infos pratiques") {
                            ForEach(detail.practicalInfo, id: \.self) { info in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.title).efText(.strongLabel).foregroundStyle(EFTextColor.ink.color)
                                    Text(info.text).efText(.body).foregroundStyle(EFTextColor.ink2.color)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    if let pageURL = festival.pageURL {
                        Link(destination: pageURL) {
                            Text("Lire sur Esprit Festivalier ↗\u{FE0E}")
                                .efText(.strongLabel)
                                .foregroundStyle(EFTextColor.accentDark.color)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url).ignoresSafeArea()
        }
    }

    // Decorative for VoiceOver: reading order is title, actions, content.
    private var hero: some View {
        Color(EFColorToken.thumb.color)
            .frame(height: 320)
            .overlay { heroImage }
            .clipped()
            .accessibilityHidden(true)
    }

    private var heroImage: some View {
        AsyncImage(url: festival.imageURL) { phase in
            if let image = phase.image {
                ZStack(alignment: .bottomLeading) {
                    // The overlay takes the hero's size: the fill overflow is clipped, not laid out.
                    Color.clear.overlay { image.resizable().scaledToFill() }.clipped()
                    // Top scrim (page colour): status bar and back button; bottom scrim: the credit.
                    LinearGradient(
                        stops: [.init(color: EFColorToken.bg.color.opacity(0.8), location: 0),
                                .init(color: .clear, location: 0.22),
                                .init(color: .clear, location: 0.6),
                                .init(color: EFColorToken.night.color.opacity(0.85), location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                    if let credit = festival.imageCredit {
                        Text("Photo : \(credit)")
                            .efText(.caption)
                            .foregroundStyle(EFTextColor.onFill.color)
                            .padding(.horizontal, 16).padding(.bottom, 10)
                    }
                }
            } else {
                Image(systemName: "music.note").font(.largeTitle).foregroundStyle(EFTextColor.muted.color)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !festival.genres.isEmpty {
                Text(festival.genres.joined(separator: " · "))
                    .efText(.sectionHeader)
                    .foregroundStyle(EFTextColor.accentDark.color)
            }
            Text(festival.name)
                .efText(.title1)
                .foregroundStyle(EFTextColor.ink.color)
                .accessibilityAddTraits(.isHeader)
            Text("\(FestivalDates.text(from: festival.startDate, to: festival.endDate)) · \(festival.city)")
                .efText(.bodySecondary)
                .foregroundStyle(EFTextColor.ink2.color)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if let url = TicketLink.url(for: festival) {
                PrimaryButton("Billets ↗\u{FE0E}") { safariURL = SafariItem(url: url) }
                    .accessibilityLabel("Billets, site externe")
            }
            SecondaryButton("Itinéraire") { openURL(Directions.appleMapsURL(for: festival)) }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title)
            content()
        }
    }
}

private struct SafariItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#Preview("Light") { FestivalDetailPreview() }
#Preview("Dark") { FestivalDetailPreview().preferredColorScheme(.dark) }
#Preview("AX3") { FestivalDetailPreview().dynamicTypeSize(.accessibility3) }

private struct FestivalDetailPreview: View {
    var body: some View {
        NavigationStack {
            FestivalDetailView(id: "eurockeennes", festivals: MockFestivalSource(), artists: MockArtistSource())
        }
    }
}
