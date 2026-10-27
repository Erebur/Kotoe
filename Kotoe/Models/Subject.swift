//
//  Subject.swift
//  Flash
//
//  Created by Simon Weber on 19.10.26.
//


import Foundation
import SwiftData
import PencilKit

@Model
final class Subject {
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
    var lastAccessedAt: Date = Date.now
    var modifiedAt: Date = Date.now

    var position: Int = 0
    var isArchived: Bool = false

    /// User-chosen SF Symbol. `nil` derives one from the name.
    var iconName: String? = nil

    /// Index into `KotoeTheme.palette`. `nil` derives a color from the name.
    var tintIndex: Int? = nil

    // MARK: Relationships

    @Relationship(
        deleteRule: .cascade,
        inverse: \FlashcardSet.subject
    )
    var flashcardSets: [FlashcardSet]?

    init(
        name: String,
        notes: String? = nil,
        position: Int = 0,
        iconName: String? = nil,
        tintIndex: Int? = nil
    ) {
        self.id = UUID()

        self.name = name
        self.notes = notes

        self.position = position
        self.iconName = iconName
        self.tintIndex = tintIndex
    }
    
    var sortedFlashcardSets: [FlashcardSet] {
        (flashcardSets ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.position < $1.position }
    }

    /// Every card in the subject, in set order.
    var allCards: [Flashcard] {
        sortedFlashcardSets.flatMap(\.sortedFlashcards)
    }

    var cardCount: Int {
        allCards.count
    }
}

// MARK: - Rich Text

extension Subject {

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

extension Subject {

    /// Deletes the media files of every card. Call before deleting the subject.
    func removeMediaFiles() {
        for set in flashcardSets ?? [] {
            set.removeMediaFiles()
        }
    }
}
