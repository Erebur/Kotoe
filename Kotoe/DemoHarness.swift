// TEMPORARY visual QA harness. Deleted before finishing.

import PencilKit
import SwiftData
import SwiftUI

enum DemoMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo")
    }

    static var screen: String {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--screen=") }?
            .replacingOccurrences(of: "--screen=", with: "") ?? "library"
    }

    static var forceLight: Bool {
        ProcessInfo.processInfo.arguments.contains("--light")
    }
}

@MainActor
enum DemoSeed {
    static func populate(_ context: ModelContext) {
        let japanese = Subject(
            name: "Japanese",
            notes: "Everyday vocabulary, greetings and the first kanji."
        )
        context.insert(japanese)

        makeSet(
            name: "Greetings",
            subject: japanese,
            position: 0,
            cards: [
                ("こんにちは", "Hello / Good afternoon"),
                ("おはようございます", "Good morning"),
                ("ありがとう", "Thank you"),
                ("すみません", "Excuse me / Sorry"),
                ("さようなら", "Goodbye"),
            ],
            context: context
        )

        makeSet(
            name: "Hiragana",
            subject: japanese,
            position: 1,
            cards: [
                ("あ", "a"),
                ("い", "i"),
                ("う", "u"),
                ("え", "e"),
                ("お", "o"),
            ],
            context: context
        )

        let biology = Subject(
            name: "Biology",
            notes: "Cell structure, organelles and the basics of genetics."
        )
        context.insert(biology)

        makeSet(
            name: "Cell Organelles",
            subject: biology,
            position: 0,
            cards: [
                ("Mitochondria", "Produces ATP through cellular respiration"),
                ("Nucleus", "Stores DNA and coordinates cell activity"),
                ("Ribosome", "Builds proteins from amino acids"),
                ("Golgi apparatus", "Packages and ships proteins"),
            ],
            context: context
        )

        let art = Subject(
            name: "Art History",
            notes: "Movements, artists and the stories behind famous works."
        )
        context.insert(art)

        makeSet(
            name: "Impressionism",
            subject: art,
            position: 0,
            cards: [
                ("Claude Monet", "Water Lilies"),
                ("Pierre-Auguste Renoir", "Bal du moulin de la Galette"),
                ("Edgar Degas", "The Ballet Class"),
            ],
            context: context
        )

        try? context.save()
    }

    private static func makeSet(
        name: String,
        subject: Subject,
        position: Int,
        cards: [(String, String)],
        context: ModelContext
    ) {
        let set = FlashcardSet(name: name, position: position)
        context.insert(set)
        set.subject = subject

        for (index, pair) in cards.enumerated() {
            let card = Flashcard(position: index)
            context.insert(card)
            card.flashcardSet = set

            let front = FlashcardSide(role: .front)
            let back = FlashcardSide(role: .back)
            context.insert(front)
            context.insert(back)

            front.setPlainText(pair.0)
            back.setPlainText(pair.1)

            card.setFront(front)
            card.setBack(back)
        }
    }
}

struct DemoRootView: View {

    @Query(sort: \Subject.name) private var subjects: [Subject]
    @State private var isPresented = false
    @State private var sheetName = "Advanced Biology"

    private var firstSet: FlashcardSet? {
        subjects.first?.sortedFlashcardSets.first
    }

    var body: some View {
        Group {
            switch DemoMode.screen {
            case "subject":
                if let subject = subjects.first {
                    NavigationStack {
                        SubjectView(subject: subject)
                    }
                } else {
                    ProgressView()
                }

            case "study":
                if let set = firstSet {
                    NavigationStack {
                        StudyView(flashcardSet: set)
                    }
                } else {
                    ProgressView()
                }

            case "setedit":
                if let set = firstSet {
                    FlashcardSetEditView(flashcardSet: set)
                } else {
                    ProgressView()
                }

            case "cardedit":
                if let card = firstSet?.sortedFlashcards.first {
                    NavigationStack {
                        FlashcardEditorView(card: card)
                    }
                } else {
                    ProgressView()
                }

            case "newsheet":
                ZStack {
                    AmbientBackground()
                    Text("Create sheet host")
                        .foregroundStyle(.secondary)
                }
                .sheet(isPresented: $isPresented) {
                    CreateItemSheet(
                        title: "New Subject",
                        prompt: "A subject groups related flashcard sets, like a course or a language.",
                        systemImage: "books.vertical.fill",
                        placeholder: "Subject name",
                        actionTitle: "Create",
                        name: $sheetName,
                        onCreate: {},
                        onCancel: {}
                    )
                    .dialogSheet()
                }

            case "setedit-sheet":
                ZStack {
                    AmbientBackground()
                    Text("Set editor sheet host")
                        .foregroundStyle(.secondary)
                }
                .sheet(isPresented: $isPresented) {
                    if let set = firstSet {
                        FlashcardSetEditView(flashcardSet: set)
                            .editorSheetSize()
                    }
                }

            case "drawing-sheet":
                ZStack {
                    AmbientBackground()
                    Text("Drawing sheet host")
                        .foregroundStyle(.secondary)
                }
                .sheet(isPresented: $isPresented) {
                    DrawingEditorView(initial: .init()) { _ in }
                }

            default:
                ContentView()
            }
        }
        .onAppear {
            if ["newsheet", "setedit-sheet", "drawing-sheet"].contains(
                DemoMode.screen
            ) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPresented = true
                }
            }
        }
        .preferredColorScheme(DemoMode.forceLight ? .light : nil)
    }
}
