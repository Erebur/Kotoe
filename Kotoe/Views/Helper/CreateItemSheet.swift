//
//  CreateItemSheet.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//
//  A small, consistent prompt used for creating subjects and sets.

import SwiftUI

struct CreateItemSheet: View {

    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    let systemImage: String
    let placeholder: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    var tint: Color = KotoeTheme.accent

    @Binding var name: String

    let onCreate: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        PopupView(
            title: title,
            subtitle: prompt,
            systemImage: systemImage,
            tint: tint,
            primaryTitle: actionTitle,
            primaryAction: create,
            primaryDisabled: trimmedName.isEmpty,
            cancelAction: onCancel,
            // The whole point of this sheet is to type a name, so keep the
            // field focused instead of clearing the initial responder.
            clearsInitialFocusOnMac: false
        ) {
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
                                ? tint.opacity(0.55)
                                : KotoeTheme.hairline,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .focused($isFocused)
                .onSubmit(create)
                .animation(.easeOut(duration: 0.15), value: isFocused)
                // Give the sheet a moment to finish presenting before taking
                // focus. On macOS PopupView clears the initial responder, so
                // this deliberately re-focuses the field after that.
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isFocused = true
                    }
                }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        onCreate()
    }
}

#Preview {
    CreateItemSheet(
        title: "contentView.newSubjectSheet.title",
        prompt: "contentView.newSubjectSheet.prompt",
        systemImage: "books.vertical.fill",
        placeholder: "contentView.newSubjectSheet.namePlaceholder",
        actionTitle: "contentView.newSubjectSheet.create",
        name: .constant("Biology"),
        onCreate: {},
        onCancel: {}
    )
    .frame(width: 440)
}
