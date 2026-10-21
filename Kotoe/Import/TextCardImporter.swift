//
//  TextCardImporter.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import Foundation

/// Turns pasted text into flashcards.
///
/// Quizlet exports a set as tab separated lines (`Term<TAB>Definition`) and
/// escapes line breaks inside a field as `\n`. Other apps use a dash or a
/// colon, so the separator is detected from the pasted text instead of being
/// fixed. Text without any separator becomes a card with a front only.
enum TextCardImporter {

    /// A single card parsed from text.
    struct Card: Identifiable {

        let id = UUID()

        var front: String
        var back: String
    }

    /// The separator that was found in the pasted text.
    enum Separator {

        case tab
        case dash
        case colon
        case none

        /// Human readable name, shown in the import preview.
        var localizedName: String {
            switch self {
            case .tab:
                return String(
                    localized: "cardImport.separator.tab",
                    defaultValue: "Tab"
                )
            case .dash:
                return String(
                    localized: "cardImport.separator.dash",
                    defaultValue: "Dash"
                )
            case .colon:
                return String(
                    localized: "cardImport.separator.colon",
                    defaultValue: "Colon"
                )
            case .none:
                return String(
                    localized: "cardImport.separator.none",
                    defaultValue: "None"
                )
            }
        }
    }

    /// Parsed cards plus the separator the text was split with.
    struct ParsedCards {

        var cards: [Card]
        var separator: Separator
    }

    // MARK: - Parsing

    /// Separators that are tried in order of preference. The one that occurs
    /// in the most lines wins, so a stray colon in a definition does not
    /// outvote the tabs of a Quizlet export.
    private static let candidates: [(separator: String, kind: Separator)] = [
        ("\t", .tab),
        (" - ", .dash),
        (" – ", .dash),
        ("::", .colon),
        (":", .colon),
    ]

    /// Parses pasted text into cards.
    static func parse(_ text: String) -> ParsedCards {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return ParsedCards(cards: [], separator: .none)
        }

        let match = detectSeparator(in: lines)

        let cards = lines.compactMap { line -> Card? in
            let parts = split(line, with: match?.separator)

            let front = unescape(parts.front)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let back = unescape(parts.back)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !front.isEmpty else { return nil }

            return Card(front: front, back: back)
        }

        return ParsedCards(cards: cards, separator: match?.kind ?? .none)
    }

    // MARK: - Helpers

    /// Picks the separator that occurs in the most lines.
    ///
    /// A later candidate only wins when it clearly outscores the earlier one.
    /// Otherwise a colon inside a definition would beat the tabs of a
    /// Quizlet export.
    private static func detectSeparator(
        in lines: [String]
    ) -> (separator: String, kind: Separator)? {
        var best: (separator: String, kind: Separator)?
        var bestCount = 0

        for candidate in candidates {
            let count = lines.filter { line in
                guard
                    let range = line.range(of: candidate.separator),
                    range.lowerBound != line.startIndex
                else { return false }

                return true
            }.count

            guard count * 2 > bestCount * 3 else { continue }

            bestCount = count
            best = candidate
        }

        return best
    }

    /// Splits a line into front and back at the first separator.
    private static func split(
        _ line: String,
        with separator: String?
    ) -> (front: String, back: String) {
        guard
            let separator,
            let range = line.range(of: separator),
            range.lowerBound != line.startIndex
        else {
            return (line, "")
        }

        let front = String(line[line.startIndex..<range.lowerBound])
        let back = String(line[range.upperBound...])

        return (front, back)
    }

    /// Quizlet escapes line breaks and tabs inside a field.
    private static func unescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}
