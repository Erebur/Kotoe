//
//  RichTextDisplayMode.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  How a rich text field shows its content. Stored on the owning model so the
//  choice is remembered per field and travels with the content through iCloud.
//

import Foundation

enum RichTextDisplayMode: String, CaseIterable, Codable {
    /// Only the markdown source, editable.
    case editor

    /// Source on one side, rendered output on the other.
    case split

    /// Only the rendered output.
    case preview
}
