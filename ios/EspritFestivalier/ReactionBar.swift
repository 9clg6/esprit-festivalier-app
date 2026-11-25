import EFDesign
import EFDomain
import SwiftUI

/// "Ta réaction" at the end of an article (FR-030, UX "Réactions : états"): five pills that wrap,
/// a list at accessibility sizes. A failed write says nothing (UX): the pills show what is stored.
struct ReactionBar: View {
    let article: Article.ID
    let service: any ReactionService
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var summary: ReactionSummary?
    /// The light haptic's trigger: one per tap.
    @State private var taps = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Ta réaction")
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(FlowLayout())
            layout {
                ForEach(Reaction.allCases, id: \.self) { reaction in
                    ReactionPill(
                        emoji: reaction.emoji, label: reaction.label, count: summary?.counts?[reaction],
                        isSelected: summary?.mine.contains(reaction) ?? false
                    ) { toggle(reaction) }
                }
            }
            if summary?.isDemo == true { DemoCaption(text: "Données de démonstration") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Réactions")
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .task { summary = try? await service.summary(for: article) }
    }

    /// The target is decided at tap time from what the user sees.
    private func toggle(_ reaction: Reaction) {
        taps += 1
        let active = !(summary?.mine.contains(reaction) ?? false)
        Task {
            if let updated = try? await service.set(reaction, active: active, on: article) {
                summary = updated
            } else {
                summary = try? await service.summary(for: article)
            }
        }
    }
}
