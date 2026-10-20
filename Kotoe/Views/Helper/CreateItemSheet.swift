//
//  CreateItemSheet.swift
//  Kōtoe
//
//  A small, consistent prompt used for creating subjects and sets.
//

import SwiftUI

struct CreateItemSheet: View {

    let title: String
    let prompt: String
    let systemImage: String
    let placeholder: String
    let actionTitle: String

    @Binding var name: String

    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 14) {
                IconTile(
                    symbol: systemImage,
                    tint: KotoeTheme.accent,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text(prompt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            TextField(placeholder, text: $name)
                .textFieldStyle(.plain)
                .font(.title3)
                .submitLabel(.done)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(
                    KotoeTheme.fieldBackground,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            isFocused
                                ? KotoeTheme.accent.opacity(0.55)
                                : KotoeTheme.hairline,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .focused($isFocused)
                .onSubmit(create)
                .animation(.easeOut(duration: 0.15), value: isFocused)

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(actionTitle) {
                    create()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
            .controlSize(.large)
            .tint(KotoeTheme.accent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            // Give the sheet a moment to finish presenting before taking focus.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFocused = true
            }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        onCreate()
    }
}
