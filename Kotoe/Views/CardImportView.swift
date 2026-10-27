//
//  CardImportView.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import SwiftUI
import UniformTypeIdentifiers

/// Imports many cards at once from pasted text.
///
/// Quizlet exports a set as tab separated lines, so the pasted text is split
/// into a term and an answer per line. The preview shows exactly what will be
/// created before the cards are added to the set.
struct CardImportView: View {

    @Environment(\.dismiss) private var dismiss

    let onImport: ([TextCardImporter.Card]) -> Void

    @State private var text = ""
    @State private var showingFileImporter = false
    @FocusState private var isEditorFocused: Bool

    /// Parsed once per text change instead of on every access, so a large
    /// paste does not slow down each render.
    @State private var parsed = TextCardImporter.ParsedCards(
        cards: [],
        separator: .none
    )

    private var cards: [TextCardImporter.Card] {
        parsed.cards
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            editor
            preview
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: text) {
            parsed = TextCardImporter.parse(text)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [
                .plainText,
                .tabSeparatedText,
                .commaSeparatedText,
                .rtf,
                .text,
            ]
        ) { result in
            importFile(result)
        }
        .editorSheetSize(width: 620, height: 640)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                "cardImport.navigation.title",
                systemImage: "square.and.arrow.down.on.square"
            )
            .font(.headline)

            Text("cardImport.header.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($isEditorFocused)
                    .padding(9)
                    .frame(minHeight: 130, maxHeight: 240)

                if text.isEmpty {
                    Text("cardImport.editor.placeholder")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }
            .background(
                KotoeTheme.fieldBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(KotoeTheme.hairline, lineWidth: 1)
            )

            HStack(spacing: 8) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label(
                        "cardImport.actions.paste",
                        systemImage: "doc.on.clipboard"
                    )
                }
                .disabled(!Clipboard.hasText)

                Button {
                    showingFileImporter = true
                } label: {
                    Label(
                        "cardImport.actions.chooseFile",
                        systemImage: "folder"
                    )
                }

                Spacer()

                Button {
                    text = ""
                } label: {
                    Label(
                        "cardImport.actions.clear",
                        systemImage: "xmark.circle"
                    )
                }
                .disabled(text.isEmpty)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SectionHeader(
                    title: "cardImport.preview.title",
                    systemImage: "list.bullet.rectangle"
                )

                Spacer()

                if !cards.isEmpty {
                    Text(verbatim: separatorLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if cards.isEmpty {
                Text("cardImport.preview.empty")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(KotoeTheme.fieldBackground)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(
                        Array(cards.prefix(5).enumerated()),
                        id: \.element.id
                    ) {
                        index,
                        card in
                        previewRow(card, index: index)

                        if index < min(cards.count, 5) - 1 {
                            Divider()
                                .opacity(0.4)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KotoeTheme.fieldBackground)
                )

                if cards.count > 5 {
                    Text(verbatim: moreLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private func previewRow(
        _ card: TextCardImporter.Card,
        index: Int
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.front)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if card.back.isEmpty {
                    Text("cardImport.preview.noAnswer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(card.back)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Button("shared.actions.cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if !cards.isEmpty {
                Text(verbatim: countLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                importCards()
            } label: {
                Label(
                    "cardImport.actions.import",
                    systemImage: "square.and.arrow.down"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(KotoeTheme.accent)
            .keyboardShortcut(.defaultAction)
            .disabled(cards.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Labels

    private var countLabel: String {
        String(
            localized: "cardImport.preview.count",
            defaultValue: "\(cards.count) cards ready"
        )
    }

    private var moreLabel: String {
        String(
            localized: "cardImport.preview.more",
            defaultValue: "and \(cards.count - 5) more"
        )
    }

    private var separatorLabel: String {
        String(
            localized: "cardImport.preview.separator",
            defaultValue: "Separated by \(parsed.separator.localizedName)"
        )
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let clipboard = Clipboard.text, !clipboard.isEmpty else { return }

        text = clipboard

        DispatchQueue.main.async {
            isEditorFocused = true
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result {
                print("[Import] Could not open the file: \(error)")
            }
            return
        }

        Task { @MainActor in
            let contents = await Task.detached(priority: .userInitiated) {
                ImportedFile.readText(url: url)
            }.value

            guard let contents else {
                print("[Import] Could not read \(url.lastPathComponent)")
                return
            }

            text = contents

            DispatchQueue.main.async {
                isEditorFocused = true
            }
        }
    }

    private func importCards() {
        guard !cards.isEmpty else { return }

        onImport(cards)
        dismiss()
    }
}

#Preview {
    CardImportView { _ in }
        .frame(width: 620, height: 640)
}
