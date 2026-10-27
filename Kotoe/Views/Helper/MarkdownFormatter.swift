//
//  MarkdownFormatter.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  Converts plain text with lightweight markdown conventions into
//  `NSAttributedString`s. The app has two consumers:
//
//  - `styledSource` styles the text the user is editing. It never changes a
//    single character, only attributes, so the selection, undo stack,
//    autocorrection and input methods of the native text view keep working.
//    Markdown markers stay visible but are dimmed.
//  - `rendered` produces the formatted output shown on study cards. Markers
//    are removed, lists become real bullets, and LaTeX is typeset with
//    SwiftMath and embedded as an image.
//
//  Supported conventions:
//  - `# ` … `###### ` headings
//  - `* `, `- `, `+ ` bullets, `1. ` ordered lists, `- [ ]` / `- [x]` tasks
//  - `> ` block quotes
//  - `---` horizontal rules
//  - ` ``` ` fenced code blocks and `` `code` `` spans
//  - `**bold**`, `*italic*`, `~~strikethrough~~`
//  - `[label](url)` links
//  - `$inline math$` and `$$display math$$`
//

import Foundation
import SwiftMath

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Platform aliases

#if os(macOS)
typealias FormatFont = NSFont
typealias FormatColor = NSColor
typealias PlatformImage = NSImage
#else
typealias FormatFont = UIFont
typealias FormatColor = UIColor
typealias PlatformImage = UIImage
#endif

// MARK: - Colors

enum MarkdownColors {

    static var label: FormatColor {
#if os(macOS)
        NSColor.labelColor
#else
        UIColor.label
#endif
    }

    static var secondary: FormatColor {
#if os(macOS)
        NSColor.secondaryLabelColor
#else
        UIColor.secondaryLabel
#endif
    }

    static var tertiary: FormatColor {
#if os(macOS)
        NSColor.tertiaryLabelColor
#else
        UIColor.tertiaryLabel
#endif
    }

    static var accent: FormatColor {
#if os(macOS)
        NSColor.systemBlue
#else
        UIColor.systemBlue
#endif
    }

    static var codeBackground: FormatColor {
        FormatColor(white: 0.5, alpha: 0.14)
    }

    static var mathBackground: FormatColor {
        accent.withAlphaComponent(0.10)
    }
}

// MARK: - Markdown formatter

enum MarkdownFormatter {

    // MARK: Style

    /// Fonts and colors used while formatting. The editor passes the platform
    /// text-view font, study cards pass the card font.
    struct Style {

        var baseFont: FormatFont
        var textColor: FormatColor
        var secondaryColor: FormatColor
        var tertiaryColor: FormatColor
        var accentColor: FormatColor

        var alignment: NSTextAlignment
        var lineSpacing: CGFloat
        var paragraphSpacing: CGFloat

        /// Typeset `$…$` regions into images. Only used for rendered output;
        /// the editor keeps their source visible.
        var rendersMath: Bool

        /// Picks the syntax color theme for fenced code blocks.
        var appearance: MarkdownAppearance

        init(
            baseFont: FormatFont,
            textColor: FormatColor = MarkdownColors.label,
            secondaryColor: FormatColor = MarkdownColors.secondary,
            tertiaryColor: FormatColor = MarkdownColors.tertiary,
            accentColor: FormatColor = MarkdownColors.accent,
            alignment: NSTextAlignment = .natural,
            lineSpacing: CGFloat = 2,
            paragraphSpacing: CGFloat = 2,
            rendersMath: Bool = false,
            appearance: MarkdownAppearance = .light
        ) {
            self.baseFont = baseFont
            self.textColor = textColor
            self.secondaryColor = secondaryColor
            self.tertiaryColor = tertiaryColor
            self.accentColor = accentColor
            self.alignment = alignment
            self.lineSpacing = lineSpacing
            self.paragraphSpacing = paragraphSpacing
            self.rendersMath = rendersMath
            self.appearance = appearance
        }
    }

    /// The system font used when no view-specific font is available.
    static var systemFont: FormatFont {
#if os(macOS)
        NSFont.systemFont(ofSize: NSFont.systemFontSize)
#else
        UIFont.preferredFont(forTextStyle: .body)
#endif
    }

    /// Default attributes for newly typed text in the editor.
    static func typingAttributes(for style: Style) -> [NSAttributedString.Key: Any] {
        baseAttributes(style)
    }

    // MARK: Source (editor)

    /// Styles the raw markdown source without changing any characters.
    ///
    /// Because the returned string has exactly the same text as the input,
    /// the attributes can be applied to an existing text storage run by run
    /// without moving the insertion point.
    static func styledSource(_ text: String, style: Style) -> NSAttributedString {
        let output = NSMutableAttributedString(string: text)
        guard output.length > 0 else { return output }

        let fullRange = NSRange(location: 0, length: output.length)
        output.setAttributes(baseAttributes(style), range: fullRange)

        let verbatimRanges = styleBlocks(in: output, style: style)
        styleInline(in: output, avoiding: verbatimRanges, style: style)

        return output
    }

    // MARK: Rendered (cards)

