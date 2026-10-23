//
//  StudyControls.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

/// The controls shown below the card. In guessing mode before the flip these
/// are hints ("tap to reveal", "swipe to mark"). After the flip they are the
/// Again / Got It buttons. In typing mode they are the answer field before
/// the flip and the automatic verdict after.
struct StudyControls: View {

    let isFlipped: Bool
    let sessionMode: StudyMode
    let checksCapitalization: Bool
    let typedAnswer: Binding<String>
    let lastTypedCorrect: Bool
    let tint: Color

    let onNext: () -> Void
    let onSubmit: () -> Void

    var tapIndicators: some View {
        // Guessing mode: no "Reveal answer" button. Hints guide the user
        // to tap to flip and swipe to mark the card correct or incorrect.
        HStack(spacing: 10) {
            Image(systemName: "arrow.left")
                .font(.caption2.weight(.semibold))
            Text("studyView.card.swipeIncorrect")
                .font(.caption2.weight(.semibold))
            Spacer()
            Image(systemName: "hand.tap")
                .font(.caption2.weight(.semibold))
            Text("studyView.card.tapToReveal")
                .font(.caption2.weight(.semibold))
            Spacer()
            Text("studyView.card.swipeCorrect")
                .font(.caption2.weight(.semibold))
            Image(systemName: "arrow.right")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .transition(.move(edge: .bottom).combined(with: .opacity))

    }

    var textField: some View {
        HStack(spacing: 10) {
            TextField(
                "studyView.start.placeholder",
                text: typedAnswer
            )
            .textFieldStyle(.plain)
            .font(.body)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                KotoeTheme.fieldBackground,
                in: RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
            .onSubmit(onSubmit)
            .submitLabel(.done)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    var body: some View {
        if isFlipped {
            HStack(spacing: 12) {
                Button {
                    onNext()
                } label: {
                    Label("studyView.controls.next", systemImage: "arrowshape.forward.fill")
                        .labelStyle(CenteredLabelStyle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(StudyActionButtonStyle(tint: tint))
                .keyboardShortcut(.escape)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if sessionMode == .type {
            textField
        } else {
            tapIndicators
        }
    }
}

// MARK: - Previews

#Preview("Study Controls") {
    VStack(spacing: 20) {
        StudyControls(
            isFlipped: true,
            sessionMode: .guess,
            checksCapitalization: false,
            typedAnswer: .constant(""),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onSubmit: {}
        )
        Divider()
        StudyControls(
            isFlipped: false,
            sessionMode: .guess,
            checksCapitalization: false,
            typedAnswer: .constant(""),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onSubmit: {}
        )
        Divider()
        StudyControls(
            isFlipped: false,
            sessionMode: .type,
            checksCapitalization: true,
            typedAnswer: .constant(""),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onSubmit: {}
        )
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KotoeTheme.windowBackground)
}


struct CenteredLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .center, spacing: 8) {
            configuration.icon
            configuration.title
        }
    }
}
