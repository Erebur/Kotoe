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
    let typedAnswer: Binding<NSAttributedString>
    let lastTypedCorrect: Bool
    let tint: Color

    let onNext: () -> Void
    let onIncorrect: () -> Void
    let onSubmit: () -> Void

    var tapIndicators: some View {
        // Guessing mode: the swipe hints double as buttons for pointer users.
        // They stay deliberately plain so they read as hints, not controls.
        // Tapping the card to flip is hinted at on the card itself.
        HStack(spacing: 12) {
            markButton(
                title: "studyView.card.swipeIncorrect",
                symbol: "arrow.left",
                symbolFirst: true,
                alignment: .leading,
                action: onIncorrect
            )

            markButton(
                title: "studyView.card.swipeCorrect",
                symbol: "arrow.right",
                symbolFirst: false,
                alignment: .trailing,
                action: onNext
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func markButton(
        title: LocalizedStringKey,
        symbol: String,
        symbolFirst: Bool,
        alignment: Alignment,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if symbolFirst {
                    Image(systemName: symbol)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !symbolFirst {
                    Image(systemName: symbol)
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: alignment)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    var textField: some View {
        RichTextField(
            placeholder: "studyView.start.placeholder",
            attributedText: typedAnswer,
            tint: tint,
            minHeight: 34,
            maxHeight: 72,
            submitsOnReturn: true,
            onSubmit: onSubmit,
            showsStyleControls: false
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    var body: some View {
        if sessionMode == .type {
            if isFlipped {
                nextButton
            } else {
                textField
            }
        } else {
            // The marking buttons stay in place before and after the reveal.
            tapIndicators
        }
    }

    private var nextButton: some View {
        HStack(spacing: 12) {
            verdictBadge

            Button {
                onNext()
            } label: {
                Label(
                    "studyView.controls.next",
                    systemImage: "arrowshape.forward.fill"
                )
                .labelStyle(CenteredLabelStyle())
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyActionButtonStyle(tint: tint))
            .keyboardShortcut(.escape)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Shown beside Next while a typed answer's verdict is revealed, so the
    /// outcome is visible and not only implied by the revealed back.
    private var verdictBadge: some View {
        let color = lastTypedCorrect ? KotoeTheme.success : KotoeTheme.failure
        let title: LocalizedStringKey = lastTypedCorrect
            ? "studyView.verdict.correct"
            : "studyView.verdict.incorrect"
        let symbol = lastTypedCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"

        return Label(title, systemImage: symbol)
            .labelStyle(CenteredLabelStyle())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.16))
            )
            .accessibilityLabel(title)
            .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Previews

#Preview("Study Controls") {
    VStack(spacing: 20) {
        StudyControls(
            isFlipped: true,
            sessionMode: .guess,
            checksCapitalization: false,
            typedAnswer: .constant(NSAttributedString()),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onIncorrect: { },
            onSubmit: {}
        )
        Divider()
        StudyControls(
            isFlipped: false,
            sessionMode: .guess,
            checksCapitalization: false,
            typedAnswer: .constant(NSAttributedString()),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onIncorrect: { },
            onSubmit: {}
        )
        Divider()
        StudyControls(
            isFlipped: false,
            sessionMode: .type,
            checksCapitalization: true,
            typedAnswer: .constant(NSAttributedString()),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onIncorrect: { },
            onSubmit: {}
        )
        Divider()
        StudyControls(
            isFlipped: true,
            sessionMode: .type,
            checksCapitalization: true,
            typedAnswer: .constant(NSAttributedString()),
            lastTypedCorrect: true,
            tint: KotoeTheme.accent,
            onNext: { },
            onIncorrect: { },
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
