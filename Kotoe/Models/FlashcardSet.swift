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

    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    var position: Int = 0
    var isArchived: Bool = false

    var subject: Subject?

    @Relationship(
        deleteRule: .cascade,
        inverse: \Flashcard.flashcardSet
    )
    var flashcards: [Flashcard]?

    init(
        name: String,
        notes: String? = nil,
        position: Int = 0
    ) {
        self.id = UUID()

        self.name = name
        self.notes = notes

        self.position = position
    }
    
    var sortedFlashcards: [Flashcard] {
        (flashcards ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.position < $1.position }
    }
}
