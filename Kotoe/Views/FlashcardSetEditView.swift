//
//  FlashcardSetEditView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import PencilKit
import PhotosUI
import SwiftData
import SwiftUI

/// Opens when a set is edited. Edit the set's name and notes, and add,
/// reorder, delete and edit its cards.
struct FlashcardSetEditView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var flashcardSet: FlashcardSet

    @State private var path: [Flashcard] = []
    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var isEditingName: Bool

    private var cards: [Flashcard] {
        flashcardSet.sortedFlashcards
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        notesCard
                        cardsSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
            .clearInitialFocusOnMac()
            .navigationTitle("Edit Set")
            .inlineNavigationBarTitle()
            .navigationDestination(for: Flashcard.self) { card in
                FlashcardEditorView(card: card)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        finishRenaming()
                        try? modelContext.save()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .onChange(of: flashcardSet.name) {
                flashcardSet.modifiedAt = .now
            }
        }
        .editorSheetSize(width: 680, height: 740)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            IconTile(
                symbol: "rectangle.stack.fill",
                tint: KotoeTheme.accent,
                size: 60
            )

            VStack(alignment: .leading, spacing: 5) {
                if isRenaming {
                    HStack(spacing: 8) {
                        TextField("Set name", text: $draftName)
                            .textFieldStyle(.plain)
                            .font(
                                .system(
                                    size: 26,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .lineLimit(1...2)
                            .focused($isEditingName)
                            .onSubmit(finishRenaming)

                        Button {
                            finishRenaming()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(KotoeTheme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmedDraftName.isEmpty)
                        .help("Save name")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        KotoeTheme.fieldBackground,
                        in: RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 10,
                            style: .continuous
                        )
                        .strokeBorder(
                            KotoeTheme.accent.opacity(0.45),
                            lineWidth: 1
                        )
                    )
                } else {
                    HStack(spacing: 8) {
                        Text(flashcardSet.name)
                            .font(
                                .system(
                                    size: 26,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .lineLimit(1...2)
                            .onTapGesture(count: 2) {
                                beginRenaming()
                            }

                        Button {
                            beginRenaming()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Rename set")
                    }
                }

                HStack(spacing: 13) {
                    StatLabel(
                        text: pluralized(cards.count, "card"),
                        systemImage: "rectangle.on.rectangle.angled"
                    )

                    if let subject = flashcardSet.subject {
                        StatLabel(
                            text: subject.name,
                            systemImage: "books.vertical.fill"
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes", systemImage: "note.text")

            TextField(
                "Add notes about this set…",
                text: notesBinding,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(2...8)
        }
        .cardSurface(padding: 18)
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { flashcardSet.notes ?? "" },
            set: { newValue in
                flashcardSet.notes = newValue.isEmpty ? nil : newValue
                flashcardSet.modifiedAt = .now
            }
        )
    }

    // MARK: - Cards

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SectionHeader(title: "Cards", systemImage: "rectangle.stack")

                Spacer()

                Button {
                    addCard()
                } label: {
                    Label("Add Card", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(KotoeTheme.accent)
            }

            if cards.isEmpty {
                emptyCardsCard
            } else {
                ForEach(Array(cards.enumerated()), id: \.element.id) {
                    index,
                    card in
                    ReorderableCardRow(
                        card: card,
                        index: index,
                        onMoveUp: { move(card, by: -1) },
                        onMoveDown: { move(card, by: 1) },
                        onDelete: { delete(card) },
                        onDrop: { draggedID in
                            move(draggedID, before: card)
                        }
                    )
                    .transition(
                        .scale(scale: 0.97).combined(with: .opacity)
                    )
                }
            }
        }
        .animation(.snappy(duration: 0.35), value: cards.map(\.id))
    }

    private var emptyCardsCard: some View {
        Button {
            addCard()
        } label: {
            VStack(spacing: 9) {
                Image(systemName: "rectangle.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(KotoeTheme.accent)

                Text("Add Your First Card")
                    .font(.headline)

                Text(
                    "A card has a front — the prompt — and a back — the answer."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(KotoeTheme.cardBackground.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        KotoeTheme.accent.opacity(0.32),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginRenaming() {
        draftName = flashcardSet.name
        isRenaming = true

        DispatchQueue.main.async {
            isEditingName = true
        }
    }

    private func finishRenaming() {
        guard isRenaming else { return }

        if !trimmedDraftName.isEmpty {
            flashcardSet.name = trimmedDraftName
            flashcardSet.modifiedAt = .now
        }

        isEditingName = false
        isRenaming = false
    }

    private func addCard() {
        let card = Flashcard(position: cards.count)
        modelContext.insert(card)
        card.flashcardSet = flashcardSet

        let front = FlashcardSide(role: .front)
        let back = FlashcardSide(role: .back)
        modelContext.insert(front)
        modelContext.insert(back)

        card.setFront(front)
        card.setBack(back)

        flashcardSet.modifiedAt = .now

        // Jump straight into the editor for the new card.
        path.append(card)
    }

    private func delete(_ card: Flashcard) {
        let remaining = cards.filter { $0.id != card.id }

        withAnimation(.snappy(duration: 0.3)) {
            modelContext.delete(card)

            for (index, remainingCard) in remaining.enumerated() {
                remainingCard.position = index
            }

            flashcardSet.modifiedAt = .now
        }
    }

    private func move(_ card: Flashcard, by offset: Int) {
        var reordered = cards

        guard let index = reordered.firstIndex(where: { $0.id == card.id })
        else { return }

        let newIndex = index + offset
        guard reordered.indices.contains(newIndex) else { return }

        withAnimation(.snappy(duration: 0.3)) {
            reordered.swapAt(index, newIndex)
            applyPositions(reordered)
            flashcardSet.modifiedAt = .now
        }
    }

    private func move(_ draggedID: UUID, before target: Flashcard) {
        var reordered = cards

        guard
            let source = reordered.firstIndex(where: { $0.id == draggedID }),
            let targetIndex = reordered.firstIndex(where: { $0.id == target.id }),
            source != targetIndex
        else { return }

        withAnimation(.snappy(duration: 0.3)) {
            let draggedCard = reordered.remove(at: source)

            if let insertionIndex = reordered.firstIndex(
                where: { $0.id == target.id }
            ) {
                reordered.insert(draggedCard, at: insertionIndex)
            } else {
                reordered.append(draggedCard)
            }

            applyPositions(reordered)
            flashcardSet.modifiedAt = .now
        }
    }

    private func applyPositions(_ reordered: [Flashcard]) {
        for (index, card) in reordered.enumerated() {
            card.position = index
        }
    }

    private func pluralized(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}

// MARK: - Card Row

private struct ReorderableCardRow: View {

    let card: Flashcard
    let index: Int
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let onDrop: (UUID) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(value: card) {
                CardRow(card: card, index: index)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    isDropTargeted
                        ? KotoeTheme.accent
                        : Color.primary.opacity(0.3)
                )
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .draggable(card.id.uuidString) {
                    CardRow(card: card, index: index)
                        .cardSurface(padding: 10)
                        .frame(width: 300)
                }
                .help("Drag to reorder")
        }
        .cardSurface(padding: 12)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(KotoeTheme.accent, lineWidth: 2)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard
                let rawValue = items.first,
                let id = UUID(uuidString: rawValue)
            else { return false }

            onDrop(id)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .contextMenu {
            Button(action: onMoveUp) {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(index == 0)

            Button(action: onMoveDown) {
                Label("Move Down", systemImage: "arrow.down")
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("Delete Card", systemImage: "trash")
            }
        }
        .animation(.snappy(duration: 0.2), value: isDropTargeted)
    }
}

private struct CardRow: View {

    let card: Flashcard
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KotoeTheme.fieldBackground)
                    .frame(width: 28, height: 28)

                Text("\(index + 1)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(
                        systemName: card.front?.contentType.symbolName
                            ?? FlashcardContentType.richText.symbolName
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)

                    Text(card.front?.summary ?? "Empty")
                        .font(.headline)
                        .lineLimit(1)
                }

                Text(card.back?.summary ?? "Empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Card Editor

struct FlashcardEditorView: View {

    @Environment(\.modelContext) private var modelContext

    let card: Flashcard

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 18) {
                    if let front = card.front {
                        SideEditorSection(
                            title: "Front",
                            subtitle: "The prompt you see first",
                            systemImage: "questionmark.circle.fill",
                            tint: KotoeTheme.accent,
                            side: front
                        )
                    }

                    if let back = card.back {
                        SideEditorSection(
                            title: "Back",
                            subtitle: "The answer you reveal",
                            systemImage: "checkmark.circle.fill",
                            tint: KotoeTheme.success,
                            side: back
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .clearInitialFocusOnMac()
        .navigationTitle("Edit Card")
        .inlineNavigationBarTitle()
        .onAppear(perform: ensureSides)
    }

    /// Makes sure both sides exist, in case a card was created without them.
    private func ensureSides() {
        if card.front == nil {
            let side = FlashcardSide(role: .front)
            modelContext.insert(side)
            card.setFront(side)
        }

        if card.back == nil {
            let side = FlashcardSide(role: .back)
            modelContext.insert(side)
            card.setBack(side)
        }
    }
}

// MARK: - Side Editor

private struct SideEditorSection: View {

    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    @Bindable var side: FlashcardSide

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCanvas = false
    @State private var drawingDraft = PKDrawing()

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                IconTile(symbol: systemImage, tint: tint, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(side.contentType.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.10), in: Capsule())
            }

            Picker("Content", selection: $side.contentType) {
                Text("Text").tag(FlashcardContentType.richText)
                Text("Image").tag(FlashcardContentType.image)
                Text("Drawing").tag(FlashcardContentType.drawing)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .onChange(of: side.contentType) {
                side.modifiedAt = .now
                side.flashcard?.modifiedAt = .now
            }

            content
        }
        .cardSurface(padding: 18)
    }

    @ViewBuilder
    private var content: some View {
        switch side.contentType {
        case .richText:
            TextField("\(title) text", text: textBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...12)
                .padding(12)
                .background(
                    KotoeTheme.fieldBackground,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(KotoeTheme.hairline, lineWidth: 1)
                )

        case .image:
            imageControls

        case .drawing:
            drawingControls
        }
    }

    // MARK: Text

    private var textBinding: Binding<String> {
        Binding(
            get: { side.plainText },
            set: { side.setPlainText($0) }
        )
    }

    // MARK: Image

    @ViewBuilder
    private var imageControls: some View {
        if side.imageData != nil {
            ZStack(alignment: .topTrailing) {
                FlashcardSideContentView(side: side)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .padding(8)
                    .background(
                        Color.primary.opacity(0.025),
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                removeButton {
                    side.clearContent()
                }
                .padding(8)
            }
        }

        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(
                    side.imageData == nil ? "Choose Photo" : "Replace Photo"
                )
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .tint(KotoeTheme.accent)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    side.updateImage(
                        FlashcardSide.compressedImageData(from: data)
                    )
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Drawing

    @ViewBuilder
    private var drawingControls: some View {
        if side.drawingData != nil {
            ZStack(alignment: .topTrailing) {
                FlashcardSideContentView(side: side)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 220)
                    .padding(8)
                    .background(
                        Color.white,
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                removeButton {
                    side.clearContent()
                }
                .padding(8)
            }
        }

        Button {
            drawingDraft = side.pencilKitDrawing ?? PKDrawing()
            showingCanvas = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip.crop.circle")
                Text(
                    side.drawingData == nil ? "Draw" : "Edit Drawing"
                )
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .tint(KotoeTheme.accent)
        .editorCover(isPresented: $showingCanvas) {
            DrawingEditorView(initial: drawingDraft) { drawing in
                side.updateDrawing(drawing)
            }
        }
    }

    private func removeButton(action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help("Remove content")
    }
}
