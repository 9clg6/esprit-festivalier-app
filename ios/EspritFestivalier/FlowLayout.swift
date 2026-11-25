import SwiftUI

/// Left-to-right chips that wrap onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        place(in: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = place(in: bounds.width, subviews: subviews)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func place(in width: CGFloat, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var column: CGFloat = 0
        var row: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if column > 0, column + size.width > width {
                column = 0
                row += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: column, y: row))
            column += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, column - spacing)
        }
        return (origins, CGSize(width: maxX, height: row + rowHeight))
    }
}
