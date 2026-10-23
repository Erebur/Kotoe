//
//  StudyCardView.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftData
import SwiftUI

/// The study card: front/back faces with a gradient background echoing the
/// app's brand gradient. In guessing mode the card can be swiped — it tilts
/// under the finger and flies off in the swipe direction (green for correct,
/// red for incorrect) before `onAnswer` is called.
struct StudyCardView: View {

    let card: Flashcard
    let tint: Color
    let showsHint: Bool
    let allowsSwipeAnswer: Bool
    let flipSignal: Int
    let onFlipChanged: (Bool) -> Void
    let onAnswer: (Bool) -> Void

    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragDirection: Int = 0 // 1 = correct, -1 = incorrect, 0 = none

    var body: some View {
        ZStack {
            face(
                side: card.front,
                label: "studyView.card.front",
                symbol: "questionmark",
                tint: tint,
                showsHint: showsHint
            )
            .opacity(isFlipped ? 0 : 1)

            if isFlipped {
                face(
                    side: card.back,
                    label: "studyView.card.back",
                    symbol: "sparkles",
                    tint: KotoeTheme.success,
                    showsHint: false
                )
                .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.28), value: isFlipped)
        .contentShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .offset(x: dragOffset.width, y: dragOffset.height)
        .rotationEffect(.degrees(dragOffset.width / 18))
        .scaleEffect(1 - abs(dragOffset.width) / 1400)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard allowsSwipeAnswer else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) else { return }
                    dragDirection = dx > 0 ? 1 : -1
                    withAnimation(.snappy(duration: 0.12)) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    guard allowsSwipeAnswer else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height

                    guard abs(dx) > abs(dy), abs(dx) > 40 else {
                        dragDirection = 0
                        withAnimation(.snappy(duration: 0.2)) {
                            dragOffset = .zero
                        }
                        return
                    }

                    let correct = dx > 0
                    let direction: CGFloat = correct ? 1 : -1

                    withAnimation(.snappy(duration: 0.22)) {
                        dragOffset = CGSize(width: direction * 750, height: 0)
                    }

                    // Let the card fly off, then tell the parent to advance.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        onAnswer(correct)
                    }
                }
        )
        .onChange(of: flipSignal) {
            toggle()
        }
    }

    private func face(
        side: FlashcardSide?,
        label: LocalizedStringKey,
        symbol: String,
        tint: Color,
        showsHint: Bool
    ) -> some View {
        ZStack {
            // Gradient card background echoing the app's brand gradient.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.mix(with: .black, by: 0.18),
                            tint.mix(with: .black, by: 0.34)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.9)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(KotoeTheme.cardBackground.opacity(0.85))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
                .shadow(
                    color: .black.opacity(0.22),
                    radius: 24,
                    y: 12
                )

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
                    .background(tint.opacity(0.20), in: Capsule())

                    Spacer()
                }

                Spacer(minLength: 0)

                FlashcardSideContentView(side: side, textFont: .title)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                if showsHint {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                        Text("studyView.card.tapToFlip")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func toggle() {
        withAnimation(.snappy(duration: 0.28)) {
            isFlipped.toggle()
        }

        onFlipChanged(isFlipped)
    }
}
