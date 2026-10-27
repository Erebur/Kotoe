//
//  RichTextLabel.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  A read-only label for attributed text, plus the scrollable preview used by
//  the rich text field's split and preview display modes. Unlike SwiftUI's
//  `Text`, the native label renders inline images, which the markdown
//  formatter uses to embed typeset LaTeX math on study cards.
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

// MARK: - Scrollable preview

/// A scrollable preview of rendered rich text. It replaces a SwiftUI
/// `ScrollView` so the split mode can sync its offset with the editor pane and
/// so the macOS momentum gate applies here too.
///
/// `bottomInset` and `trailingInset` leave room for the floating mode switch
/// and the info button, matching the editor's padding.
struct RichTextPreview: View {

    let attributedText: NSAttributedString
    var bottomInset: CGFloat = 0
    var trailingInset: CGFloat = 0
    var sync: SplitScrollSync?

    var body: some View {
        ScrollablePreviewLabel(
            attributedText: attributedText,
            bottomInset: bottomInset,
            trailingInset: trailingInset,
            sync: sync
        )
    }
}

// MARK: - macOS preview

#if os(macOS)

/// Flipped document view so the label sits at the top and scrolling starts
/// there, like the text view the editor uses.
private final class PreviewDocumentView: NSView {

    override var isFlipped: Bool { true }
}

private final class PreviewScrollView: RichTextScrollView {

    /// Called after the scroll view's size changes so the label can re-wrap.
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }
}

private struct ScrollablePreviewLabel: NSViewRepresentable {

    let attributedText: NSAttributedString
    let bottomInset: CGFloat
    let trailingInset: CGFloat
    let sync: SplitScrollSync?

    /// Text inset used by the editor, so preview and editor text line up.
    private static let textInset = NSSize(width: 13, height: 11)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = PreviewScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false

        let container = PreviewDocumentView()
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
        container.addSubview(label)
        scrollView.documentView = container

        let coordinator = context.coordinator
        coordinator.label = label
        coordinator.container = container
        coordinator.attributedText = attributedText
        coordinator.trailingInset = trailingInset
        coordinator.bottomInset = bottomInset
        coordinator.apply(to: scrollView)

        coordinator.sync = sync
        sync?.attach(scrollView, as: .preview)

        scrollView.onLayout = { [weak scrollView, weak coordinator] in
            guard let scrollView, let coordinator else { return }
            coordinator.apply(to: scrollView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.attributedText = attributedText
        coordinator.trailingInset = trailingInset
        coordinator.bottomInset = bottomInset
        coordinator.apply(to: scrollView)

        if coordinator.sync !== sync {
            coordinator.sync?.detach(scrollView)
            coordinator.sync = sync
            sync?.attach(scrollView, as: .preview)
        }
    }

    static func dismantleNSView(
        _ scrollView: NSScrollView,
        coordinator: Coordinator
    ) {
        coordinator.sync?.detach(scrollView)
        coordinator.sync = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {

        weak var label: NSTextField?
        weak var container: NSView?
        var attributedText = NSAttributedString()
        var trailingInset: CGFloat = 0
        var bottomInset: CGFloat = 0
        var sync: SplitScrollSync?
        private var isApplying = false

        func apply(to scrollView: NSScrollView) {
            guard !isApplying else { return }
            isApplying = true
            defer { isApplying = false }

            let insets = NSEdgeInsets(
                top: 0,
                left: 0,
                bottom: bottomInset,
                right: 0
            )
            if scrollView.contentInsets.bottom != insets.bottom {
                scrollView.contentInsets = insets
            }
            guard let label, let container else { return }
            guard scrollView.contentSize.width > 0 else { return }

            if label.attributedStringValue != attributedText {
                label.attributedStringValue = attributedText
            }

            let available = scrollView.contentSize.width
                - ScrollablePreviewLabel.textInset.width * 2
                - trailingInset
            let width = max(available, 1)
            label.preferredMaxLayoutWidth = width

            let fitted = label.cell?.cellSize(
                forBounds: NSRect(
                    x: 0,
                    y: 0,
                    width: width,
                    height: CGFloat.greatestFiniteMagnitude
                )
            ) ?? .zero

            let textHeight = ceil(fitted.height)
            let inset = ScrollablePreviewLabel.textInset
            let containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: textHeight + inset.height * 2
            )

            if label.frame.size.width != width
                || label.frame.size.height != textHeight {
                label.frame = NSRect(
                    x: inset.width,
                    y: inset.height,
                    width: width,
                    height: textHeight
                )
            }
            if container.frame.size != containerSize {
                container.frame = NSRect(origin: .zero, size: containerSize)
            }
        }
    }
}

#else

// MARK: - iOS preview

private final class PreviewScrollView: UIScrollView {

