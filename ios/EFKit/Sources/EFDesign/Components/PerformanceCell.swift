import SwiftUI

/// One set of a timetable (E6): time, artist, ☆/★ (44 pt), "Maintenant", and the conflict line.
/// VoiceOver reads it as one element; picking is its default and custom action.
public struct PerformanceCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let time: String
    private let artist: String
    private let isPicked: Bool
    private let isNow: Bool
    /// Artists of the picked sets playing at the same time on another stage.
    private let conflicts: [String]
    private let toggle: () -> Void

    public init(
        time: String, artist: String, isPicked: Bool, isNow: Bool = false, conflicts: [String] = [],
        toggle: @escaping () -> Void
    ) {
        self.time = time
        self.artist = artist
        self.isPicked = isPicked
        self.isNow = isNow
        self.conflicts = conflicts
        self.toggle = toggle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // Large text: the time goes above the artist, who keeps the whole width.
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
                layout {
                    Text(time)
                        .efText(.strongLabel)
                        .foregroundStyle(EFTextColor.ink2.color)
                        .monospacedDigit()
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) { artistName; nowBadge }
                        VStack(alignment: .leading, spacing: 4) { artistName; nowBadge }
                    }
                }
                Spacer(minLength: 0)
                star
            }
            if let conflict = Self.conflictText(conflicts) {
                Text("⚠\u{FE0E} \(conflict)")
                    .efText(.bodySecondary)
                    .foregroundStyle(EFTextColor.onSun.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(EFColorToken.sun.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { toggle() }
        .accessibilityAction(named: isPicked ? "Retirer de ma timetable" : "Ajouter à ma timetable") { toggle() }
    }

    private var artistName: some View {
        Text(artist).efText(.body).foregroundStyle(EFTextColor.ink.color)
    }

    @ViewBuilder private var nowBadge: some View {
        if isNow { Badge("Maintenant") }
    }

    private var star: some View {
        Button(action: toggle) {
            Image(systemName: isPicked ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(EFColorToken.accentDark.color)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isPicked)
    }

    private var accessibilityText: String {
        [time, artist, isPicked ? "dans ma timetable" : nil, isNow ? "maintenant" : nil, Self.conflictText(conflicts)]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    /// "En même temps que X", "qu'Orelsan", "que X et Y".
    static func conflictText(_ names: [String]) -> String? {
        guard let first = names.first else { return nil }
        let list = ListFormatter()
        list.locale = Locale(identifier: "fr_FR")
        let joined = list.string(from: names) ?? names.joined(separator: ", ")
        let elides = first.first.map { "aeiouyàâéèêëîïôûüAEIOUYÀÂÉÈÊËÎÏÔÛÜ".contains($0) } ?? false
        return "En même temps \(elides ? "qu'" : "que ")\(joined)"
    }
}

#Preview("Light") { PerformanceCellSample() }
#Preview("Dark") { PerformanceCellSample().preferredColorScheme(.dark) }
#Preview("AX3") { PerformanceCellSample().dynamicTypeSize(.accessibility3) }

private struct PerformanceCellSample: View {
    var body: some View {
        VStack(alignment: .leading) {
            PerformanceCell(time: "19:00", artist: "Artiste A", isPicked: false) {}
            PerformanceCell(time: "20:30", artist: "Artiste B", isPicked: true, isNow: true, conflicts: ["Orelsan"]) {}
        }
        .padding(16)
        .background(EFColorToken.bg.color)
    }
}
