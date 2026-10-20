//
//  StudyView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import SwiftUI
#if os(iOS)
    import UIKit
#endif

/// Opens when a set is tapped. Shows one card at a time; tap to flip,
/// then mark it "Got It" or "Again" (cards marked "Again" come back
/// at the end of the queue).
struct StudyView: View {

    let title: String
    let cards: [Flashcard]

    init(title: String, cards: [Flashcard]) {
        self.title = title
        self.cards = cards
    }

    init(flashcardSet: FlashcardSet) {
        self.init(title: flashcardSet.name, cards: flashcardSet.sortedFlashcards)
    }

    @State private var queue: [Flashcard] = []
    @State private var total = 0
    @State private var known = 0
    @State private var isFlipped = false
    @State private var didStart = false

    var body: some View {
        Group {
            if total == 0 {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Swipe left on the set or long press it to add cards.")
                )
            } else if let card = queue.first {
                studyContent(for: card)
            } else {
                finishedView
            }
        }
        .toolbar {
            if total > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            start(shuffled: false)
                        } label: {
                            Label("Restart", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            start(shuffled: true)
                        } label: {
                            Label("Restart Shuffled", systemImage: "shuffle")
                        }
                    } label: {
                        Label("Options", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            start(shuffled: false)
        }
    }

    // MARK: - Study

    private func studyContent(for card: Flashcard) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                ProgressView(value: Double(known), total: Double(max(total, 1)))

                Text("\(known) of \(total) learned")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            FlipCard(card: card, isFlipped: isFlipped)
                .id(card.id)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.5)) {
                        isFlipped.toggle()
                    }
                }

            ZStack {
                if isFlipped {
                    HStack(spacing: 12) {
                        Button {
                            answer(correct: false)
                        } label: {
                            Label("Again", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.orange)

                        Button {
                            answer(correct: true)
                        } label: {
                            Label("Got It", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .tint(.green)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Text("Tap the card to reveal the answer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 52)
        }
        .padding()
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All done!")
                .font(.title.weight(.bold))

            Text("You've learned all \(total) cards.")
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                Button("Study Again") { start(shuffled: false) }
                    .buttonStyle(.borderedProminent)

                Button("Shuffle & Study Again") { start(shuffled: true) }
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Logic

    private func start(shuffled: Bool) {
        var cards = self.cards
        if shuffled { cards.shuffle() }

        withTransaction(Transaction(animation: nil)) {
            queue = cards
            total = cards.count
            known = 0
            isFlipped = false
        }
    }

    private func answer(correct: Bool) {
        guard !queue.isEmpty else { return }

        // Reset the flip without animating, so the next card's front is
        // shown immediately instead of the old card flipping back.
        withTransaction(Transaction(animation: nil)) {
            let card = queue.removeFirst()

            if correct {
                known += 1
            } else {
                queue.append(card)
            }

            isFlipped = false
        }
    }
}

// MARK: - Flip Card

private struct FlipCard: View {

    let card: Flashcard
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(card.front, label: "Front")
                .opacity(isFlipped ? 0 : 1)

            face(card.back, label: "Back")
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0)
        )
    }

    private func face(_ side: FlashcardSide?, label: String) -> some View {
        VStack {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            FlashcardSideContentView(side: side)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            cardBackground,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    /// Card surface color, using each platform's system background.
    private var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
