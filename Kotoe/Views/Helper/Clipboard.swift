//
//  Clipboard.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import Foundation

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

/// Reads plain text from the system pasteboard.
///
/// Used by the card import, where a set is usually copied from another app
/// before it is pasted into the editor.
enum Clipboard {

    /// Whether the pasteboard holds text.
    ///
    /// This never shows the system paste prompt on iOS, so it is safe to
    /// read while a view is drawn. Reading the text itself does prompt.
    static var hasText: Bool {
        #if os(macOS)
        NSPasteboard.general.types?.contains(.string) ?? false
        #else
        UIPasteboard.general.hasStrings
        #endif
    }

    static var text: String? {
        #if os(macOS)
        NSPasteboard.general.string(forType: .string)
        #else
        UIPasteboard.general.string
        #endif
    }
}
