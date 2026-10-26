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

    @Environment(\.colorScheme) private var colorScheme

    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragDirection: Int = 0 // 1 = correct, -1 = incorrect, 0 = none

    private let cornerRadius: CGFloat = 28

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
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
        let shape = RoundedRectangle(
            cornerRadius: cornerRadius,
            style: .continuous
        )

        return ZStack {
            // Saturated gradient in the subject/set color, with the same
            // warm gold glow the ambient background uses.
            shape.fill(backgroundGradient(tint: tint))

            shape.fill(
                RadialGradient(
                    colors: [.white.opacity(0.24), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 520
                )
            )

            shape.fill(
                RadialGradient(
                    colors: [KotoeTheme.gold.opacity(0.24), .clear],
                    center: .bottomTrailing,
                    startRadius: 10,
                    endRadius: 460
                )
            )

            // Oversized watermark of the face symbol, clipped by the card.
            Image(systemName: symbol)
                .font(.system(size: 190, weight: .bold))
                .foregroundStyle(.white.opacity(0.09))
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .bottomTrailing
                )
                .offset(x: 34, y: 46)
                .allowsHitTesting(false)

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
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }

                    Spacer()
                }

                Spacer(minLength: 0)

                FlashcardSideContentView(side: side, textStyle: .title)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)

                if showsHint {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                        Text("studyView.card.tapToFlip")
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.14), radius: 6, y: 1)

            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.45), .white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
        }
        .clipShape(shape)
        .shadow(color: tint.opacity(0.34), radius: 26, y: 14)
        .shadow(color: .black.opacity(0.16), radius: 8, y: 2)
    }

    /// Light comes from the top-left in the rest of the app, so the card is
    /// lightest there and deepest in the opposite corner.
    private func backgroundGradient(tint: Color) -> LinearGradient {
        let lightStop = colorScheme == .dark ? 0.04 : 0.14
        let darkStop = colorScheme == .dark ? 0.46 : 0.30

        return LinearGradient(
            colors: [
                tint.mix(with: .white, by: lightStop),
                tint,
                tint.mix(with: .black, by: darkStop),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func toggle() {
        withAnimation(.snappy(duration: 0.28)) {
            isFlipped.toggle()
        }

        onFlipChanged(isFlipped)
    }
}
