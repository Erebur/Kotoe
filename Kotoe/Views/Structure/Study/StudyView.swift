//
//  StudyView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import SwiftData
import SwiftUI

#if os(iOS)
    import UIKit
#endif

// MARK: - Study Mode

/// How a session asks for an answer.
enum StudyMode {
    case guess
    case type
}

/// Opens when a set is tapped. A start screen asks whether the user wants to
/// guess or type the answer and whether to shuffle. A tap reveals the answer;
/// in guessing mode a swipe right marks the card as known and a swipe left
/// puts it back at the end of the queue. Cards marked "Again" come back until
/// they are marked "Got It", and every mark is stored on the card and in its
/// review history.
struct StudyView: View {

    let title: String
    let cards: [Flashcard]
    let tint: Color

    /// Whether typing answers must match upper-/lowercase exactly. Stored per
    /// set so every session of the set behaves the same.
    @State private var checksCapitalization: Bool

    /// The set this session was opened from, so the capitalisation toggle can
    /// be persisted back to it. `nil` for the cards-only entry point.
    private let sourceSet: FlashcardSet?

    init(
        title: String,
        cards: [Flashcard],
        tint: Color = KotoeTheme.accent,
        checksCapitalization: Bool = false
    ) {
        self.title = title
        self.cards = cards
        self.tint = tint
        self._checksCapitalization = State(initialValue: checksCapitalization)
        self.sourceSet = nil
    }

    init(flashcardSet: FlashcardSet) {
        self.title = flashcardSet.name
        self.cards = flashcardSet.sortedFlashcards
        self.tint = flashcardSet.style.tint
        self._checksCapitalization = State(
            initialValue: flashcardSet.checksCapitalization
        )
        self.sourceSet = flashcardSet
    }

    @Environment(\.modelContext) private var modelContext

    @State private var queue: [Flashcard] = []
    @State private var total = 0
    @State private var known = 0
    @State private var incorrect = 0
    @State private var isFlipped = false
    @State private var flipSignal = 0
    @State private var exitSignal = 0
    @State private var exitCorrect = true
    @State private var isMarking = false
    @State private var generation = 0

    // MARK: Session Setup

    @State private var showsStart = true
    @State private var selectedMode: StudyMode = .guess
    @State private var shufflesCards = false
    @State private var sessionMode: StudyMode = .guess
    @State private var sessionShuffled = false

    @State private var typedAnswer = NSAttributedString()

    // MARK: Typing verdict state

