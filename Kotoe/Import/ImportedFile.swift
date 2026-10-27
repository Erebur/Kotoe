//
//  ImportedFile.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import Foundation
import ImageIO

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Reads a file that the user picked and works out what it contains.
///
/// The file picker accepts every file type, so the content decides what a
/// card side becomes: a PDF stays a PDF, an image is stored as an image and
/// a text file is imported as text. Everything else is rejected with a
/// message instead of silently becoming an unreadable card.
enum ImportedFile {

    /// The content of an imported file.
    enum Content: Sendable {

        case image(Data)
        case pdf(Data)
        case text(String)
    }

    /// The outcome of reading a file.
    enum Outcome: Sendable {

        case imported(Content)
        case unsupported(String)
        case failed(String)
    }

    /// Reads the file and classifies its content.
    nonisolated static func read(url: URL) -> Outcome {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            return .failed(url.lastPathComponent)
        }

        return classify(data: data, fileName: url.lastPathComponent)
    }

    /// Classifies already loaded bytes.
    nonisolated static func classify(
        data: Data,
        fileName: String
    ) -> Outcome {
        if data.starts(with: Array("%PDF".utf8)) {
            return .imported(.pdf(data))
        }

        // ImageIO returns a source even for data it cannot decode, so the
        // source must also report a type and at least one image.
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           CGImageSourceGetType(source) != nil,
           CGImageSourceGetCount(source) > 0 {
            return .imported(.image(data))
        }

        if let text = plainText(from: data) {
            return .imported(.text(text))
        }

        return .unsupported(fileName)
    }

    /// Reads a text file, used by the bulk card import.
    nonisolated static func readText(url: URL) -> String? {
        let isScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else { return nil }

        return plainText(from: data)
    }

    // MARK: - Helpers

    /// Converts the file to plain text, unwrapping RTF documents.
    nonisolated private static func plainText(from data: Data) -> String? {
        if data.starts(with: Array("{\\rtf".utf8)),
           let attributed = try? NSAttributedString(
               data: data,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ) {
            return attributed.string
        }

        guard let text = String(data: data, encoding: .utf8) else { return nil }

        // Binary data that happens to decode is not text.
        if text.unicodeScalars.contains(where: { $0.value == 0xFFFD }) {
            return nil
        }

        return text
    }
}
