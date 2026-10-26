//
//  RichTextField.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//
//  A general rich text input that works on iOS and macOS. Edits are kept as
//  `NSAttributedString` — the same Foundation type on both platforms — which
//  round-trips through RTF, so formatting survives storage and iCloud sync
//  on every device.
//
//  Formatting is derived from plain-text markdown conventions (see
//  `MarkdownFormatter`): lists, headings, quotes, bold/italic/code, links, and
//  LaTeX math. There are no formatting buttons.
//
//  While editing, only *attributes* are applied. The characters of the source
//  are never replaced, so the insertion point, selection, undo history,
//  autocorrection, and input methods behave exactly like a native text view.
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Rich text field

/// A multiline rich text input. `attributedText` is the single source of
/// truth and is kept in sync with the native text view in both directions.
///
/// Content grows up to `maxHeight` and scrolls inside the field beyond it.
struct RichTextField: View {

    let placeholder: LocalizedStringKey
    @Binding var attributedText: NSAttributedString

    /// Tint used for the focused border.
    var tint: Color = KotoeTheme.accent

    /// Minimum and maximum height of the editable area.
    var minHeight: CGFloat = 0
    var maxHeight: CGFloat = .greatestFiniteMagnitude

    /// Call `onSubmit` on Return instead of inserting a line break. Used for
    /// single-line inputs such as a typed study answer.
    var submitsOnReturn: Bool = false
    var onSubmit: () -> Void = {}

    @State private var isFocused = false
    @State private var editorHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            RichTextEditor(
                attributedText: $attributedText,
                isFocused: $isFocused,
                height: $editorHeight,
                submitsOnReturn: submitsOnReturn,
                onSubmit: onSubmit
            )
            .frame(height: clampedHeight)

            if attributedText.string.isEmpty && !isFocused {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .allowsHitTesting(false)
            }
        }
        .background(
            KotoeTheme.fieldBackground,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused ? tint.opacity(0.7) : KotoeTheme.hairline,
                    lineWidth: isFocused ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var clampedHeight: CGFloat {
        min(max(editorHeight, minHeight), maxHeight)
    }
}

// MARK: - List continuation

/// Computes the edit that pressing Return performs inside a markdown list.
/// Pressing Return on an empty item removes the marker; on a filled item it
/// starts the next bullet, number, or unchecked task.
enum MarkdownListContinuation {

    struct Edit {
        let range: NSRange
        let replacement: String
    }

    private static let pattern =
        #"^([ \t]*)([-*+]|[0-9]+\.)([ \t]+)(?:\[([ xX])\]([ \t]+))?(.*)$"#

    static func edit(for text: NSString, selection: NSRange) -> Edit? {
        guard selection.length == 0 else { return nil }

        let lineRange = text.lineRange(
            for: NSRange(location: selection.location, length: 0)
        )
        let lineStart = lineRange.location
        guard selection.location >= lineStart else { return nil }

        let prefixLength = selection.location - lineStart
        let prefix = text.substring(
            with: NSRange(location: lineStart, length: prefixLength)
        )

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: prefix,
                options: [],
                range: NSRange(location: 0, length: (prefix as NSString).length)
            )
        else { return nil }

        func group(_ index: Int) -> String? {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { return nil }
            return (prefix as NSString).substring(with: range)
        }

        let indent = group(1) ?? ""
        let marker = group(2) ?? "-"
        let isTask = group(4) != nil
        let content = group(6) ?? ""

        // Pressing Return on an empty item ends the list.
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return Edit(
                range: NSRange(location: lineStart, length: prefixLength),
                replacement: ""
            )
        }

        let nextMarker: String
        if isTask {
            nextMarker = "- [ ]"
        } else if marker.hasSuffix("."),
                  let number = Int(marker.dropLast()) {
            nextMarker = "\(number + 1)."
        } else {
            nextMarker = marker
        }

        return Edit(
            range: NSRange(location: selection.location, length: 0),
            replacement: "\n\(indent)\(nextMarker) "
        )
    }

    /// The insertion point after applying `edit` at `location`.
    static func selection(after edit: Edit, at location: Int) -> NSRange {
        let inserted = (edit.replacement as NSString).length
        return NSRange(location: location + inserted, length: 0)
    }
}

// MARK: - Native text editor (macOS)

