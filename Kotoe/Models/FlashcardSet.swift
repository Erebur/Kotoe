//
//  FlashcardSet.swift
//  Flash
//
//  Created by Simon Weber on 19.10.26.
//


import Foundation
import SwiftData
import PencilKit

@Model
final class FlashcardSet {
    var id: UUID = UUID()

    var name: String = ""
    var notes: String?

    /// Rich text of the notes, serialized as RTF. `notes` keeps the plain
    /// string in sync so existing readers keep working.
    var notesRichTextData: Data? = nil

    /// Backing value of `notesDisplayMode`. Optional because stores created
    /// before the field existed have no value for it; `nil` reads as
    /// `.editor`.
    var notesDisplayModeStorage: RichTextDisplayMode? = nil

    /// How the notes field shows its content. Part of the record so the
    /// choice is remembered per field and syncs through iCloud.
    var notesDisplayMode: RichTextDisplayMode {
        get { notesDisplayModeStorage ?? .editor }
        set { notesDisplayModeStorage = newValue }
    }

    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    var position: Int = 0
    var isArchived: Bool = false

    /// When typing answers, whether upper- and lowercase letters must match
    /// exactly. Stored per set so every session of the set behaves the same.
    var checksCapitalization: Bool = false

    /// User-chosen SF Symbol. `nil` uses the default set symbol.
    var iconName: String? = nil

    /// Index into `KotoeTheme.palette`. `nil` follows the subject's color.
    var tintIndex: Int? = nil

    var subject: Subject?

    @Relationship(
        deleteRule: .cascade,
        inverse: \Flashcard.flashcardSet
    )
    var flashcards: [Flashcard]?

    init(
        name: String,
        notes: String? = nil,
        position: Int = 0,
        iconName: String? = nil,
        tintIndex: Int? = nil,
        checksCapitalization: Bool = false
    ) {
        self.id = UUID()

        self.name = name
        self.notes = notes

        self.position = position
        self.iconName = iconName
        self.tintIndex = tintIndex
        self.checksCapitalization = checksCapitalization
    }
    
    var sortedFlashcards: [Flashcard] {
        (flashcards ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.position < $1.position }
    }
}

// MARK: - Rich Text

extension FlashcardSet {

    /// The notes as rich text, stored as RTF. Writing here keeps `notes` in
    /// sync with the plain string so existing readers keep working.
    var attributedNotes: NSAttributedString {
        get {
            if let data = notesRichTextData,
               let attributed = try? NSAttributedString(
                   data: data,
                   options: [.documentType: NSAttributedString.DocumentType.rtf],
                   documentAttributes: nil
               ) {
                return attributed
            }
            return NSAttributedString(string: notes ?? "")
        }
        set {
            notesRichTextData = newValue.rtfData
            notes = newValue.string.isEmpty ? nil : newValue.string
        }
    }
}

// MARK: - Media Cleanup

extension FlashcardSet {

    /// Deletes the media files of every card. Call before deleting the set.
    func removeMediaFiles() {
        for card in flashcards ?? [] {
            card.removeMediaFiles()
        }
    }
}
