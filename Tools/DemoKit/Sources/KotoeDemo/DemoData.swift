//
//  DemoData.swift
//  Kōtoe DemoKit
//
//  In-memory sample data for the headless demo renderer.
//

import Foundation
import SwiftData

/// Builds throwaway sample libraries for demos.
///
/// Everything lives in an in-memory SwiftData container with CloudKit turned
/// off. A demo must never touch the real library, the iCloud Drive media
/// folder, or the user's sync state.
@MainActor
enum DemoData {

    struct Library {
        let container: ModelContainer
        let subjects: [Subject]
        let cards: [Flashcard]
    }

    // MARK: - Containers

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
            fatalError("Could not create the demo container: \(error)")
        }
    }

    // MARK: - Library

    /// Six subjects with sets and cards, close to the library in the README.
    static func library() -> Library {
        let container = container()
        let context = container.mainContext

        var subjects: [Subject] = []
        var cards: [Flashcard] = []

        func subject(
            _ name: String,
            notes: String?,
            symbol: String,
            tint: Int
        ) -> Subject {
            let subject = Subject(
                name: name,
                notes: notes,
                position: subjects.count,
                iconName: symbol,
                tintIndex: tint
            )
            context.insert(subject)
            subjects.append(subject)
            return subject
        }

        func set(
            _ name: String,
            notes: String?,
            in subject: Subject
        ) -> FlashcardSet {
            let set = FlashcardSet(
                name: name,
                notes: notes,
                position: subject.sortedFlashcardSets.count
            )
            set.subject = subject
            context.insert(set)
            return set
        }

        func card(
            front: String,
            back: String,
            in set: FlashcardSet
        ) -> Flashcard {
            let card = makeCard(
                front: front,
                back: back,
                position: set.sortedFlashcards.count,
                in: context
            )
            card.flashcardSet = set
            cards.append(card)
            return card
        }

        let anatomy = subject(
            "Anatomy",
            notes: "Bones, muscles, and the systems that hold the body together.",
            symbol: "cross.case.fill",
            tint: 2
        )
        let humanBody = set(
            "Human Body",
            notes: "The major systems and the organs inside them.",
            in: anatomy
        )
        card(
            front: "How many bones are in the adult human body?",
            back: "206",
            in: humanBody
        )
        card(
            front: "Which muscle separates the chest from the abdomen?",
            back: "The diaphragm",
            in: humanBody
        )
        card(
            front: "What is the largest organ of the body?",
            back: "The skin",
            in: humanBody
        )

        let chemistry = subject(
            "Chemistry",
            notes: "Elements, bonds, and the reactions between them.",
            symbol: "flask.fill",
            tint: 1
        )
        let periodicTable = set(
            "Periodic Table",
            notes: nil,
            in: chemistry
        )
        card(
            front: "What is the chemical symbol for gold?",
            back: "Au",
            in: periodicTable
        )
        card(
            front: "How many protons does carbon have?",
            back: "Six",
            in: periodicTable
        )

        let history = subject(
            "History",
            notes: "The people and events that shaped the modern world.",
            symbol: "clock.arrow.circlepath",
            tint: 8
        )
        let twentiethCentury = set(
            "20th Century",
            notes: nil,
            in: history
        )
        card(
            front: "In which year did the Berlin Wall fall?",
            back: "1989",
            in: twentiethCentury
        )

        let japanese = subject(
            "Japanese",
            notes: "Kana, everyday phrases, and a little grammar.",
            symbol: "text.book.closed.fill",
            tint: 3
        )
        let hiragana = set(
            "Hiragana",
            notes: "The first Japanese writing system.",
            in: japanese
        )
        for (front, back) in [
            ("あ", "a"),
            ("か", "ka"),
            ("さ", "sa"),
            ("た", "ta"),
            ("な", "na"),
        ] {
            card(front: front, back: back, in: hiragana)
        }
        let phrases = set(
            "Everyday Phrases",
            notes: "Useful lines for a first trip.",
            in: japanese
        )
        for (front, back) in [
            ("Hello", "こんにちは (konnichiwa)"),
            ("Thank you", "ありがとう (arigatō)"),
            ("Good morning", "おはようございます (ohayō gozaimasu)"),
            ("Excuse me", "すみません (sumimasen)"),
        ] {
            card(front: front, back: back, in: phrases)
        }

        let music = subject(
            "Music Theory",
            notes: "Intervals, scales, and the notes in between.",
            symbol: "music.note",
            tint: 4
        )
        let intervals = set(
            "Intervals",
            notes: nil,
            in: music
        )
        card(
            front: "How many semitones are in an octave?",
            back: "Twelve",
            in: intervals
        )
        card(
            front: "What interval is C to G?",
            back: "A perfect fifth",
            in: intervals
        )

        let spanish = subject(
            "Spanish",
            notes: "Everyday words for the first weeks.",
            symbol: "globe.europe.africa.fill",
            tint: 5
        )
        let basics = set(
            "Basics",
            notes: nil,
            in: spanish
        )
        card(front: "Hello", back: "Hola", in: basics)
        card(front: "Thank you", back: "Gracias", in: basics)

        mark(cards.first, known: true, daysAgo: 2, in: context)
        mark(cards[3], known: true, daysAgo: 1, in: context)
        mark(cards[6], known: false, daysAgo: 4, in: context)
        mark(cards[10], known: true, daysAgo: 6, in: context)

        try? context.save()

        return Library(container: container, subjects: subjects, cards: cards)
    }

    /// A card with typed front and back sides.
    static func makeCard(
        front: String,
        back: String,
        position: Int,
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

    // MARK: - Review History

    private static func mark(
        _ card: Flashcard?,
        known: Bool,
        daysAgo: Double,
        in context: ModelContext
    ) {
        guard let card else { return }

        let date = Date(timeIntervalSinceNow: -daysAgo * 86_400)
        card.isKnown = known
        card.lastReviewedAt = date

        let review = FlashcardReview(correct: known, reviewedAt: date)
        review.card = card
        context.insert(review)
    }

    // MARK: - Sync Log

    /// A monitor with a realistic partial export failure, for the sync log
    /// demo. The CloudKit observer is harmless because no mirror is running.
    static func syncMonitor() -> CloudKitSyncMonitor {
        let summary = "What is the capital of France?"
        let setName = "Geography"

        let records = [
            CloudKitSyncMonitor.SyncFailure.RecordError(
                record: "CD_Flashcard_2F6C2B0D-9A4A-4A6E-9A75-2B6B4F0A7C11",
                domain: "CKErrorDomain",
                code: 12,
                message: "Invalid arguments",
                count: 2,
                action: .upload,
                entity: "Flashcard",
                item: String(
                    localized: "contentView.syncLog.item.cardInSet",
                    defaultValue: "Card “\(summary)” in “\(setName)”"
                )
            ),
            CloudKitSyncMonitor.SyncFailure.RecordError(
                record: "CD_FlashcardSide_6A1E5D31-2C68-4C8A-BA3F-1D8F2E9C4B02",
                domain: "CKErrorDomain",
                code: 12,
                message: "Invalid arguments",
                count: 1,
                action: .upload,
                entity: "FlashcardSide",
                item: String(
                    localized: "contentView.syncLog.item.backSide",
                    defaultValue: "Back of “\(summary)”"
                )
            ),
        ]

        let details = [
            CloudKitSyncMonitor.SyncFailure.Detail(
                kind: .underlying,
                domain: "CKErrorDomain",
                code: 2,
                message: "Partial failure",
                count: 1
            ),
            CloudKitSyncMonitor.SyncFailure.Detail(
                kind: .failureReason,
                domain: nil,
                code: nil,
                message: "The server rejected the record.",
                count: 1
            ),
        ]

        let export = CloudKitSyncMonitor.SyncFailure(
            operation: .export,
            message: "Failed to export 3 records",
            domain: "CKErrorDomain",
            code: 2,
            details: details,
            recordErrors: records,
            lastSeenAt: Date(timeIntervalSinceNow: -90),
            count: 3
        )

        let setup = CloudKitSyncMonitor.SyncFailure(
            operation: .setup,
            message: "The iCloud account is not available",
            domain: "CKErrorDomain",
            code: 9,
            details: [],
            recordErrors: [],
            lastSeenAt: Date(timeIntervalSinceNow: -240),
            count: 1
        )

        return CloudKitSyncMonitor(failures: [export, setup])
    }
}
