//
//  StudyStartScreen.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

/// The session start screen: pick guess or type mode, whether to shuffle, and
/// (in typing mode) whether to check capitalisation. Tapping Start begins the
/// session through `onStart`.
struct StudyStartScreen: View {

    @Binding var selectedMode: StudyMode
    @Binding var shufflesCards: Bool
    @Binding var checksCapitalization: Bool

    let tint: Color
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("studyView.start.title")
                    .font(.system(size: 30, weight: .bold, design: .rounded))

                Text("studyView.start.mode")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                modeOption(
                    .guess,
                    title: "studyView.start.guess",
                    symbol: "questionmark.bubble.fill"
                )

                modeOption(
                    .type,
                    title: "studyView.start.type",
                    symbol: "keyboard"
                )
            }

            HStack(spacing: 12) {
                Label("studyView.start.shuffle", systemImage: "shuffle")
                    .font(.headline)

                Spacer(minLength: 8)

                Toggle(isOn: $shufflesCards) {
                    Text("studyView.start.shuffle")
                }
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(tint)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                KotoeTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )

            if selectedMode == .type {
                HStack(spacing: 12) {
                    Label("studyView.type.capitalisation", systemImage: "textformat.abc")
                        .font(.headline)

                    Spacer(minLength: 8)

                    Toggle(isOn: $checksCapitalization) {
                        Text("studyView.type.capitalisation")
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(tint)
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    KotoeTheme.cardBackground,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }

            Button {
                onStart()
            } label: {
                Text("studyView.start.start")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modeOption(
        _ option: StudyMode,
        title: LocalizedStringKey,
        symbol: String
    ) -> some View {
        let isSelected = selectedMode == option

        return Button {
            selectedMode = option
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                    .frame(width: 40, height: 40)
                    .background(
                        isSelected ? tint : tint.opacity(0.12),
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(
                    isSelected ? tint : Color.secondary.opacity(0.35)
                )
            }
            .padding(14)
            .background(
                KotoeTheme.cardBackground,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(PressableCardStyle())
    }
}

// MARK: - Previews

#Preview("Study Start Screen") {
    StudyStartScreen(
        selectedMode: .constant(.guess),
        shufflesCards: .constant(false),
        checksCapitalization: .constant(false),
        tint: KotoeTheme.accent,
        onStart: {}
    )
}
