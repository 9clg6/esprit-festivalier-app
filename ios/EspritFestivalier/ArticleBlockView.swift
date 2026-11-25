import EFDesign
import EFDomain
import SwiftUI

/// An article block with its text already built: one `AttributedString` per paragraph (UX `ArticleBlockView`).
struct RenderedBlock: Identifiable {
    enum Kind {
        case paragraph(AttributedString)
        case heading(level: Int, AttributedString)
        case image(ArticleImage)
        case quote(AttributedString, source: String?)
        case list(ordered: Bool, items: [AttributedString])
        case embed(Embed)
        case readAlso(ArticleSummary)
        case separator
    }

    let id: Int
    let kind: Kind

    static func make(_ blocks: [ArticleBlock]) -> [RenderedBlock] {
        blocks.enumerated().map { RenderedBlock(id: $0.offset, kind: kind(of: $0.element)) }
    }

    private static func kind(of block: ArticleBlock) -> Kind {
        switch block {
        case .paragraph(let runs): .paragraph(text(runs))
        case .heading(let level, let runs): .heading(level: level, text(runs))
        case .image(let image): .image(image)
        case .quote(let runs, let source): .quote(text(runs), source: source)
        case .list(let ordered, let items): .list(ordered: ordered, items: items.map(text))
        case .embed(let embed): .embed(embed)
        case .readAlso(let summary): .readAlso(summary)
        case .separator: .separator
        }
    }

    /// Bold, italic and links; a link is underlined (colour is never the only sign) and tinted `accentDark`.
    static func text(_ runs: [InlineRun]) -> AttributedString {
        runs.reduce(into: AttributedString()) { text, run in
            var piece = AttributedString(run.text)
            var intent: InlinePresentationIntent = []
            if run.bold { intent.insert(.stronglyEmphasized) }
            if run.italic { intent.insert(.emphasized) }
            if !intent.isEmpty { piece.inlinePresentationIntent = intent }
            if let link = run.link {
                piece.link = link
                piece.swiftUI.underlineStyle = .single
            }
            text += piece
        }
    }
}

/// One block of E11. Text blocks keep the 16 pt margins; images run edge to edge.
struct ArticleBlockView: View {
    let block: RenderedBlock.Kind
    let zoom: (ArticleImage) -> Void
    let play: (Embed) -> Void
    let read: (ArticleSummary) -> Void

