//
//  RichTextLabel.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  A read-only label for attributed text. Unlike SwiftUI's `Text`, the native
//  label renders inline images, which the markdown formatter uses to embed
//  typeset LaTeX math on study cards.
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct RichTextLabel: View {

    let attributedText: NSAttributedString
    var alignment: NSTextAlignment = .center

    var body: some View {
        PlatformAttributedLabel(
            attributedText: attributedText,
            alignment: alignment
        )
    }
}

// MARK: - macOS

#if os(macOS)

private struct PlatformAttributedLabel: NSViewRepresentable {

    let attributedText: NSAttributedString
    let alignment: NSTextAlignment

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: "")
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        return label
    }

    func updateNSView(_ label: NSTextField, context: Context) {
        label.attributedStringValue = attributedText
        label.alignment = alignment
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSTextField,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        nsView.preferredMaxLayoutWidth = width

        guard let cell = nsView.cell else { return nil }
        let size = cell.cellSize(
            forBounds: NSRect(
                x: 0,
                y: 0,
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        return CGSize(width: width, height: ceil(size.height))
    }
}

#else

// MARK: - iOS

private struct PlatformAttributedLabel: UIViewRepresentable {

    let attributedText: NSAttributedString
    let alignment: NSTextAlignment

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.attributedText = attributedText
        label.textAlignment = alignment
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UILabel,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        let size = uiView.sizeThatFits(
            CGSize(
                width: width,
                height: CGFloat.greatestFiniteMagnitude
            )
        )
        return CGSize(width: width, height: ceil(size.height))
    }
}

#endif

// MARK: - Preview

#Preview("Rendered Rich Text") {
    let text = """
    # Photosynthesis

    Plants convert **light** into *chemical* energy:

    * light-dependent reactions
    * Calvin cycle

    $$6CO_2 + 6H_2O \\rightarrow C_6H_{12}O_6 + 6O_2$$
    """

    return RichTextLabel(
        attributedText: MarkdownFormatter.rendered(
            text,
            style: MarkdownFormatter.Style(
                baseFont: MarkdownFormatter.systemFont,
                alignment: .center,
                rendersMath: true
            )
        )
    )
    .padding(24)
    .frame(width: 360)
}
