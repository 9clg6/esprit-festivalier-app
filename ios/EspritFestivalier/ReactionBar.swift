import EFData
import EFDesign
import EFDomain
import SwiftUI

/// "Ta réaction" at the end of an article (FR-030, UX "Réactions : états"): five pills that wrap,
/// a list at accessibility sizes. The taps and writes are `ReactionsModel`'s.
struct ReactionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: ReactionsModel
    /// The light haptic's trigger: one per tap.
    @State private var taps = 0

    init(article: ArticleKey, service: any ReactionService) {
        _model = State(initialValue: ReactionsModel(article: article, service: service))
    }

    private var summary: ReactionSummary? { model.summary }

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
                    ) {
                        taps += 1
                        model.toggle(reaction)
                    }
                }
            }
            if summary?.isDemo == true { DemoCaption(text: "Données de démonstration") }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Réactions")
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .task { await model.load() }
    }
}
