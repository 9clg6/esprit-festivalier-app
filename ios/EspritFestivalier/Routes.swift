import EFDesign
import EFDomain
import SwiftUI

/// The screens a tab's `NavigationStack` can push (E5, E6, E7, festival lineup, E8, E11).
enum Route: Hashable {
    case festival(Festival.ID)
    case timetable(Festival.ID)
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
            case .timetable(let id): TimetableView(id: id, environment: environment)
            case .lineups: LineupsView(environment: environment)
            case .festivalLineup(let id): FestivalLineupView(festivalId: id, environment: environment)
            case .artist(let id): ArtistView(artistId: id, environment: environment)
            // A new identity per article: one ArticleView never shows another article's model.
            case .article(let article): ArticleView(article: article, environment: environment).id(article.id)
            }
        }
    }
}

extension EnvironmentValues {
    /// Pushes on the tab's stack: E11 opens articles and festivals through it, so a festival opened from an
    /// article keeps its own `Route` links (timetable, artists, « Tout voir »). Set by every stack showing E11.
    @Entry var pushRoute: @MainActor @Sendable (Route) -> Void = { _ in }
}

/// Loads a value once, then shows it: skeletons while loading, "Réessayer" on failure.
/// Coming back to the screen does not reload; `reloadsOnActive` reloads when the app comes back from the
/// background. A failed or cancelled reload keeps what is shown.
struct Loaded<Value, Content: View>: View {
    enum State {
        case loading, failed
        case loaded(Value)
    }

    var reloadsOnActive = false
    let load: @MainActor () async throws -> Value
    @ViewBuilder let content: (Value, _ reload: @escaping @MainActor () async -> Void) -> Content
    @SwiftUI.State private var state = State.loading
    @SwiftUI.State private var wasInBackground = false
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
            // Coming back passes through .inactive, so remember .background; a banner, Control
            // Center or a system alert only goes .active -> .inactive -> .active and does not reload.
            if phase == .background { wasInBackground = true }
            if reloadsOnActive, phase == .active, wasInBackground {
                wasInBackground = false
                Task { await reload() }
            }
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
    var text = "Données de démonstration (dernière édition)"

    var body: some View {
        Text(text)
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
