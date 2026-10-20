//
//  FlashcardModels.swift
//  Flash
//
//  Created by Simon Weber on 19.10.26.
//
import Foundation
import SwiftData
import PencilKit

// MARK: - Flashcard Content Type

enum FlashcardContentType: String, Codable {
    case richText
    case image
    case drawing
}

// MARK: - Flashcard Side Role

enum FlashcardSideRole: String, Codable {
    case front
    case back
}


// MARK: - Flashcard

@Model
final class Flashcard {

    // MARK: Identity

    var id: UUID = UUID()

    // MARK: Metadata

    var createdAt: Date = Date.now
    var modifiedAt: Date = Date.now

    var position: Int = 0
    var isArchived: Bool = false

    // MARK: Relationships

    var flashcardSet: FlashcardSet?

    @Relationship(
        deleteRule: .cascade,
        inverse: \FlashcardSide.flashcard
    )
    var sides: [FlashcardSide]?

    // MARK: Initialization

    init(position: Int = 0) {
        self.id = UUID()

        self.createdAt = .now
        self.modifiedAt = .now

        self.position = position
        self.isArchived = false
    }

    // MARK: Side Accessors

    var front: FlashcardSide? {
        sides?.first { $0.role == .front }
    }

    var back: FlashcardSide? {
        sides?.first { $0.role == .back }
    }

    // MARK: Side Creation

    func setFront(_ side: FlashcardSide) {
        var currentSides = sides ?? []

        currentSides.removeAll { $0.role == .front }

        side.role = .front
        currentSides.append(side)

        sides = currentSides
        modifiedAt = .now
    }

    func setBack(_ side: FlashcardSide) {
        var currentSides = sides ?? []

        currentSides.removeAll { $0.role == .back }

        side.role = .back
        currentSides.append(side)

        sides = currentSides
        modifiedAt = .now
    }
}
