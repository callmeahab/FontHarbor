// Copyright (C) 2026 Font Harbor contributors
// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import SwiftUI

extension FontCategory {
    var design: Font.Design {
        switch self {
        case .sansSerif: .default
        case .serif: .serif
        case .monospace: .monospaced
        case .display: .rounded
        }
    }
}

extension FontSource {
    var color: Color {
        switch self {
        case .googleFonts: .blue
        case .fontshare: .purple
        case .league: .orange
        case .adobe: .red
        case .jetBrains: .pink
        case .mozilla: .indigo
        case .nerdFonts: .green
        case .community: .teal
        }
    }
}

extension SpecimenTheme {
    var background: Color {
        switch self {
        case .paper: Color(red: 0.95, green: 0.92, blue: 0.84)
        case .midnight: Color(red: 0.055, green: 0.07, blue: 0.12)
        case .ink: Color(red: 0.12, green: 0.12, blue: 0.12)
        case .cobalt: Color(red: 0.04, green: 0.19, blue: 0.62)
        }
    }

    var foreground: Color {
        switch self {
        case .paper: Color(red: 0.12, green: 0.10, blue: 0.08)
        case .midnight: Color(red: 0.88, green: 0.92, blue: 1)
        case .ink: .white
        case .cobalt: .white
        }
    }
}


/// Keep metadata tags inside the card while preserving natural capsule widths.
struct WrappingTagsLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for (view, point) in zip(subviews, result.points) {
            view.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let limit = width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        var points: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > limit {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width ?? usedWidth, height: y + rowHeight), points)
    }
}
