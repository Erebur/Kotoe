//
//  StudyView.swift
//  Kōtoe
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
    let tint: Color

    init(
        title: String,
        cards: [Flashcard],
        tint: Color = KotoeTheme.accent
    ) {
        self.title = title
        self.cards = cards
        self.tint = tint
    }

    init(flashcardSet: FlashcardSet) {
        self.init(
            title: flashcardSet.name,
            cards: flashcardSet.sortedFlashcards,
            tint: flashcardSet.style.tint
        )
    }

    @State private var queue: [Flashcard] = []
    @State private var total = 0
    @State private var known = 0
    @State private var isFlipped = false
    @State private var flipSignal = 0
    @State private var generation = 0
    @State private var didStart = false

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(known) / Double(total)
    }

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)

            content
        }
        .navigationTitle(title)
        .inlineNavigationBarTitle()
        .toolbar {
            if total > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
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
        .onAppear {
            guard !didStart else { return }
            didStart = true
            start(shuffled: false)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if total == 0 {
            emptyState
        } else if let card = queue.first {
            studyContent(for: card)
        } else {
            finishedView
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    // MARK: - Study

    private func studyContent(for card: Flashcard) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 18) {
                progressCard

                ZStack {
                    StudyCard(
                        card: card,
                        tint: tint,
                        flipSignal: flipSignal
                    ) { flipped in
                        isFlipped = flipped
                    }
                    .id("\(card.id.uuidString)-\(generation)")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing)
                                .combined(with: .opacity),
                            removal: .move(edge: .leading)
                                .combined(with: .opacity)
                        )
                    )
                }
                .frame(
                    height: max(
                        190,
                        min(620, proxy.size.height - 210)
                    )
                )

                controls
                    .frame(height: 58)
                    .animation(.snappy(duration: 0.28), value: isFlipped)
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var progressLabel: String {
        String(
            localized: "studyView.progress.learned",
            defaultValue: "\(known) of \(total) learned"
        )
    }

    private var cardsLeftLabel: String {
        String(
            localized: "studyView.progress.cardsLeft",
            defaultValue: "\(queue.count) cards left"
        )
    }

    private var progressCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [tint, KotoeTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 5,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.4), value: known)

                Text(verbatim: "\(Int((progress * 100).rounded()))%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: progressLabel)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())

                Text(verbatim: cardsLeftLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)

            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KotoeTheme.gold)
                .opacity(queue.count == 1 ? 1 : 0.45)
        }
        .cardSurface(padding: 14, tint: tint)
    }

    @ViewBuilder
    private var controls: some View {
        if queue.isEmpty {
            Color.clear
        } else if isFlipped {
            HStack(spacing: 12) {
                Button {
                    answer(correct: false)
                } label: {
                    Label(
                        "studyView.controls.again",
                        systemImage: "arrow.counterclockwise"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    StudyActionButtonStyle(
                        tint: Color(red: 0.70, green: 0.45, blue: 0.20)
                    )
                )
                .keyboardShortcut("1", modifiers: [])

                Button {
                    answer(correct: true)
                } label: {
                    Label("studyView.controls.gotIt", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyActionButtonStyle(tint: KotoeTheme.success))
                .keyboardShortcut("2", modifiers: [])
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Button {
                flipCurrentCard()
            } label: {
                Label(
                    "studyView.controls.revealAnswer",
                    systemImage: "eye.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .controlSize(.large)
            .keyboardShortcut(.space, modifiers: [])
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Empty / Finished

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 124, height: 124)

                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 50))
                    .foregroundStyle(tint)
            }

            Text("studyView.emptyState.title")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(
                "studyView.emptyState.message"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
        }
        .padding(30)
    }

    private var finishedMessage: String {
        String(
            localized: "studyView.finished.message",
            defaultValue: "You reviewed all \(total) cards in this round."
        )
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(KotoeTheme.success.opacity(0.12))
                    .frame(width: 132, height: 132)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KotoeTheme.success, KotoeTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: KotoeTheme.success.opacity(0.25),
                        radius: 12,
                        y: 4
                    )
            }

            VStack(spacing: 6) {
                Text("studyView.finished.title")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text(verbatim: finishedMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    start(shuffled: false)
                } label: {
                    Label(
                        "studyView.finished.studyAgain",
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)

                Button {
                    start(shuffled: true)
                } label: {
                    Label("studyView.finished.shuffle", systemImage: "shuffle")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(30)
        .frame(maxWidth: 520)
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
            flipSignal = 0
            generation += 1
        }
    }

    private func flipCurrentCard() {
        guard !isFlipped, !queue.isEmpty else { return }
        flipSignal += 1
    }

    private func answer(correct: Bool) {
        guard !queue.isEmpty else { return }

        withAnimation(.snappy(duration: 0.36)) {
            let card = queue.removeFirst()

            if correct {
                known += 1
            } else {
                queue.append(card)
            }

            // A new generation gives the incoming card a fresh, unflipped
            // state without flipping the outgoing card back while it leaves.
            generation += 1
            isFlipped = false
        }
    }
}

// MARK: - Study Card

private struct StudyCard: View {

    let card: Flashcard
    let tint: Color
    let flipSignal: Int
    let onFlipChanged: (Bool) -> Void

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            face(
                side: card.front,
                label: "studyView.card.front",
                symbol: "questionmark",
                tint: tint
            )
            .opacity(isFlipped ? 0 : 1)

            face(
                side: card.back,
                label: "studyView.card.back",
                symbol: "sparkles",
                tint: KotoeTheme.success
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.55
        )
        .animation(
            .spring(response: 0.55, dampingFraction: 0.82),
            value: isFlipped
        )
        .contentShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .onTapGesture {
            toggle()
        }
        .onChange(of: flipSignal) {
            toggle()
        }
    }

    private func face(
        side: FlashcardSide?,
        label: LocalizedStringKey,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 10, weight: .bold))

                    Text(label)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12), in: Capsule())

                Spacer()
            }

            Spacer(minLength: 0)

            FlashcardSideContentView(side: side, textFont: .title)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                Text("studyView.card.tapToFlip")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(KotoeTheme.cardBackground)

                LinearGradient(
                    colors: [tint.opacity(0.13), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 160)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .shadow(
                color: .black.opacity(0.10),
                radius: 20,
                y: 9
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(0.34), KotoeTheme.hairline],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            isFlipped.toggle()
        }

        onFlipChanged(isFlipped)
    }
}

// MARK: - Action Button

private struct StudyActionButtonStyle: ButtonStyle {

    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                tint,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: tint.opacity(0.28), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