    /// Called after the scroll view's size changes so the label can re-wrap.
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

private struct ScrollablePreviewLabel: UIViewRepresentable {

    let attributedText: NSAttributedString
    let bottomInset: CGFloat
    let trailingInset: CGFloat
    let sync: SplitScrollSync?

    /// Text inset used by the editor, so preview and editor text line up.
    private static let textInset = UIEdgeInsets(
        top: 11,
        left: 13,
        bottom: 11,
        right: 13
    )

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = PreviewScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never

        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        label.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        scrollView.addSubview(label)

        let coordinator = context.coordinator
        coordinator.label = label
        coordinator.attributedText = attributedText
        coordinator.trailingInset = trailingInset
        coordinator.bottomInset = bottomInset
        coordinator.apply(to: scrollView)

        coordinator.sync = sync
        sync?.attach(scrollView, as: .preview)

        scrollView.onLayout = { [weak scrollView, weak coordinator] in
            guard let scrollView, let coordinator else { return }
            coordinator.apply(to: scrollView)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.attributedText = attributedText
        coordinator.trailingInset = trailingInset
        coordinator.bottomInset = bottomInset
        coordinator.apply(to: scrollView)

        if coordinator.sync !== sync {
            coordinator.sync?.detach(scrollView)
            coordinator.sync = sync
            sync?.attach(scrollView, as: .preview)
        }
    }

    static func dismantleUIView(
        _ scrollView: UIScrollView,
        coordinator: Coordinator
    ) {
        coordinator.sync?.detach(scrollView)
        coordinator.sync = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {

        weak var label: UILabel?
        var attributedText = NSAttributedString()
        var trailingInset: CGFloat = 0
        var bottomInset: CGFloat = 0
        var sync: SplitScrollSync?
        private var isApplying = false

        func apply(to scrollView: UIScrollView) {
            guard !isApplying else { return }
            isApplying = true
            defer { isApplying = false }

            let insets = UIEdgeInsets(
                top: 0,
                left: 0,
                bottom: bottomInset,
                right: 0
            )
            if scrollView.contentInset.bottom != insets.bottom {
                scrollView.contentInset = insets
            }
            guard let label else { return }
            guard scrollView.bounds.width > 0 else { return }

            if label.attributedText != attributedText {
                label.attributedText = attributedText
            }

            let inset = ScrollablePreviewLabel.textInset
            let width = max(
                scrollView.bounds.width - inset.left - inset.right
                    - trailingInset,
                1
            )
            let fitted = label.sizeThatFits(
                CGSize(
                    width: width,
                    height: CGFloat.greatestFiniteMagnitude
                )
            )

            let textHeight = ceil(fitted.height)
            if label.frame.size.width != width
                || label.frame.size.height != textHeight {
                label.frame = CGRect(
                    x: inset.left,
                    y: inset.top,
                    width: width,
                    height: textHeight
                )
            }

            let contentSize = CGSize(
                width: scrollView.bounds.width,
                height: textHeight + inset.top + inset.bottom
            )
            if scrollView.contentSize != contentSize {
                scrollView.contentSize = contentSize
            }
        }
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
