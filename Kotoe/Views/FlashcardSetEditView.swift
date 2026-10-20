//
//  FlashcardSetEditView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//


import PencilKit
import PhotosUI
import SwiftData
import SwiftUI

/// Opens on swipe left / long press of a set. Edit the set's name and
/// notes, and add, reorder, delete and edit its cards.
struct FlashcardSetEditView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var flashcardSet: FlashcardSet

    @State private var path: [Flashcard] = []

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                detailsSection
                cardsSection
            }
            .navigationTitle("Edit Set")
            .inlineNavigationBarTitle()
            .navigationDestination(for: Flashcard.self) { card in
                FlashcardEditorView(card: card)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    EditButton()
                }
                #endif

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .onChange(of: flashcardSet.name) {
                flashcardSet.modifiedAt = .now
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section("Details") {
            TextField("Set name", text: $flashcardSet.name)

            TextField("Notes", text: notesBinding, axis: .vertical)
                .lineLimit(1...6)
        }
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

    private var cardsSection: some View {
        Section {
            let cards = flashcardSet.sortedFlashcards

            if cards.isEmpty {
                Text("No cards yet.")
                    .foregroundStyle(.secondary)
            }

            ForEach(cards) { card in
                NavigationLink(value: card) {
                    CardRow(card: card)
                }
                .contextMenu {
                    Button(role: .destructive) {
                        delete(card)
                    } label: {
                        Label("Delete Card", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                delete(cards, at: offsets)
            }
            .onMove { source, destination in
                move(cards, from: source, to: destination)
            }

            Button {
                addCard()
            } label: {
                Label("Add Card", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Cards")
        }
    }

    // MARK: - Actions

    private func addCard() {
        let card = Flashcard(position: flashcardSet.sortedFlashcards.count)
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

    private func delete(_ cards: [Flashcard], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }

        let remaining = cards.enumerated()
            .filter { !offsets.contains($0.offset) }
            .map(\.element)

        for (index, card) in remaining.enumerated() {
            card.position = index
        }

        flashcardSet.modifiedAt = .now
    }

    /// Deletes a single card. Used by the context menu, since macOS has no
    /// `EditButton` and therefore no swipe-to-delete affordance.
    private func delete(_ card: Flashcard) {
        let remaining = flashcardSet.sortedFlashcards.filter { $0.id != card.id }

        modelContext.delete(card)

        for (index, remainingCard) in remaining.enumerated() {
            remainingCard.position = index
        }

        flashcardSet.modifiedAt = .now
    }

    private func move(_ cards: [Flashcard], from source: IndexSet, to destination: Int) {
        var reordered = cards
        reordered.move(fromOffsets: source, toOffset: destination)

        for (index, card) in reordered.enumerated() {
            card.position = index
        }

        flashcardSet.modifiedAt = .now
    }
}

// MARK: - Card Row

private struct CardRow: View {
    let card: Flashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.front?.summary ?? "Empty")
                .font(.headline)
                .lineLimit(1)

            Text(card.back?.summary ?? "Empty")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Card Editor

struct FlashcardEditorView: View {

    @Environment(\.modelContext) private var modelContext

    let card: Flashcard

    var body: some View {
        Form {
            if let front = card.front {
                SideEditorSection(title: "Front", side: front)
            }

            if let back = card.back {
                SideEditorSection(title: "Back", side: back)
            }
        }
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
    @Bindable var side: FlashcardSide

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCanvas = false
    @State private var drawingDraft = PKDrawing()

    var body: some View {
        Section(title) {
            Picker("Content", selection: $side.contentType) {
                Text("Text").tag(FlashcardContentType.richText)
                Text("Image").tag(FlashcardContentType.image)
                Text("Drawing").tag(FlashcardContentType.drawing)
            }
            .pickerStyle(.segmented)
            .onChange(of: side.contentType) {
                side.modifiedAt = .now
                side.flashcard?.modifiedAt = .now
            }

            switch side.contentType {
            case .richText:
                TextField("\(title) text", text: textBinding, axis: .vertical)
                    .lineLimit(2...10)

            case .image:
                imageControls

            case .drawing:
                drawingControls
            }
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
            FlashcardSideContentView(side: side)
                .frame(maxWidth: .infinity, maxHeight: 200)
        }

        PhotosPicker(selection: $pickerItem, matching: .images) {
            Label(
                side.imageData == nil ? "Choose Photo" : "Replace Photo",
                systemImage: "photo"
            )
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    side.updateImage(FlashcardSide.compressedImageData(from: data))
                }
                pickerItem = nil
            }
        }

        if side.imageData != nil {
            Button("Remove Image", role: .destructive) {
                side.clearContent()
            }
        }
    }

    // MARK: Drawing

    @ViewBuilder
    private var drawingControls: some View {
        if side.drawingData != nil {
            FlashcardSideContentView(side: side)
                .frame(maxWidth: .infinity, maxHeight: 200)
        }

        Button {
            drawingDraft = side.pencilKitDrawing ?? PKDrawing()
            showingCanvas = true
        } label: {
            Label(
                side.drawingData == nil ? "Draw" : "Edit Drawing",
                systemImage: "pencil.tip.crop.circle"
            )
        }
        .editorCover(isPresented: $showingCanvas) {
            DrawingEditorView(initial: drawingDraft) { drawing in
                side.updateDrawing(drawing)
            }
        }

        if side.drawingData != nil {
            Button("Remove Drawing", role: .destructive) {
                side.clearContent()
            }
        }
    }
}