    /// The card that received the last typed verdict, shown while the outcome
    /// lingers before the session moves on.
    @State private var lastTypedCard: Flashcard?
    @State private var lastTypedCorrect = false

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)

            content
        }
        .navigationTitle(title)
        .inlineNavigationBarTitle()
        .toolbar {
            if !showsStart && !cards.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showsStart = true
                        } label: {
                            Label(
                                "studyView.options.newSession",
                                systemImage: "slider.horizontal.3"
                            )
                        }
                        .tint(.primary)

                        Button {
                            start(shuffled: false)
                        } label: {
                            Label(
                                "studyView.options.restart",
                                systemImage: "arrow.counterclockwise"
                            )
                        }
                        .tint(.primary)

                        Button {
                            start(shuffled: true)
                        } label: {
                            Label(
                                "studyView.options.restartShuffled",
                                systemImage: "shuffle"
                            )
                        }
                        .tint(.primary)
                    } label: {
                        Label(
                            "studyView.options.title",
                            systemImage: "ellipsis.circle"
                        )
                    }
                    .tint(.primary)
                    .help("studyView.options.help")
                }
            }
        }
        #if os(macOS)
            // StudyView is not scrollable, so macOS would otherwise give its
            // window toolbar an opaque background instead of the tinted one
            // that scrollable screens get.
            .toolbarBackground(.hidden, for: .windowToolbar)
        #endif
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if cards.isEmpty {
            StudyEmptyState(tint: tint)
        } else if showsStart {
            StudyStartScreen(
                selectedMode: $selectedMode,
                shufflesCards: $shufflesCards,
                checksCapitalization: $checksCapitalization,
                tint: tint,
                onStart: beginSession
            )
            .transition(.opacity)
        } else if let card = queue.first {
            studyContent(for: card)
        } else {
            StudyFinishedView(
                total: total,
                tint: tint,
                onStudyAgain: { start(shuffled: sessionShuffled) },
                onShuffle: { start(shuffled: true) }
            )
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    // MARK: - Study

    private func studyContent(for card: Flashcard) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 18) {
                StudyProgressCard(
                    known: known,
                    incorrect: incorrect,
                    total: total,
                    queueCount: queue.count,
                    tint: tint
                )

                ZStack {
                    StudyCardView(
                        card: card,
                        tint: tint,
                        showsHint: sessionMode == .guess,
                        allowsSwipeAnswer: sessionMode == .guess,
                        flipSignal: flipSignal,
                        exitSignal: exitSignal,
                        exitCorrect: exitCorrect
                    ) { flipped in
                        isFlipped = flipped
                    } onAnswer: { correct in
                        answer(correct: correct)
                    }
                    .id("\(card.id.uuidString)-\(generation)")
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .opacity
                        )
                    )
                }
                .frame(
                    height: max(
                        190,
                        min(620, proxy.size.height - 210)
                    )
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .onTapGesture {
                    guard sessionMode == .guess else { return }
                    flipCurrentCard()
                }

                StudyControls(
                    isFlipped: isFlipped,
                    sessionMode: sessionMode,
                    checksCapitalization: checksCapitalization,
                    typedAnswer: $typedAnswer,
                    lastTypedCorrect: lastTypedCorrect,
                    tint: tint,
                    onNext: {
                        mark(correct: true)
                    },
                    onIncorrect: {
                        mark(correct: false)
                    },
                    onSubmit: submitTypedAnswer
                )
                .frame(height: 58)
                .animation(.snappy(duration: 0.28), value: isFlipped)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Logic

    private func beginSession() {
        sessionMode = selectedMode
        sessionShuffled = shufflesCards

        // Persist the capitalisation choice back to the set so it is
        // set-wide and survives across sessions.
        if let sourceSet {
            sourceSet.checksCapitalization = checksCapitalization
            try? modelContext.save()
        }

        start(shuffled: shufflesCards)
    }

    private func start(shuffled: Bool) {
        var cards = self.cards
        if shuffled { cards.shuffle() }

        withTransaction(Transaction(animation: nil)) {
            queue = cards
            total = cards.count
            known = 0
            incorrect = 0
            isFlipped = false
            flipSignal = 0
            isMarking = false
            generation += 1
            typedAnswer = NSAttributedString()
            lastTypedCard = nil
            lastTypedCorrect = false
            showsStart = false
        }
    }

    /// Reveals the back of the current card in guessing mode, and flips it back
    /// to the front when tapped again.
    private func flipCurrentCard() {
        guard !queue.isEmpty else { return }
        flipSignal += 1
    }

    /// Starts the card's fly-off animation through `exitSignal`. The card calls
    /// back into `answer` once it has left the screen.
    private func mark(correct: Bool) {
        guard !isMarking, !queue.isEmpty else { return }

        isMarking = true
        exitCorrect = correct
        exitSignal += 1
    }

    private func answer(correct: Bool) {
        guard let card = queue.first else { return }

        isMarking = false

        withAnimation(.snappy(duration: 0.36)) {
            queue.removeFirst()

            if correct {
                known += 1
            } else {
                incorrect += 1
                queue.append(card)
            }

            // A new generation gives the incoming card a fresh, unflipped
            // state without flipping the outgoing card back while it leaves.
            generation += 1
            isFlipped = false
            typedAnswer = NSAttributedString()
            // A manual advance cancels the pending automatic verdict step.
            lastTypedCard = nil
        }

        record(correct, for: card)
    }

    /// In typing mode the answer is judged automatically once it has been
    /// typed.
    private func submitTypedAnswer() {
        guard sessionMode == .type, !isFlipped, !queue.isEmpty else { return }

        let card = queue.first!
        let expected = MarkdownFormatter.plainText(
            from: card.back?.plainText ?? ""
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = typedAnswer.string
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let correct: Bool
        if checksCapitalization {
            correct = answer == expected
        } else {
            correct = answer.lowercased() == expected.lowercased()
        }

        lastTypedCorrect = correct
        lastTypedCard = card

        withAnimation(.snappy(duration: 0.25)) {
            flipCurrentCard()
        }

        // Record the mark and show the outcome for a moment before moving on.
        record(correct, for: card)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            finishTypedCard(correct: correct, card: card)
        }
    }

    private func finishTypedCard(correct: Bool, card: Flashcard) {
        guard lastTypedCard?.id == card.id else { return }

        withAnimation(.snappy(duration: 0.36)) {
            queue.removeFirst()

            if correct {
                known += 1
            } else {
                incorrect += 1
                queue.append(card)
            }

            generation += 1
            isFlipped = false
            typedAnswer = NSAttributedString()
            lastTypedCard = nil
        }
    }

    /// Stores the latest knowledge state on the card and appends a review so
    /// the mark survives relaunch and syncs with the card through iCloud.
    private func record(_ correct: Bool, for card: Flashcard) {
        card.isKnown = correct
        card.lastReviewedAt = .now

        let review = FlashcardReview(
            correct: correct,
            reviewedAt: .now
        )

        modelContext.insert(review)
        card.reviews = (card.reviews ?? []) + [review]

        do {
            try modelContext.save()
        } catch {
            print("Could not save study review: \(error)")
        }
    }
}

// MARK: - Previews

#Preview("Study Session") {
    let scene = PreviewData.scene()

    return NavigationStack {
        StudyView(flashcardSet: scene.set)
    }
    .modelContainer(scene.container)
}

#Preview("Study Card") {
    let scene = PreviewData.scene()
    let tint = KotoeTheme.palette[2]

    return ZStack {
        AmbientBackground(tint: tint)

        StudyCardView(
            card: scene.card,
            tint: tint,
            showsHint: true,
            allowsSwipeAnswer: true,
            flipSignal: 0,
            exitSignal: 0,
            exitCorrect: true,
            onFlipChanged: { _ in },
            onAnswer: { _ in }
        )
        .frame(width: 420, height: 560)
    }
    .modelContainer(scene.container)
}