    var body: some View {
        switch block {
        case .paragraph(let text):
            // 17 pt, line height about 1.5.
            Text(text).efText(.body).lineSpacing(8).foregroundStyle(EFTextColor.ink.color)
                .textSelection(.enabled)
                .padding(.horizontal, 16)
        case .heading(let level, let text):
            Text(text).efText(level <= 2 ? .title2 : .title3).foregroundStyle(EFTextColor.ink.color)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 16)
                .padding(.horizontal, 16)
        case .image(let image):
            ArticleImageView(image: image) { zoom(image) }
        case .quote(let text, let source):
            quote(text, source: source)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(ordered ? "\(index + 1)." : "•")
                        Text(item).textSelection(.enabled)
                    }
                    .efText(.body)
                    .foregroundStyle(EFTextColor.ink.color)
                }
            }
            .padding(.leading, 32)
            .padding(.trailing, 16)
        case .embed(let embed):
            EmbedCard(embed: embed) { play(embed) }.padding(.horizontal, 16)
        case .readAlso(let summary):
            readAlso(summary)
        case .separator:
            EFColorToken.line.color.frame(height: 1)
                .containerRelativeFrame(.horizontal) { width, _ in width * 0.4 }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
        }
    }

    private func quote(_ text: AttributedString, source: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            EFColorToken.accent.color.frame(width: 3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(text).efText(.body).italic().foregroundStyle(EFTextColor.ink.color)
                if let source {
                    Text(source).efText(.caption).foregroundStyle(EFTextColor.muted.color)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
    }

    private func readAlso(_ summary: ArticleSummary) -> some View {
        Button { read(summary) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lire aussi").efText(.sectionHeader).foregroundStyle(EFTextColor.accentDark.color)
                    Text(summary.title).efText(.strongLabel).foregroundStyle(EFTextColor.ink.color)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(EFColorToken.accent.color)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(EFColorToken.sky.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 16)
    }
}

/// Edge to edge, room kept at the original proportions, `thumb` while loading; the caption is its label.
private struct ArticleImageView: View {
    let image: ArticleImage
    let zoom: () -> Void

    var body: some View {
        Button(action: zoom) {
            VStack(alignment: .leading, spacing: 8) {
                EFColorToken.thumb.color
                    .aspectRatio(ratio, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: image.url) { phase in
                            if let picture = phase.image { picture.resizable().scaledToFill() }
                        }
                    }
                    .clipped()
                if let caption = image.caption {
                    Text(caption).efText(.caption).foregroundStyle(EFTextColor.muted.color)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(image.caption ?? image.alt ?? "Photo")
        .accessibilityAddTraits(.isImage)
        .accessibilityHint("Ouvre la photo en plein écran")
    }

    private var ratio: CGFloat {
        guard let width = image.width, let height = image.height, width > 0, height > 0 else { return 3 / 2 }
        return CGFloat(width) / CGFloat(height)
    }
}

/// Third-party content: nothing of it loads before the tap (NFR-005).
private struct EmbedCard: View {
    let embed: Embed
    let play: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        Button(action: play) {
            layout {
                Image(systemName: kind.symbol).font(.title2).foregroundStyle(EFColorToken.accent.color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.label).efText(.sectionHeader).foregroundStyle(EFTextColor.accentDark.color)
                    if let title = embed.title {
                        Text(title).efText(.strongLabel).foregroundStyle(EFTextColor.ink.color)
                            .multilineTextAlignment(.leading)
                    }
                    Text("\(kind.action) ↗\u{FE0E}").efText(.bodySecondary)
                        .foregroundStyle(EFTextColor.accentDark.color)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EFColorToken.card.color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(EFColorToken.line.color)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([kind.action, kind.label, embed.title].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
    }

    private struct Kind {
        let label: String, symbol: String, action: String
    }

    private var kind: Kind {
        switch embed.provider {
        case .youtube: Kind(label: "Vidéo YouTube", symbol: "play.rectangle.fill", action: "Lire la vidéo")
        case .spotify: Kind(label: "Son Spotify", symbol: "music.note", action: "Écouter")
        case .instagram:
            Kind(label: "Publication Instagram", symbol: "photo.on.rectangle", action: "Voir la publication")
        case .other: Kind(label: "Contenu externe", symbol: "link", action: "Ouvrir")
        }
    }
}

/// Full screen on `night`: pinch or double tap to zoom, drag down or « Fermer » to close.
/// Reduce Motion: no animated zoom, a fade instead of the slide.
struct ZoomedImage: View {
    let image: ArticleImage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragging: CGSize = .zero
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .bottom) {
            EFColorToken.night.color.ignoresSafeArea()
            AsyncImage(url: image.url) { phase in
                if let picture = phase.image {
                    picture.resizable().scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .scaleEffect(scale * pinch)
            .offset(shownOffset)
            .gesture(magnify)
            .simultaneousGesture(drag)
            .onTapGesture(count: 2) { setScale(scale > 1 ? 1 : 2.5) }
            .accessibilityLabel(image.caption ?? image.alt ?? "Photo")
            .accessibilityAddTraits(.isImage)
            if let caption = image.caption, scale == 1 {
                Text(caption).efText(.caption).foregroundStyle(EFTextColor.onFill.color)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EFColorToken.night.color.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button(action: close) {
                Image(systemName: "xmark").font(.title3.bold()).foregroundStyle(EFTextColor.onFill.color)
                    .frame(width: 44, height: 44)
                    .background(EFColorToken.night.color.opacity(0.7), in: Circle())
            }
            .accessibilityLabel("Fermer")
            .padding(16)
        }
        .opacity(shown || !reduceMotion ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : nil) { shown = true }
        }
        .accessibilityAction(.escape, close)
    }

    private var shownOffset: CGSize {
        if scale == 1 { return CGSize(width: 0, height: max(dragging.height, 0)) }
        return CGSize(width: offset.width + dragging.width, height: offset.height + dragging.height)
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, pinch, _ in pinch = value.magnification }
            .onEnded { value in setScale(min(max(scale * value.magnification, 1), 4)) }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { dragging = $0.translation }
            .onEnded { value in
                if scale == 1, value.translation.height > 120 { return close() }
                if scale > 1 {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { dragging = .zero }
            }
    }

    private func setScale(_ value: CGFloat) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            scale = value
            if value == 1 { offset = .zero }
        }
    }

    private func close() {
        var transaction = Transaction()
        transaction.disablesAnimations = reduceMotion
        withTransaction(transaction) { dismiss() }
    }
}