#if os(macOS)

struct RichTextEditor: NSViewRepresentable {

    @Binding var attributedText: NSAttributedString
    @Binding var isFocused: Bool
    @Binding var height: CGFloat
    let submitsOnReturn: Bool
    let onSubmit: () -> Void

    static var systemFont: FormatFont {
        NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }

    static var style: MarkdownFormatter.Style {
        MarkdownFormatter.Style(baseFont: systemFont)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = Self.systemFont
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticTextCompletionEnabled = true
        textView.isAutomaticLinkDetectionEnabled = true

        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 13, height: 11)
        textView.typingAttributes = MarkdownFormatter.typingAttributes(for: Self.style)

        scrollView.documentView = textView

        context.coordinator.textView = textView
        textView.delegate = context.coordinator

        if textView.textStorage?.string != attributedText.string {
            textView.textStorage?.setAttributedString(attributedText)
        }
        context.coordinator.bindings = self
        DispatchQueue.main.async {
            context.coordinator.restyle()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        context.coordinator.bindings = self

        if !context.coordinator.isProgrammaticChange {
            let current = textView.textStorage?.string ?? ""
            if current != attributedText.string {
                context.coordinator.isProgrammaticChange = true
                textView.textStorage?.setAttributedString(attributedText)
                context.coordinator.isProgrammaticChange = false

                DispatchQueue.main.async {
                    context.coordinator.restyle()
                }
            }
        }

        context.coordinator.reportHeight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {

        weak var textView: NSTextView?
        var bindings: RichTextEditor?
        var isProgrammaticChange = false

        /// Re-applies markdown attributes without touching a single character.
        func restyle() {
            guard let textView, let bindings else { return }
            guard !textView.hasMarkedText() else { return }
            guard let storage = textView.textStorage else { return }

            let style = RichTextEditor.style
            let styled = MarkdownFormatter.styledSource(
                storage.string,
                style: style
            )
            guard styled.length == storage.length else { return }

            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()
            styled.enumerateAttributes(in: fullRange, options: []) {
                attributes,
                range,
                _ in
                storage.setAttributes(attributes, range: range)
            }
            storage.endEditing()

            textView.typingAttributes = MarkdownFormatter.typingAttributes(
                for: style
            )

            bindings.attributedText = storage.attributedSubstring(
                from: fullRange
            )

            reportHeight()
        }

        func reportHeight() {
            guard let textView, let bindings else { return }
            guard let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else { return }

            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container).height
            let fitted = used + textView.textContainerInset.height * 2

            DispatchQueue.main.async {
                if abs(fitted - bindings.height) > 0.5 {
                    bindings.height = fitted
                }
            }
        }

        // MARK: NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticChange else { return }
            restyle()
        }

        func textDidBeginEditing(_ notification: Notification) {
            guard let bindings else { return }
            bindings.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let bindings else { return }
            bindings.isFocused = false
        }

        func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:))
            else { return false }
            guard let bindings else { return false }

            if bindings.submitsOnReturn {
                bindings.onSubmit()
                return true
            }

            let selection = textView.selectedRange()
            guard let edit = MarkdownListContinuation.edit(
                for: textView.string as NSString,
                selection: selection
            ) else { return false }

            textView.replaceCharacters(
                in: edit.range,
                with: edit.replacement
            )
            textView.setSelectedRange(
                MarkdownListContinuation.selection(
                    after: edit,
                    at: edit.range.location
                )
            )
            return true
        }
    }
}

#else

// MARK: - Native text editor (iOS)

struct RichTextEditor: UIViewRepresentable {

    @Binding var attributedText: NSAttributedString
    @Binding var isFocused: Bool
    @Binding var height: CGFloat
    let submitsOnReturn: Bool
    let onSubmit: () -> Void

    static var systemFont: FormatFont {
        UIFont.preferredFont(forTextStyle: .body)
    }

