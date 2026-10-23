//
//  PreviewData.swift
//  Kōtoe
//
//  In-memory sample models for Xcode previews.
//

import SwiftData
import SwiftUI

/// Builds throwaway, in-memory sample data so previews never touch the real
/// library or iCloud. Every preview uses a fresh container.
@MainActor
enum PreviewData {

    struct Scene {
        let container: ModelContainer
        let subject: Subject
        let set: FlashcardSet
        let card: Flashcard
        let frontSide: FlashcardSide
    }

    /// An empty store listing every model in the schema.
    static func container() -> ModelContainer {
        let schema = Schema([
            Subject.self,
            FlashcardSet.self,
            Flashcard.self,
            FlashcardSide.self,
            FlashcardReview.self,
        ])

        do {
            return try ModelContainer(
                for: schema,
                configurations: [
                    ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        cloudKitDatabase: .none
                    )
                ]
            )
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }

    /// A subject with one set and two typed cards.
    static func scene() -> Scene {
        let container = container()
        let context = container.mainContext

        let subject = Subject(
            name: "Biology",
            notes: "Cells, DNA, and the organelles."
        )
        context.insert(subject)

        let set = FlashcardSet(name: "Cell Biology")
        set.subject = subject
        context.insert(set)

        let first = card(
            front: "What is the powerhouse of the cell?",
            back: "The mitochondrion",
            position: 0,
            in: context
        )
        first.flashcardSet = set

        let second = card(
            front: "Which organelle builds proteins?",
            back: "The ribosome",
            position: 1,
            in: context
        )
        second.flashcardSet = set

        try? context.save()

        guard let frontSide = first.front else {
            fatalError("Preview card is missing its front side")
        }

        return Scene(
            container: container,
            subject: subject,
            set: set,
            card: first,
            frontSide: frontSide
        )
    }

    /// A card with typed front and back sides, inserted into `context`.
    static func card(
        front: String,
        back: String,
        position: Int = 0,
        in context: ModelContext
    ) -> Flashcard {
        let card = Flashcard(position: position)
        context.insert(card)

        let frontSide = FlashcardSide(role: .front)
        let backSide = FlashcardSide(role: .back)
        context.insert(frontSide)
        context.insert(backSide)

        frontSide.setPlainText(front)
        backSide.setPlainText(back)

        card.setFront(frontSide)
        card.setBack(backSide)

        return card
    }

    /// A side with a content type but no file, for media placeholders.
    static func emptySide(
        _ contentType: FlashcardContentType,
        in context: ModelContext
    ) -> FlashcardSide {
        let side = FlashcardSide(role: .front, contentType: contentType)
        context.insert(side)
        return side
    }
}