    /// Produces the formatted output shown to the user: markers removed,
    /// lists turned into bullets, and math typeset when `rendersMath` is set.
    static func rendered(
        _ text: String,
        style: Style,
        highlightingCode: Bool = true
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let rawLines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var inFence = false
        var fenceLanguage: String?
        var codeLines: [String] = []
        var hasContent = false
        var newlineAttributes = baseAttributes(style)

        // Lines collected for a display math block that spans several lines.
        var mathBlock: [String]?

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            // Inside a $$ block every line belongs to the math until a line
            // closes the block with $$. A single-line $$…$$ is handled below
            // as ordinary inline math.
            if mathBlock != nil {
                if let close = trimmed.range(of: "$$") {
                    var block = mathBlock ?? []
                    block.append(
                        String(trimmed[trimmed.startIndex..<close.lowerBound])
                    )
                    appendDisplayMath(
                        block,
                        to: output,
                        style: style,
                        hasContent: &hasContent
                    )
                    mathBlock = nil
                    newlineAttributes = baseAttributes(style)

                    // Text after the closing $$ on the same line is normal
                    // text and starts a new line.
                    let remainder = String(trimmed[close.upperBound...])
                    if !remainder.isEmpty {
                        if hasContent {
                            output.append(
                                NSAttributedString(
                                    string: "\n",
                                    attributes: newlineAttributes
                                )
                            )
                        }
                        appendRenderedLine(remainder, to: output, style: style)
                        hasContent = true
                    }
                } else {
                    mathBlock?.append(rawLine)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                if inFence {
                    appendCodeBlock(
                        codeLines,
                        language: fenceLanguage,
                        to: output,
                        style: style,
                        highlightingCode: highlightingCode,
                        hasContent: &hasContent,
                        newlineAttributes: &newlineAttributes
                    )
                    codeLines = []
                    fenceLanguage = nil
                } else {
                    fenceLanguage = infoLanguage(from: trimmed)
                }
                inFence.toggle()
                continue
            }

            if inFence {
                codeLines.append(rawLine)
                continue
            }

            // An opening $$ without a closing $$ on the same line starts a
            // block that continues until the closing $$.
            if trimmed.hasPrefix("$$"),
               !trimmed.dropFirst(2).contains("$$") {
                mathBlock = [String(trimmed.dropFirst(2))]
                continue
            }

            if hasContent {
                output.append(
                    NSAttributedString(
                        string: "\n",
                        attributes: newlineAttributes
                    )
                )
            }

            let lineStart = output.length

            appendRenderedLine(rawLine, to: output, style: style)

            if output.length > lineStart {
                newlineAttributes = output.attributes(
                    at: lineStart,
                    effectiveRange: nil
                )
            } else {
                newlineAttributes = baseAttributes(style)
            }

            hasContent = true
        }

        // An unterminated fence still shows its code, highlighted.
        if inFence {
            appendCodeBlock(
                codeLines,
                language: fenceLanguage,
                to: output,
                style: style,
                highlightingCode: highlightingCode,
                hasContent: &hasContent,
                newlineAttributes: &newlineAttributes
            )
        }

        // An unterminated $$ block still shows its math.
        if let mathBlock {
            appendDisplayMath(
                mathBlock,
                to: output,
                style: style,
                hasContent: &hasContent
            )
        }

        return output
    }

    /// Plain text with all markdown markers removed. Used for summaries and
    /// for judging typed answers.
    static func plainText(from text: String) -> String {
        let style = Style(baseFont: systemFont, rendersMath: false)
        return rendered(text, style: style, highlightingCode: false).string
    }

    // MARK: - Base attributes

    static func baseAttributes(_ style: Style) -> [NSAttributedString.Key: Any] {
        [
            .font: style.baseFont,
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraphStyle(style, headIndent: 0),
        ]
    }

    private static func paragraphStyle(
        _ style: Style,
        headIndent: CGFloat
    ) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = style.alignment
        paragraph.lineSpacing = style.lineSpacing
        paragraph.paragraphSpacing = style.paragraphSpacing
        paragraph.headIndent = headIndent
        return paragraph
    }

    // MARK: - Fonts

    private static func boldFont(_ font: FormatFont) -> FormatFont {
#if os(macOS)
        NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
#else
        withTrait(.traitBold, font)
#endif
    }

    private static func boldFont(size: CGFloat) -> FormatFont {
#if os(macOS)
        NSFont.boldSystemFont(ofSize: size)
#else
        UIFont.boldSystemFont(ofSize: size)
#endif
    }

    private static func italicFont(_ font: FormatFont) -> FormatFont {
#if os(macOS)
        NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
#else
        withTrait(.traitItalic, font)
#endif
    }

