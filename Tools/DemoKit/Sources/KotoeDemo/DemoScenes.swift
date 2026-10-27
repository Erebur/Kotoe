//
//  DemoScenes.swift
//  Kōtoe DemoKit
//
//  Named screens the headless renderer can capture.
//

import SwiftData
import SwiftUI

/// One named demo screen.
struct DemoScene {
    let id: String
    let title: String
    let defaultSize: CGSize
    let makeView: @MainActor () -> AnyView
}

/// The scenes available from `Tools/demo <scene>`.
///
/// Add a scene here when a change needs a screenshot that the existing scenes
/// do not cover. Keep the view in the state you want to show; do not change
/// production behavior just to make a demo easier.
@MainActor
enum DemoScenes {

    static var all: [DemoScene] {
        [
            library,
            emptyLibrary,
            subject,
            setEditor,
            cardEditor,
            studyStart,
            studyCard,
            studyFinished,
            importCards,
            appearance,
            syncLog,
        ]
    }

    static func scene(id: String) -> DemoScene? {
        all.first { $0.id == id }
    }

    // MARK: - Library

    private static var library: DemoScene {
        DemoScene(
            id: "library",
            title: "Library",
            defaultSize: CGSize(width: 1100, height: 760)
        ) {
            let library = DemoData.library()
            let monitor = CloudKitSyncMonitor()

            return wrap(
                ContentView().environment(monitor),
                container: library.container
            )
        }
    }

    private static var emptyLibrary: DemoScene {
        DemoScene(
            id: "library-empty",
            title: "Empty library",
            defaultSize: CGSize(width: 1100, height: 760)
        ) {
            let monitor = CloudKitSyncMonitor()

            return wrap(
                ContentView().environment(monitor),
                container: DemoData.container()
            )
        }
    }

    // MARK: - Subject & Editor

    private static var subject: DemoScene {
        DemoScene(
            id: "subject",
            title: "Subject detail",
            defaultSize: CGSize(width: 980, height: 780)
        ) {
            let library = DemoData.library()
            let subject = library.subjects[0]

            return wrap(
                SubjectView(subject: subject),
                container: library.container
            )
        }
    }

    private static var setEditor: DemoScene {
        DemoScene(
            id: "set-editor",
            title: "Set editor",
            defaultSize: CGSize(width: 680, height: 740)
        ) {
            let library = DemoData.library()
            let set = library.subjects[0].sortedFlashcardSets[0]

            return wrap(
                FlashcardSetEditView(flashcardSet: set),
                container: library.container
            )
        }
    }

    private static var cardEditor: DemoScene {
        DemoScene(
            id: "card-editor",
            title: "Card editor",
            defaultSize: CGSize(width: 720, height: 780)
        ) {
            let library = DemoData.library()
            let card = library.cards[0]
            let tint = card.flashcardSet?.style.tint ?? KotoeTheme.accent

            return wrap(
                FlashcardEditorView(card: card, tint: tint),
                container: library.container
            )
        }
    }

    // MARK: - Study

    private static var studyStart: DemoScene {
        DemoScene(
            id: "study-start",
            title: "Study start screen",
            defaultSize: CGSize(width: 980, height: 780)
        ) {
            let library = DemoData.library()
            let set = library.subjects[0].sortedFlashcardSets[0]

            return wrap(
                StudyView(flashcardSet: set),
                container: library.container
            )
        }
    }

    private static var studyCard: DemoScene {
        DemoScene(
            id: "study-card",
            title: "Study card",
            defaultSize: CGSize(width: 900, height: 700)
        ) {
            let library = DemoData.library()
            let card = library.cards[0]

            return wrap(
                ZStack {
                    AmbientBackground(tint: KotoeTheme.accent)

                    StudyCardView(
                        card: card,
                        tint: KotoeTheme.accent,
                        showsHint: true,
                        allowsSwipeAnswer: true,
                        flipSignal: 0,
                        exitSignal: 0,
                        exitCorrect: true,
                        onFlipChanged: { _ in },
                        onAnswer: { _ in }
                    )
                    .padding(56)
                },
                container: library.container
            )
        }
    }

    private static var studyFinished: DemoScene {
        DemoScene(
            id: "study-finished",
            title: "Finished study session",
            defaultSize: CGSize(width: 900, height: 720)
        ) {
            wrap(
                ZStack {
                    AmbientBackground(tint: KotoeTheme.success)

                    StudyFinishedView(
                        total: 19,
                        tint: KotoeTheme.success,
                        onStudyAgain: {},
                        onShuffle: {}
                    )
                    .padding(40)
                }
            )
        }
    }

    // MARK: - Sheets

    private static var importCards: DemoScene {
        DemoScene(
            id: "import",
            title: "Bulk card import",
            defaultSize: CGSize(width: 620, height: 640)
        ) {
            wrap(CardImportView { _ in })
        }
    }

    private static var appearance: DemoScene {
        DemoScene(
            id: "appearance",
            title: "Appearance editor",
            defaultSize: CGSize(width: 460, height: 560)
        ) {
            let library = DemoData.library()
            let subject = library.subjects[0]

            return wrap(
                DemoAppearanceView(subject: subject),
                container: library.container
            )
        }
    }

    private static var syncLog: DemoScene {
        DemoScene(
            id: "sync-log",
            title: "CloudKit error log",
            defaultSize: CGSize(width: 520, height: 560)
        ) {
            wrap(SyncErrorLogView(monitor: DemoData.syncMonitor()))
        }
    }

    // MARK: - Helpers

    /// Puts a window-like background behind sheet content and injects the
    /// in-memory store when the scene needs one.
    private static func wrap<Content: View>(
        _ content: Content,
        container: ModelContainer? = nil
    ) -> AnyView {
        var view = AnyView(
            ZStack {
                KotoeTheme.windowBackground
                content
            }
        )

        if let container {
            view = AnyView(view.modelContainer(container))
        }

        return view
    }
}

// MARK: - Appearance Demo

private struct DemoAppearanceView: View {

    let subject: Subject

    @State private var iconName: String?
    @State private var tintIndex: Int?

    init(subject: Subject) {
        self.subject = subject
        _iconName = State(initialValue: subject.iconName)
        _tintIndex = State(initialValue: subject.tintIndex)
    }

    var body: some View {
        AppearanceEditor(
            title: "contentView.appearanceEditor.title",
            subtitle: "contentView.appearanceEditor.subtitle",
            symbols: KotoeTheme.subjectSymbols,
            defaultSymbol: KotoeTheme.style(for: subject.name).symbol,
            defaultTintIndex: subject.effectiveTintIndex,
            iconName: $iconName,
            tintIndex: $tintIndex
        )
        .frame(width: 460, height: 560)
    }
}
