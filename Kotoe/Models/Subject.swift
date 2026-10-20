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

    var createdAt: Date = Date.now
    var lastAccessedAt: Date = Date.now
    var modifiedAt: Date = Date.now

    var position: Int = 0
    var isArchived: Bool = false

    // MARK: Relationships

    @Relationship(
        deleteRule: .cascade,
        inverse: \FlashcardSet.subject
    )
    var flashcardSets: [FlashcardSet]?

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
