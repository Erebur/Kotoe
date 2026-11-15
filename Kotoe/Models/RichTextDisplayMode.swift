//
//  RichTextDisplayMode.swift
//  Kōtoe
//
//  Created by Simon Weber on 26.10.26.
//
//  How a rich text field shows its content. The mode is local to the field:
//  it is never stored on the model, so a field starts in the mode its owner
//  asks for (preview by default) each time it appears.
//

import Foundation

enum RichTextDisplayMode: CaseIterable, Hashable {
    /// Only the markdown source, editable.
    case editor

    /// Source on one side, rendered output on the other.
    case split

    /// Only the rendered output.
    case preview
}
