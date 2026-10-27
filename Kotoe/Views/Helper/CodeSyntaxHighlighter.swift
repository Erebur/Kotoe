//
//  CodeSyntaxHighlighter.swift
//  Kōtoe
//
//  Created by Simon Weber on 27.10.26.
//
//  Highlights fenced code blocks with highlight.js, wrapped by the
//  HighlighterSwift package. The formatter only takes the foreground colors
//  from the library output and keeps its own monospaced font, background, and
//  paragraph style, so code blocks match the rest of the rich text.
//

import Foundation
import Highlighter

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Light or dark syntax colors. The code colors follow the system appearance
/// of the view that renders the code.
enum MarkdownAppearance: Hashable {
    case light
    case dark
}

/// One colored token range inside a fenced code block, relative to the code
/// string.
struct CodeHighlightSpan {
    let range: NSRange
    let color: FormatColor
}

/// Syntax highlighting for fenced code blocks.
///
/// Highlight.js supports about 185 languages and accepts the usual aliases
/// (`swift`, `js`, `py`, `ts`, `cpp`, …). A fence without a language falls
/// back to highlight.js language detection, so untagged blocks still get
/// colors when the content is recognizable.
enum CodeSyntaxHighlighter {

    // MARK: - Types

    private struct CacheKey: Hashable {
        let code: String
        let language: String?
        let appearance: MarkdownAppearance
    }

    // MARK: - State

    private static let lock = NSLock()
    private static var engine: Highlighter?
    private static var engineAppearance: MarkdownAppearance?
    private static var cache: [CacheKey: [CodeHighlightSpan]] = [:]
    private static var cacheOrder: [CacheKey] = []

    /// Code blocks are usually short; keep enough entries for the visible
    /// cards without letting the cache grow with every keystroke.
    private static let cacheLimit = 64

    /// Automatic detection runs every grammar, so very large untagged blocks
    /// stay plain instead of stalling the editor.
    private static let autoDetectionLimit = 4000

    // MARK: - Highlighting

    /// Colored ranges for `code`. The result is cached, because the editor
    /// restyles on every keystroke and study cards re-render often.
    static func spans(
        for code: String,
        language: String?,
        appearance: MarkdownAppearance
    ) -> [CodeHighlightSpan] {
        guard !code.isEmpty else { return [] }

        let language = normalizedLanguage(language)
        if language == nil, code.count > autoDetectionLimit {
            return []
        }

        let key = CacheKey(
            code: code,
            language: language,
            appearance: appearance
        )

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let spans = compute(code: code, language: language, appearance: appearance)

        lock.lock()
        cache[key] = spans
        cacheOrder.append(key)
        if cacheOrder.count > cacheLimit {
            let oldest = cacheOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        lock.unlock()

        return spans
    }

    private static func compute(
        code: String,
        language: String?,
        appearance: MarkdownAppearance
    ) -> [CodeHighlightSpan] {
        lock.lock()
        defer { lock.unlock() }

        guard let engine = preparedEngine(appearance: appearance) else {
            return []
        }
        guard let highlighted = engine.highlight(code, as: language) else {
            // Unknown language or a highlight.js failure: keep the plain code.
            return []
        }
        guard highlighted.string == code else {
            // Never apply ranges to a string that shifted (entity decoding).
            return []
        }

        var spans: [CodeHighlightSpan] = []
        highlighted.enumerateAttribute(
            .foregroundColor,
            in: NSRange(location: 0, length: highlighted.length)
        ) { value, range, _ in
            guard let color = value as? FormatColor else { return }
            spans.append(CodeHighlightSpan(range: range, color: color))
        }
        return spans
    }

    // MARK: - Engine

    private static func preparedEngine(
        appearance: MarkdownAppearance
    ) -> Highlighter? {
        let engine: Highlighter
        if let existing = Self.engine {
            engine = existing
        } else {
            guard let created = Highlighter() else { return nil }
            Self.engine = created
            engine = created
        }

        if engineAppearance != appearance {
            let theme = appearance == .dark ? "xcode-dusk" : "xcode"
            guard engine.setTheme(theme) else { return nil }
            engineAppearance = appearance
        }

        return engine
    }

    // MARK: - Languages

    /// Fence info strings use markdown/CommonMark names; map the few that
    /// highlight.js knows under a different alias.
    private static func normalizedLanguage(_ language: String?) -> String? {
        guard var name = language?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(), !name.isEmpty
        else {
            return nil
        }

        if name.hasPrefix("{."), name.hasSuffix("}") {
            name = String(name.dropFirst(2).dropLast())
        }

        let aliases: [String: String] = [
            "c++": "cpp",
            "c#": "csharp",
            "f#": "fsharp",
            "obj-c": "objectivec",
            "objc": "objectivec",
            "objective-c": "objectivec",
            "jsx": "javascript",
            "tsx": "typescript",
            "golang": "go",
            "shell": "bash",
            "zsh": "bash",
            "docker": "dockerfile",
            "html": "xml",
            "svg": "xml",
            "vue": "xml",
        ]

        return aliases[name] ?? name
    }
}
