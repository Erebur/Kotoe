//
//  StudyProgressCard.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

/// The small progress indicator: a ring whose green segment shows learned
/// cards and whose red segment shows incorrect cards, followed by the
/// "known of total" and "cards left" labels.
struct StudyProgressCard: View {

    let known: Int
    let incorrect: Int
    let total: Int
    let queueCount: Int
    let tint: Color

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(known) / Double(total)
    }

    /// Fraction of the ring filled by the correct (green) segment.
    private var knownRingProgress: Double {
        guard total > 0 else { return 0 }
        return min(Double(known) / Double(total), 1)
    }

    /// Fraction of the ring filled by correct + incorrect combined.
    private var reviewedRingProgress: Double {
        guard total > 0 else { return 0 }
        return min(Double(known + incorrect) / Double(total), 1)
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
            defaultValue: "\(queueCount) cards left"
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: reviewedRingProgress)
                    .stroke(
                        LinearGradient(
                            colors: [KotoeTheme.failure, KotoeTheme.failure.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.4), value: reviewedRingProgress)

                Circle()
                    .trim(from: 0, to: knownRingProgress)
                    .stroke(
                        LinearGradient(
                            colors: [KotoeTheme.success, KotoeTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy(duration: 0.4), value: knownRingProgress)

                Text(verbatim: "\(Int((progress * 100).rounded()))%")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
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
                .opacity(queueCount == 1 ? 1 : 0.45)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            KotoeTheme.cardBackground.opacity(0.6),
            in: Capsule()
        )
    }
}

// MARK: - Previews

#Preview("Study Progress Card") {
    StudyProgressCard(
        known: 3,
        incorrect: 1,
        total: 10,
        queueCount: 6,
        tint: KotoeTheme.accent
    )
    .padding(40)
}