    static var style: MarkdownFormatter.Style {
        MarkdownFormatter.Style(baseFont: systemFont)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = false
        textView.textContainerInset = UIEdgeInsets(
            top: 11,
            left: 13,
            bottom: 11,
            right: 13
        )
        textView.textContainer.lineFragmentPadding = 0
        textView.font = Self.systemFont

        // Native text features stay on: autocorrection, spell checking,
        // smart punctuation, inline predictions and the undo stack.
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.smartQuotesType = .default
        textView.smartDashesType = .default
        textView.smartInsertDeleteType = .default
        textView.allowsEditingTextAttributes = true
        textView.typingAttributes = MarkdownFormatter.typingAttributes(
            for: Self.style
        )

        textView.delegate = context.coordinator

        if textView.attributedText.string != attributedText.string {
            textView.attributedText = attributedText
        }
        context.coordinator.textView = textView
        context.coordinator.bindings = self
        DispatchQueue.main.async {
            context.coordinator.restyle()
        }

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.textView = textView
        context.coordinator.bindings = self

        if !context.coordinator.isProgrammaticChange {
            if textView.attributedText.string != attributedText.string {
                context.coordinator.isProgrammaticChange = true
                textView.attributedText = attributedText
                context.coordinator.isProgrammaticChange = false

                DispatchQueue.main.async {
                    context.coordinator.restyle()
                }
            }
        }

        context.coordinator.reportHeight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {

        weak var textView: UITextView?
        var bindings: RichTextEditor?
        var isProgrammaticChange = false

        /// Re-applies markdown attributes without touching a single character.
        func restyle() {
            guard let textView, let bindings else { return }
            guard textView.markedTextRange == nil else { return }

            let storage = textView.textStorage
            let style = RichTextEditor.style
            let styled = MarkdownFormatter.styledSource(
                storage.string,
                style: style
            )
            guard styled.length == storage.length else { return }

            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()
            styled.enumerateAttributes(in: fullRange, options: []) {
                attributes,
                range,
                _ in
                storage.setAttributes(attributes, range: range)
            }
            storage.endEditing()

            textView.typingAttributes = MarkdownFormatter.typingAttributes(
                for: style
            )

            bindings.attributedText = storage.attributedSubstring(
                from: fullRange
            )

            reportHeight()
        }

        func reportHeight() {
            guard let textView, let bindings else { return }

            let fitted = textView.sizeThatFits(
                CGSize(
                    width: textView.bounds.width,
                    height: CGFloat.greatestFiniteMagnitude
                )
            ).height

            DispatchQueue.main.async {
                if abs(fitted - bindings.height) > 0.5 {
                    bindings.height = fitted
                }
            }
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange else { return }
            restyle()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            guard let bindings else { return }
            bindings.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard let bindings else { return }
            bindings.isFocused = false
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == "\n" else { return true }

            if let bindings, bindings.submitsOnReturn {
                bindings.onSubmit()
                return false
            }

            guard let edit = MarkdownListContinuation.edit(
                for: textView.text as NSString,
                selection: range
            ) else { return true }

            guard
                let start = textView.position(
                    from: textView.beginningOfDocument,
                    offset: edit.range.location
                ),
                let end = textView.position(
                    from: start,
                    offset: edit.range.length
                ),
                let textRange = textView.textRange(from: start, to: end)
            else { return true }

            textView.replace(textRange, withText: edit.replacement)
            textView.selectedRange = MarkdownListContinuation.selection(
                after: edit,
                at: edit.range.location
            )
            return false
        }
    }
}

#endif

// MARK: - RTF serialization

extension NSAttributedString {

    /// RTF representation of the attributed string, or `nil` if encoding
    /// fails. RTF is the shared attributed-text format on iOS and macOS.
    var rtfData: Data? {
        try? data(
            from: NSRange(location: 0, length: length),
            documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtf
            ]
        )
    }
}

// MARK: - Previews

#Preview("Rich Text Field") {
    let attributed = NSAttributedString(
        string: """
        # Heading

        Type here. Markdown works:

        * first item
        * second item

        **bold**, *italic*, `code`, and $x^2 + y^2 = z^2$.
        """
    )

    return VStack(alignment: .leading, spacing: 20) {
        RichTextField(
            placeholder: "shared.content.empty",
            attributedText: .constant(attributed),
            minHeight: 160,
            maxHeight: 300
        )
        .frame(width: 360)

        RichTextField(
            placeholder: "cardEditor.front.textPlaceholder",
            attributedText: .constant(
                NSAttributedString(string: "Formatted text")
            ),
            tint: KotoeTheme.palette[3]
        )
        .frame(width: 360)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KotoeTheme.windowBackground)
}
