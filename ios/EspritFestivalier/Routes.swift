import EFDesign
import EFDomain
import SwiftUI

/// The screens a tab's `NavigationStack` can push (E5, E7, festival lineup, E8, E11).
enum Route: Hashable {
    case festival(Festival.ID)
    case lineups
    case festivalLineup(Festival.ID)
    case artist(Artist.ID)
    case article(Article)
}

extension View {
    func routes(_ environment: AppEnvironment) -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .festival(let id): FestivalDetailView(id: id, environment: environment)
            case .lineups: LineupsView(environment: environment)
            case .festivalLineup(let id): FestivalLineupView(festivalId: id, environment: environment)
            case .artist(let id): ArtistView(artistId: id, environment: environment)
            case .article(let article): ArticleView(article: article)
            }
        }
    }
}

/// Loads a value once, then shows it: skeletons while loading, "Réessayer" on failure.
/// Coming back to the screen does not reload; `reloadsOnActive` reloads when the app comes back to the
/// foreground. A failed or cancelled reload keeps what is shown.
struct Loaded<Value, Content: View>: View {
    enum State {
        case loading, failed
        case loaded(Value)
    }

    var reloadsOnActive = false
    let load: @MainActor () async throws -> Value
    @ViewBuilder let content: (Value, _ reload: @escaping @MainActor () async -> Void) -> Content
    @SwiftUI.State private var state = State.loading
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch state {
            case .loading:
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in SkeletonBlock(cornerRadius: 16).frame(height: 120) }
                    }
                    .padding(16)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Chargement")
            case .failed:
                EmptyState(
                    systemImage: "wifi.exclamationmark", title: "Impossible de charger cette page",
                    message: "Vérifie ta connexion, puis réessaie.", actionTitle: "Réessayer"
                ) { Task { await reload() } }
                .frame(maxHeight: .infinity)
            case .loaded(let value):
                content(value, reload)
            }
        }
        .background(EFColorToken.bg.color)
        .task {
            if case .loading = state { await reload() }
        }
        .onChange(of: scenePhase) { _, phase in
            if reloadsOnActive, phase == .active { Task { await reload() } }
        }
    }

    private func reload() async {
        do {
            state = .loaded(try await load())
        } catch {
            if case .loaded = state { return }
            if !(error is CancellationError) { state = .failed }
        }
    }
}

/// Said wherever lineups are shown while they come from the demo data.
struct DemoCaption: View {
    var body: some View {
        Text("Données de démonstration (dernière édition)")
            .efText(.caption)
            .foregroundStyle(EFTextColor.muted.color)
    }
}

/// An artist without photo: initials on `sky`. Decorative for VoiceOver (the name is next to it).
struct ArtistAvatar: View {
    let name: String
    var size: CGFloat = 96

    var body: some View {
        Text(initials)
            .font(EFTextStyle.title2.font)
            .foregroundStyle(EFTextColor.accentDark.color)
            .frame(width: size, height: size)
            .background(EFColorToken.sky.color, in: Circle())
            .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
