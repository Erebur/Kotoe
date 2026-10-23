//
//  StudyFinishedView.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

/// Shown when the study queue has drained — the deck is complete.
struct StudyFinishedView: View {

    let total: Int
    let tint: Color
    let onStudyAgain: () -> Void
    let onShuffle: () -> Void

    private var finishedMessage: String {
        String(
            localized: "studyView.finished.message",
            defaultValue: "You reviewed all %lld cards in this round."
        )
    }

    var body: some View {
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
                    onStudyAgain()
                } label: {
                    Label(
                        "studyView.finished.studyAgain",
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)

                Button {
                    onShuffle()
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
}

// MARK: - Previews

#Preview("Study Finished") {
    ZStack {
        AmbientBackground(tint: KotoeTheme.accent)
        StudyFinishedView(
            total: 10,
            tint: KotoeTheme.accent,
            onStudyAgain: {},
            onShuffle: {}
        )
    }
}