#if !os(macOS)
    /// Adds a trait while keeping the font's other traits and design, so bold
    /// and italic combine and a monospaced font stays monospaced.
    private static func withTrait(
        _ trait: UIFontDescriptor.SymbolicTraits,
        _ font: UIFont
    ) -> UIFont {
        let traits = font.fontDescriptor.symbolicTraits.union(trait)

        guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        else { return font }

        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
#endif

    private static func monospacedFont(_ font: FormatFont) -> FormatFont {
#if os(macOS)
        NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
#else
        UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
#endif
    }

    private static func headingScale(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 1.55
        case 2: return 1.35
        case 3: return 1.2
        default: return 1.08
        }
    }

    // MARK: - Source block styling

    private static func styleBlocks(
        in output: NSMutableAttributedString,
        style: Style
    ) -> [NSRange] {
        let ns = output.string as NSString
        var index = 0
        var inFence = false
        var fenceLanguage: String?
        var codeStart: Int?
        var verbatimRanges: [NSRange] = []

        while index < ns.length {
            var start = 0
            var end = 0
            var contentsEnd = 0
            ns.getLineStart(
                &start,
                end: &end,
                contentsEnd: &contentsEnd,
                for: NSRange(location: index, length: 0)
            )

            let contentRange = NSRange(
                location: start,
                length: max(0, contentsEnd - start)
            )
            let line = ns.substring(with: contentRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inFence, let codeStart {
                    applyCodeHighlight(
                        output,
                        range: NSRange(
                            location: codeStart,
                            length: contentRange.location - codeStart
                        ),
                        language: fenceLanguage,
                        style: style
                    )
                }
                if inFence {
                    codeStart = nil
                    fenceLanguage = nil
                } else {
                    fenceLanguage = infoLanguage(from: trimmed)
                }
                output.addAttribute(
                    .foregroundColor,
                    value: style.secondaryColor,
                    range: contentRange
                )
                verbatimRanges.append(
                    NSRange(location: start, length: end - start)
                )
                inFence.toggle()
                index = end
                continue
            }

            if inFence {
                applyCodeLineStyle(output, range: contentRange)
                if codeStart == nil {
                    codeStart = start
                }
                verbatimRanges.append(
                    NSRange(location: start, length: end - start)
                )
                index = end
                continue
            }

            if let heading = headingPrefix(in: line) {
                let size = style.baseFont.pointSize * headingScale(heading.level)
                output.addAttributes(
                    [
                        .font: boldFont(size: size),
                        .foregroundColor: style.textColor,
                    ],
                    range: contentRange
                )
                output.addAttribute(
                    .foregroundColor,
                    value: style.secondaryColor,
                    range: NSRange(
                        location: contentRange.location,
                        length: heading.length
                    )
                )
            } else if isHorizontalRule(trimmed) {
                output.addAttribute(
                    .foregroundColor,
                    value: style.tertiaryColor,
                    range: contentRange
                )
            } else if let marker = listMarkerLength(in: line) {
                output.addAttribute(
                    .foregroundColor,
                    value: style.accentColor,
                    range: NSRange(
                        location: contentRange.location,
                        length: marker
                    )
                )
                // A `*` bullet must not open an italic span.
                verbatimRanges.append(
                    NSRange(location: contentRange.location, length: marker)
                )
                output.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle(style, headIndent: 18),
                    range: contentRange
                )
            } else if let quote = quoteMarkerLength(in: line) {
                output.addAttribute(
                    .foregroundColor,
                    value: style.secondaryColor,
                    range: NSRange(
                        location: contentRange.location,
                        length: quote
                    )
                )
                output.addAttribute(
                    .paragraphStyle,
                    value: paragraphStyle(style, headIndent: 12),
                    range: contentRange
                )
            }

            index = end
        }

        // An unterminated fence still gets its code highlighted.
        if inFence, let codeStart {
            applyCodeHighlight(
                output,
                range: NSRange(
                    location: codeStart,
                    length: ns.length - codeStart
                ),
                language: fenceLanguage,
                style: style
            )
        }

        return verbatimRanges
    }

    private static func applyCodeLineStyle(
        _ output: NSMutableAttributedString,
        range: NSRange
    ) {
        guard range.length > 0 else { return }
        let font =
            output.attribute(.font, at: range.location, effectiveRange: nil)
            as? FormatFont
        output.addAttributes(
            [
                .font: monospacedFont(font ?? systemFont),
                .backgroundColor: MarkdownColors.codeBackground,
            ],
            range: range
        )
    }

    // MARK: - Source inline styling

    /// Runs inline styling only outside fenced code, so the syntax colors and
    /// the characters inside code blocks stay untouched.
    private static func styleInline(
        in output: NSMutableAttributedString,
        avoiding ranges: [NSRange],
        style: Style
    ) {
        var cursor = 0
        for range in ranges.sorted(by: { $0.location < $1.location }) {
            if range.location > cursor {
                styleInline(
                    in: output,
                    range: NSRange(
                        location: cursor,
                        length: range.location - cursor
                    ),
                    style: style
                )
            }
            cursor = max(cursor, NSMaxRange(range))
        }

        if cursor < output.length {
            styleInline(
                in: output,
                range: NSRange(
                    location: cursor,
                    length: output.length - cursor
                ),
                style: style
            )
        }
    }

    private static func styleInline(
        in output: NSMutableAttributedString,
        range: NSRange,
        style: Style
    ) {
        let ns = output.string as NSString
        let end = range.location + range.length
        var index = range.location

        while index < end {
            let character = ns.character(at: index)

            // `code`
            if character == 0x60,
               let close = findToken("`", in: ns, from: index + 1, before: end) {
                dim(output, NSRange(location: index, length: 1), style: style)
                dim(output, NSRange(location: close, length: 1), style: style)
                let inner = NSRange(
                    location: index + 1,
                    length: close - index - 1
                )
                if inner.length > 0 {
                    let font = fontAt(output, location: index, fallback: style.baseFont)
                    output.addAttributes(
                        [
                            .font: monospacedFont(font),
                            .backgroundColor: MarkdownColors.codeBackground,
                        ],
                        range: inner
                    )
                }
                index = close + 1
                continue
            }

            // $$display$$ / $inline$
            if character == 0x24 {
                if index + 1 < end,
                   ns.character(at: index + 1) == 0x24,
                   let close = findToken("$$", in: ns, from: index + 2, before: end) {
                    dim(output, NSRange(location: index, length: 2), style: style)
                    dim(output, NSRange(location: close, length: 2), style: style)
                    let inner = NSRange(
                        location: index + 2,
                        length: close - index - 2
                    )
                    applyMathStyle(output, range: inner, style: style)
                    index = close + 2
                    continue
                }

                if let close = inlineMathClose(in: ns, from: index + 1, before: end) {
                    dim(output, NSRange(location: index, length: 1), style: style)
                    dim(output, NSRange(location: close, length: 1), style: style)
                    applyMathStyle(
                        output,
                        range: NSRange(
                            location: index + 1,
                            length: close - index - 1
                        ),
                        style: style
                    )
                    index = close + 1
                    continue
                }
            }

            // **bold**
            if character == 0x2A,
               index + 1 < end,
               ns.character(at: index + 1) == 0x2A,
               let close = findToken("**", in: ns, from: index + 2, before: end) {
                dim(output, NSRange(location: index, length: 2), style: style)
                dim(output, NSRange(location: close, length: 2), style: style)
                let inner = NSRange(
                    location: index + 2,
                    length: close - index - 2
                )
                if inner.length > 0 {
                    let font = fontAt(output, location: index, fallback: style.baseFont)
                    output.addAttribute(
                        .font,
                        value: boldFont(font),
                        range: inner
                    )
                    styleInline(in: output, range: inner, style: style)
                }
                index = close + 2
                continue
            }

            // *italic*
            if character == 0x2A,
               let close = italicClose(in: ns, from: index + 1, before: end) {
                dim(output, NSRange(location: index, length: 1), style: style)
                dim(output, NSRange(location: close, length: 1), style: style)
                let inner = NSRange(
                    location: index + 1,
                    length: close - index - 1
                )
                if inner.length > 0 {
                    let font = fontAt(output, location: index, fallback: style.baseFont)
                    output.addAttribute(
                        .font,
                        value: italicFont(font),
                        range: inner
                    )
                    styleInline(in: output, range: inner, style: style)
                }
                index = close + 1
                continue
            }

            // ~~strikethrough~~
            if character == 0x7E,
               index + 1 < end,
               ns.character(at: index + 1) == 0x7E,
               let close = findToken("~~", in: ns, from: index + 2, before: end) {
                dim(output, NSRange(location: index, length: 2), style: style)
                dim(output, NSRange(location: close, length: 2), style: style)
                let inner = NSRange(
                    location: index + 2,
                    length: close - index - 2
                )
                if inner.length > 0 {
                    output.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: inner
                    )
                    styleInline(in: output, range: inner, style: style)
                }
                index = close + 2
                continue
            }

            // [label](url)
            if character == 0x5B,
               let link = linkMatch(in: ns, at: index, before: end) {
                dim(output, NSRange(location: index, length: 1), style: style)
                dim(
                    output,
                    NSRange(
                        location: link.labelRange.location + link.labelRange.length,
                        length: link.end
                            - (link.labelRange.location + link.labelRange.length)
                    ),
                    style: style
                )
                output.addAttributes(
                    [
                        .foregroundColor: style.accentColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                    ],
                    range: link.labelRange
                )
                styleInline(in: output, range: link.labelRange, style: style)
                index = link.end
                continue
            }

            index += 1
        }
    }

    private static func applyMathStyle(
        _ output: NSMutableAttributedString,
        range: NSRange,
        style: Style
    ) {
        guard range.length > 0 else { return }
        let font =
            output.attribute(.font, at: range.location, effectiveRange: nil)
            as? FormatFont
        output.addAttributes(
            [
                .font: monospacedFont(font ?? style.baseFont),
                .foregroundColor: style.accentColor,
                .backgroundColor: MarkdownColors.mathBackground,
            ],
            range: range
        )
    }

    private static func dim(
        _ output: NSMutableAttributedString,
        _ range: NSRange,
        style: Style
    ) {
        guard range.length > 0 else { return }
        output.addAttribute(
            .foregroundColor,
            value: style.secondaryColor,
            range: range
        )
    }

    private static func fontAt(
        _ output: NSAttributedString,
        location: Int,
        fallback: FormatFont
    ) -> FormatFont {
        guard location < output.length else { return fallback }
        return output.attribute(.font, at: location, effectiveRange: nil)
            as? FormatFont ?? fallback
    }

    // MARK: - Code blocks

    private static func appendCodeBlock(
        _ lines: [String],
        language: String?,
        to output: NSMutableAttributedString,
        style: Style,
        highlightingCode: Bool,
        hasContent: inout Bool,
        newlineAttributes: inout [NSAttributedString.Key: Any]
    ) {
        let code = lines.joined(separator: "\n")
        guard !code.isEmpty else { return }

        if hasContent {
            output.append(
                NSAttributedString(
                    string: "\n",
                    attributes: newlineAttributes
                )
            )
        }

        let lineStart = output.length
        output.append(
            NSAttributedString(
                string: code,
                attributes: codeAttributes(style)
            )
        )

        if highlightingCode {
            applyCodeHighlight(
                output,
                range: NSRange(
                    location: lineStart,
                    length: (code as NSString).length
                ),
                language: language,
                style: style
            )
        }

        newlineAttributes = output.attributes(
            at: lineStart,
            effectiveRange: nil
        )
        hasContent = true
    }

    private static func codeAttributes(
        _ style: Style
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: monospacedFont(style.baseFont),
            .foregroundColor: style.textColor,
            .backgroundColor: MarkdownColors.codeBackground,
            .paragraphStyle: paragraphStyle(style, headIndent: 12),
        ]
    }

    /// The language tag after the backticks of a fence, if any.
    private static func infoLanguage(from fenceLine: String) -> String? {
        let info = String(fenceLine.dropFirst(3))
            .trimmingCharacters(in: .whitespaces)
        guard let token = info.split(whereSeparator: { $0.isWhitespace }).first
        else { return nil }
        let name = String(token)
        return name.isEmpty ? nil : name
    }

    /// Applies the syntax colors for `range` on top of the code attributes.
    /// The text itself is never changed.
    private static func applyCodeHighlight(
        _ output: NSMutableAttributedString,
        range: NSRange,
        language: String?,
        style: Style
    ) {
        guard range.length > 0 else { return }
        let code = (output.string as NSString).substring(with: range)
        let spans = CodeSyntaxHighlighter.spans(
            for: code,
            language: language,
            appearance: style.appearance
        )

        for span in spans {
            let start = range.location + span.range.location
            guard start >= range.location else { continue }
            let target = NSRange(location: start, length: span.range.length)
            guard NSMaxRange(target) <= NSMaxRange(range) else { continue }
            output.addAttribute(
                .foregroundColor,
                value: span.color,
                range: target
            )
        }
    }

    // MARK: - Rendered lines

    private static func appendRenderedLine(
        _ line: String,
        to output: NSMutableAttributedString,
        style: Style
    ) {        let ns = line as NSString

        // Heading
        if let heading = headingPrefix(in: line) {
            let content = ns.substring(from: heading.length)
            let font = boldFont(
                size: style.baseFont.pointSize * headingScale(heading.level)
            )
            appendRenderedInline(
                content,
                font: font,
                color: style.textColor,
                to: output,
                style: style
            )
            return
        }

        var cursor = 0
        while cursor < ns.length, isSpace(ns.character(at: cursor)) {
            cursor += 1
        }
        let rest = ns.substring(from: cursor)

        // Horizontal rule
        if isHorizontalRule(rest) {
            output.append(
                NSAttributedString(
                    string: "────────────────────",
                    attributes: [
                        .font: style.baseFont,
                        .foregroundColor: style.tertiaryColor,
                        .paragraphStyle: paragraphStyle(style, headIndent: 0),
                    ]
                )
            )
            return
        }

        // Block quote
        if rest.hasPrefix(">") {
            var contentStart = cursor + 1
            if contentStart < ns.length,
               isSpace(ns.character(at: contentStart)) {
                contentStart += 1
            }
            let content = ns.substring(from: contentStart)
            let paragraph = paragraphStyle(style, headIndent: 14)
            let lineStart = output.length
            appendRenderedInline(
                content,
                font: style.baseFont,
                color: style.secondaryColor,
                to: output,
                style: style
            )
            applyParagraph(
                paragraph,
                to: output,
                from: lineStart
            )
            return
        }

        // Task, bullet and ordered list items
        if let item = listItem(in: line) {
            appendListLine(item, to: output, style: style)
            return
        }

        // Plain line
        appendRenderedInline(
            rest,
            font: style.baseFont,
            color: style.textColor,
            to: output,
            style: style
        )
    }

    private struct ListItem {
        let marker: String
        let content: String
        let indent: CGFloat
        let isTask: Bool
        let isChecked: Bool
    }

    private static func appendListLine(
        _ item: ListItem,
        to output: NSMutableAttributedString,
        style: Style
    ) {
        let lineStart = output.length
        let markerColor = item.isTask ? style.accentColor : style.secondaryColor

        output.append(
            NSAttributedString(
                string: item.marker + "  ",
                attributes: [
                    .font: style.baseFont,
                    .foregroundColor: markerColor,
                ]
            )
        )

        appendRenderedInline(
            item.content,
            font: style.baseFont,
            color: style.textColor,
            to: output,
            style: style
        )

        applyParagraph(
            paragraphStyle(style, headIndent: item.indent),
            to: output,
            from: lineStart
        )
    }

    private static func applyParagraph(
        _ paragraph: NSParagraphStyle,
        to output: NSMutableAttributedString,
        from start: Int
    ) {
        guard output.length > start else { return }
        output.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: start, length: output.length - start)
        )
    }

    // MARK: - Rendered inline

    private static func appendRenderedInline(
        _ text: String,
        font: FormatFont,
        color: FormatColor,
        to output: NSMutableAttributedString,
        style: Style
    ) {
        let ns = text as NSString
        var segmentStart = 0
        var index = 0

        // Local copies keep the closures simple and avoid capturing `self`
        // (the formatter is a caseless enum).
        let baseFont = font
        let baseColor = color

        func attributes(
            _ font: FormatFont? = nil,
            _ color: FormatColor? = nil,
            extra: [NSAttributedString.Key: Any] = [:]
        ) -> [NSAttributedString.Key: Any] {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? baseFont,
                .foregroundColor: color ?? baseColor,
            ]
            for (key, value) in extra {
                attributes[key] = value
            }
            return attributes
        }

        func flush(to end: Int) {
            guard end > segmentStart else { return }
            output.append(
                NSAttributedString(
                    string: ns.substring(
                        with: NSRange(
                            location: segmentStart,
                            length: end - segmentStart
                        )
                    ),
                    attributes: attributes()
                )
            )
        }

        func emit(
            _ string: String,
            attributes: [NSAttributedString.Key: Any]
        ) {
            output.append(
                NSAttributedString(string: string, attributes: attributes)
            )
        }

        while index < ns.length {
            let character = ns.character(at: index)

            // Backslash escape
            if character == 0x5C, index + 1 < ns.length {
                let next = ns.character(at: index + 1)
                if isEscapable(next) {
                    flush(to: index)
                    emit(
                        ns.substring(
                            with: NSRange(location: index + 1, length: 1)
                        ),
                        attributes: attributes()
                    )
                    index += 2
                    segmentStart = index
                    continue
                }
            }

            // `code`
            if character == 0x60,
               let close = findToken("`", in: ns, from: index + 1, before: ns.length) {
                flush(to: index)
                let inner = ns.substring(
                    with: NSRange(
                        location: index + 1,
                        length: close - index - 1
                    )
                )
                emit(
                    inner,
                    attributes: attributes(
                        monospacedFont(font),
                        extra: [.backgroundColor: MarkdownColors.codeBackground]
                    )
                )
                index = close + 1
                segmentStart = index
                continue
            }

            // Math
            if character == 0x24 {
                if index + 1 < ns.length,
                   ns.character(at: index + 1) == 0x24,
                   let close = findToken("$$", in: ns, from: index + 2, before: ns.length) {
                    flush(to: index)
                    let inner = ns.substring(
                        with: NSRange(
                            location: index + 2,
                            length: close - index - 2
                        )
                    )
                    appendMath(
                        inner,
                        font: font,
                        display: true,
                        to: output,
                        style: style
                    )
                    index = close + 2
                    segmentStart = index
                    continue
                }

                if let close = inlineMathClose(in: ns, from: index + 1, before: ns.length) {
                    flush(to: index)
                    let inner = ns.substring(
                        with: NSRange(
                            location: index + 1,
                            length: close - index - 1
                        )
                    )
                    appendMath(
                        inner,
                        font: font,
                        display: false,
                        to: output,
                        style: style
                    )
                    index = close + 1
                    segmentStart = index
                    continue
                }
            }

            // **bold**
            if character == 0x2A,
               index + 1 < ns.length,
               ns.character(at: index + 1) == 0x2A,
               let close = findToken("**", in: ns, from: index + 2, before: ns.length) {
                flush(to: index)
                let inner = ns.substring(
                    with: NSRange(
                        location: index + 2,
                        length: close - index - 2
                    )
                )
                appendRenderedInline(
                    inner,
                    font: boldFont(font),
                    color: color,
                    to: output,
                    style: style
                )
                index = close + 2
                segmentStart = index
                continue
            }

            // *italic*
            if character == 0x2A,
               let close = italicClose(in: ns, from: index + 1, before: ns.length) {
                flush(to: index)
                let inner = ns.substring(
                    with: NSRange(
                        location: index + 1,
                        length: close - index - 1
                    )
                )
                appendRenderedInline(
                    inner,
                    font: italicFont(font),
                    color: color,
                    to: output,
                    style: style
                )
                index = close + 1
                segmentStart = index
                continue
            }

            // ~~strikethrough~~
            if character == 0x7E,
               index + 1 < ns.length,
               ns.character(at: index + 1) == 0x7E,
               let close = findToken("~~", in: ns, from: index + 2, before: ns.length) {
                flush(to: index)
                let inner = ns.substring(
                    with: NSRange(
                        location: index + 2,
                        length: close - index - 2
                    )
                )
                let start = output.length
                appendRenderedInline(
                    inner,
                    font: font,
                    color: color,
                    to: output,
                    style: style
                )
                if output.length > start {
                    output.addAttribute(
                        .strikethroughStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(
                            location: start,
                            length: output.length - start
                        )
                    )
                }
                index = close + 2
                segmentStart = index
                continue
            }

            // [label](url)
            if character == 0x5B,
               let link = linkMatch(in: ns, at: index, before: ns.length) {
                flush(to: index)
                let label = ns.substring(with: link.labelRange)
                let start = output.length
                appendRenderedInline(
                    label,
                    font: font,
                    color: style.accentColor,
                    to: output,
                    style: style
                )
                if output.length > start {
                    output.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: NSRange(
                            location: start,
                            length: output.length - start
                        )
                    )
                }
                index = link.end
                segmentStart = index
                continue
            }

            index += 1
        }

        flush(to: ns.length)
    }

    // MARK: - Math

    /// Appends a display math block that spanned several source lines. The
    /// lines are joined so LaTeX environments (`\\begin{aligned}`) keep their
    /// line breaks.
    private static func appendDisplayMath(
        _ lines: [String],
        to output: NSMutableAttributedString,
        style: Style,
        hasContent: inout Bool
    ) {
        let latex = lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latex.isEmpty else { return }

        if hasContent {
            output.append(
                NSAttributedString(
                    string: "\n",
                    attributes: baseAttributes(style)
                )
            )
        }

        appendMath(
            latex,
            font: style.baseFont,
            display: true,
            to: output,
            style: style
        )
        hasContent = true
    }

    private static func appendMath(
        _ latex: String,
        font: FormatFont,
        display: Bool,
        to output: NSMutableAttributedString,
        style: Style
    ) {
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if style.rendersMath,
           let image = mathImage(
            latex: trimmed,
            fontSize: font.pointSize,
            color: style.textColor,
            display: display,
            appearance: style.appearance
           ) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let size = image.size
            attachment.bounds = CGRect(
                x: 0,
                y: -size.height * 0.24,
                width: size.width,
                height: size.height
            )
            output.append(NSAttributedString(attachment: attachment))
            output.append(
                NSAttributedString(
                    string: " ",
                    attributes: [.font: font, .foregroundColor: style.textColor]
                )
            )
            return
        }

        output.append(
            NSAttributedString(
                string: trimmed,
                attributes: [
                    .font: monospacedFont(font),
                    .foregroundColor: style.accentColor,
                    .backgroundColor: MarkdownColors.mathBackground,
                ]
            )
        )
    }

    private final class CachedImage {
        let image: PlatformImage
        init(_ image: PlatformImage) { self.image = image }
    }

    private static let mathImageCache = NSCache<NSString, CachedImage>()

    private static func mathImage(
        latex: String,
        fontSize: CGFloat,
        color: FormatColor,
        display: Bool,
        appearance: MarkdownAppearance
    ) -> PlatformImage? {
        // A math image resolves its text color when it is drawn, so a light
        // image must not be reused in dark mode (the text would vanish).
        let key =
            "\(fontSize)|\(display)|\(appearance)|\(color.description)|\(latex)"
            as NSString

        if let cached = mathImageCache.object(forKey: key) {
            return cached.image
        }

        let mathImage = MTMathImage(
            latex: latex,
            fontSize: fontSize,
            textColor: color,
            labelMode: display ? .display : .text,
            textAlignment: .left
        )

        let (error, image) = mathImage.asImage()
        guard error == nil, let image else { return nil }

        mathImageCache.setObject(CachedImage(image), forKey: key)
        return image
    }

    // MARK: - Line helpers

    private struct LinkMatch {
        let labelRange: NSRange
        let end: Int
    }

    private static func isSpace(_ character: unichar) -> Bool {
        character == 0x20 || character == 0x09
    }

    private static func isDigit(_ character: unichar) -> Bool {
        character >= 0x30 && character <= 0x39
    }

    private static func isEscapable(_ character: unichar) -> Bool {
        switch character {
        case 0x2A, 0x5F, 0x60, 0x24, 0x7E, 0x5B, 0x5D, 0x28, 0x29, 0x23, 0x3E:
            return true
        default:
            return false
        }
    }

    /// Leading `#`s followed by a space. Returns the level and the UTF-16
    /// length of the marker (including leading whitespace and the space).
    private static func headingPrefix(in line: String) -> (level: Int, length: Int)? {
        let ns = line as NSString
        var index = 0

        while index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }

        let markerStart = index
        while index < ns.length, ns.character(at: index) == 0x23 {
            index += 1
        }

        let level = index - markerStart
        guard (1...6).contains(level) else { return nil }
        guard index < ns.length, isSpace(ns.character(at: index)) else {
            return nil
        }

        while index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }

        return (level, index)
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        guard let first = trimmed.first, "-*_".contains(first) else {
            return false
        }
        return trimmed.allSatisfy { $0 == first }
    }

    /// UTF-16 length of a bullet, task, or ordered-list marker, including
    /// leading whitespace and the trailing space.
    private static func listMarkerLength(in line: String) -> Int? {
        let ns = line as NSString
        var index = 0

        while index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }
        guard index < ns.length else { return nil }

        let character = ns.character(at: index)

        if character == 0x2D || character == 0x2A || character == 0x2B {
            guard index + 1 < ns.length,
                  isSpace(ns.character(at: index + 1)) else {
                return nil
            }
            index += 1
            while index < ns.length, isSpace(ns.character(at: index)) {
                index += 1
            }

            // Optional task checkbox.
            if index + 2 < ns.length,
               ns.character(at: index) == 0x5B,
               ns.character(at: index + 2) == 0x5D {
                let state = ns.character(at: index + 1)
                if state == 0x20 || state == 0x78 || state == 0x58 {
                    index += 3
                    while index < ns.length, isSpace(ns.character(at: index)) {
                        index += 1
                    }
                }
            }

            return index
        }

        if isDigit(character) {
            while index < ns.length, isDigit(ns.character(at: index)) {
                index += 1
            }
            guard index < ns.length, ns.character(at: index) == 0x2E else {
                return nil
            }
            index += 1
            guard index < ns.length, isSpace(ns.character(at: index)) else {
                return nil
            }
            while index < ns.length, isSpace(ns.character(at: index)) {
                index += 1
            }
            return index
        }

        return nil
    }

    private static func quoteMarkerLength(in line: String) -> Int? {
        let ns = line as NSString
        var index = 0

        while index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }
        guard index < ns.length, ns.character(at: index) == 0x3E else {
            return nil
        }
        index += 1
        if index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }
        return index
    }

    private static func listItem(in line: String) -> ListItem? {
        let ns = line as NSString
        var index = 0

        while index < ns.length, isSpace(ns.character(at: index)) {
            index += 1
        }
        guard index < ns.length else { return nil }

        let character = ns.character(at: index)

        if character == 0x2D || character == 0x2A || character == 0x2B {
            guard index + 1 < ns.length,
                  isSpace(ns.character(at: index + 1)) else {
                return nil
            }
            index += 1
            while index < ns.length, isSpace(ns.character(at: index)) {
                index += 1
            }

            if index + 2 < ns.length,
               ns.character(at: index) == 0x5B,
               ns.character(at: index + 2) == 0x5D {
                let state = ns.character(at: index + 1)
                if state == 0x20 || state == 0x78 || state == 0x58 {
                    var contentStart = index + 3
                    if contentStart < ns.length,
                       isSpace(ns.character(at: contentStart)) {
                        contentStart += 1
                    }
                    return ListItem(
                        marker: state == 0x20 ? "☐" : "☑",
                        content: ns.substring(from: contentStart),
                        indent: 20,
                        isTask: true,
                        isChecked: state != 0x20
                    )
                }
            }

            return ListItem(
                marker: "•",
                content: ns.substring(from: index),
                indent: 18,
                isTask: false,
                isChecked: false
            )
        }

        if isDigit(character) {
            let numberStart = index
            while index < ns.length, isDigit(ns.character(at: index)) {
                index += 1
            }
            guard index < ns.length, ns.character(at: index) == 0x2E else {
                return nil
            }
            let number = ns.substring(
                with: NSRange(
                    location: numberStart,
                    length: index - numberStart
                )
            )
            index += 1
            guard index < ns.length, isSpace(ns.character(at: index)) else {
                return nil
            }
            while index < ns.length, isSpace(ns.character(at: index)) {
                index += 1
            }
            return ListItem(
                marker: "\(number).",
                content: ns.substring(from: index),
                indent: 22,
                isTask: false,
                isChecked: false
            )
        }

        return nil
    }

    // MARK: - Token helpers

    private static func findToken(
        _ token: String,
        in string: NSString,
        from start: Int,
        before end: Int
    ) -> Int? {
        guard start <= end, start >= 0, end <= string.length else {
            return nil
        }
        let searchRange = NSRange(location: start, length: end - start)
        let found = string.range(of: token, options: [], range: searchRange)
        guard found.location != NSNotFound else { return nil }

        // Inline markers close on the same line. A marker on a later line
        // would otherwise style across a line break and dim the marker that
        // starts the next line's span.
        let newline = string.range(
            of: "\n",
            options: [],
            range: NSRange(location: start, length: found.location - start)
        )
        return newline.location == NSNotFound ? found.location : nil
    }

    private static func isStar(_ string: NSString, at index: Int) -> Bool {
        guard index >= 0, index < string.length else { return false }
        return string.character(at: index) == 0x2A
    }

    private static func italicClose(
        in string: NSString,
        from start: Int,
        before end: Int
    ) -> Int? {
        var index = start
        while index < end {
            let character = string.character(at: index)
            if character == 0x0A { return nil }
            if character == 0x2A,
               index > start,
               !isStar(string, at: index - 1),
               !isStar(string, at: index + 1) {
                return index
            }
            index += 1
        }
        return nil
    }

    /// Finds the closing `$` of inline math. Rejects empty content, content
    /// that starts or ends with whitespace (so prices like "$5 and $10" are
    /// not treated as math), and content spanning a line break.
    private static func inlineMathClose(
        in string: NSString,
        from start: Int,
        before end: Int
    ) -> Int? {
        var index = start
        while index < end {
            let character = string.character(at: index)
            if character == 0x0A { return nil }
            if character == 0x24 {
                guard index > start else { return nil }
                let inner = string.substring(
                    with: NSRange(location: start, length: index - start)
                )
                guard !inner.isEmpty,
                      inner.first?.isWhitespace == false,
                      inner.last?.isWhitespace == false else {
                    return nil
                }
                return index
            }
            index += 1
        }
        return nil
    }

    private static func linkMatch(
        in string: NSString,
        at index: Int,
        before end: Int
    ) -> LinkMatch? {
        guard index < end, string.character(at: index) == 0x5B else {
            return nil
        }

        var cursor = index + 1
        while cursor < end {
            let character = string.character(at: cursor)
            if character == 0x0A { return nil }
            if character == 0x5D { break }
            cursor += 1
        }
        guard cursor < end, string.character(at: cursor) == 0x5D else {
            return nil
        }

        let labelRange = NSRange(
            location: index + 1,
            length: cursor - index - 1
        )
        guard labelRange.length > 0 else { return nil }

        guard cursor + 1 < end,
              string.character(at: cursor + 1) == 0x28 else {
            return nil
        }

        var urlEnd = cursor + 2
        while urlEnd < end, string.character(at: urlEnd) != 0x29 {
            if string.character(at: urlEnd) == 0x0A { return nil }
            urlEnd += 1
        }
        guard urlEnd < end else { return nil }

        return LinkMatch(labelRange: labelRange, end: urlEnd + 1)
    }
}
