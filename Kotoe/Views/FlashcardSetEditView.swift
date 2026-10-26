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
import UniformTypeIdentifiers

/// Opens when a set is edited. Edit the set's name and notes, and add,
/// reorder, delete and edit its cards.
struct FlashcardSetEditView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var flashcardSet: FlashcardSet

    @State private var path: [Flashcard] = []
    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var showingAppearance = false
    @State private var showingImport = false
    @State private var showingDeleteConfirmation = false
    @FocusState private var isEditingName: Bool

    private var cards: [Flashcard] {
        flashcardSet.sortedFlashcards
    }

    private var tint: Color {
        flashcardSet.style.tint
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AmbientBackground(tint: flashcardSet.style.tint)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        #if os(macOS)
                        Text("Edit Set")
                            .font(.headline)
                        #endif

                        header
                        notesCard
                        cardsSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                    .padding(.bottom, 34)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                #if os(macOS)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    sheetFooter
                }
                #endif
            }
            .clearInitialFocusOnMac()
            .navigationTitle("setEditView.navigation.title")
            .inlineNavigationBarTitle()
            #if os(macOS)
            // Hide the titlebar on macOS so the ambient gradient covers the
            // whole sheet. The in-content title keeps the screen labeled.
            .toolbarVisibility(.hidden, for: .windowToolbar)
            #endif
            .navigationDestination(for: Flashcard.self) { card in
                FlashcardEditorView(card: card, tint: tint) {
                    addAnotherCard()
                }
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
                    deleteButton
                    doneButton
                }
                #endif
            }
            .onChange(of: flashcardSet.name) {
                flashcardSet.modifiedAt = .now
            }
            .sheet(isPresented: $showingAppearance) {
                appearanceEditor
            }
            .sheet(isPresented: $showingImport) {
                CardImportView { imported in
                    importCards(imported)
                }
            }
            .confirmationDialog(
                "setEditView.deleteSetDialog.title",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    String(
                        localized: "setEditView.deleteSetDialog.delete",
                        defaultValue: "Delete \(flashcardSet.name)"
                    ),
                    role: .destructive
                ) {
                    deleteSet()
                }
                Button("shared.actions.cancel", role: .cancel) {
                    showingDeleteConfirmation = false
                }
            } message: {
                Text(
                    String(
                        localized: "setEditView.deleteSetDialog.message",
                        defaultValue:
                            "\(flashcardSet.sortedFlashcards.count) cards will be deleted. This can't be undone."
                    )
                )
            }
        }
        .tint(tint)
        .editorSheetSize(width: 680, height: 740)
    }

    private var doneButton: some View {
        Button("shared.actions.done") {
            finishRenaming()
            try? modelContext.save()
            dismiss()
        }
        .keyboardShortcut(.defaultAction)
    }

    /// Destructive button that confirms deletion in a confirmation dialog.
    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("setEditView.deleteSet.title", systemImage: "trash")
        }
        .help("setEditView.deleteSet.help")
    }

    #if os(macOS)
    /// The native macOS sheet action bar does not pick up the tinted
    /// background, so the sheet uses an in-content footer instead.
    private var sheetFooter: some View {
        HStack {
            Spacer()

            deleteButton

            doneButton
                .buttonStyle(.borderedProminent)
                .tint(tint)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
    #endif

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                showingAppearance = true
            } label: {
                IconTile(
                    symbol: flashcardSet.style.symbol,
                    tint: flashcardSet.style.tint,
                    size: 60
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(KotoeTheme.ink.opacity(0.7), in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    .white.opacity(0.45),
                                    lineWidth: 1
                                )
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(PressableCardStyle())
            .help("shared.actions.changeIconColorHelp")

            VStack(alignment: .leading, spacing: 5) {
                if isRenaming {
                    HStack(spacing: 8) {
                        TextField(
                            "setEditView.header.namePlaceholder",
                            text: $draftName
                        )
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
                                .foregroundStyle(tint)
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmedDraftName.isEmpty)
                        .help("shared.actions.saveNameHelp")
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
                            tint.opacity(0.45),
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
                        .help("setEditView.header.renameHelp")
                    }
                }

                HStack(spacing: 13) {
                    StatLabel(
                        text: LocalizedCounts.cards(cards.count),
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
            SectionHeader(
                title: "shared.section.notes",
                systemImage: "note.text"
            )

            RichTextField(
                placeholder: "setEditView.notes.placeholder",
                attributedText: notesBinding,
                tint: flashcardSet.style.tint,
                minHeight: 80,
                maxHeight: 260
            )
        }
        .cardSurface(padding: 18)
    }

    private var notesBinding: Binding<NSAttributedString> {
        Binding(
            get: { flashcardSet.attributedNotes },
            set: {
                flashcardSet.attributedNotes = $0
                flashcardSet.modifiedAt = .now
            }
        )
    }

    // MARK: - Cards

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SectionHeader(
                    title: "shared.section.cards",
                    systemImage: "rectangle.stack"
                )

                Spacer()

                Button {
                    showingImport = true
                } label: {
                    Label(
                        "setEditView.cards.importCards",
                        systemImage: "square.and.arrow.down"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(tint)
                .help("setEditView.cards.importHelp")

                Button {
                    addCard()
                } label: {
                    Label("setEditView.cards.addCard", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(tint)
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
                        tint: tint,
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
                    .foregroundStyle(tint)

                Text("setEditView.emptyState.title")
                    .font(.headline)

                Text(
                    "setEditView.emptyState.message"
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
                        tint.opacity(0.32),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Appearance

    private var appearanceEditor: some View {
        AppearanceEditor(
            title: "setEditView.appearanceEditor.title",
            subtitle: String(
                localized: "setEditView.appearanceEditor.subtitle",
                defaultValue:
                    "Choose the icon and color for \(flashcardSet.name)."
            ),
            symbols: KotoeTheme.setSymbols,
            defaultSymbol: "rectangle.stack.fill",
            defaultTintIndex: flashcardSet.effectiveTintIndex,
            iconName: Binding(
                get: { flashcardSet.iconName },
                set: { flashcardSet.iconName = $0 }
            ),
            tintIndex: Binding(
                get: { flashcardSet.tintIndex },
                set: { flashcardSet.tintIndex = $0 }
            )
        )
        .editorSheetSize(width: 460, height: 560)
        .onChange(of: flashcardSet.iconName) {
            saveAppearance()
        }
        .onChange(of: flashcardSet.tintIndex) {
            saveAppearance()
        }
    }

    private func saveAppearance() {
        flashcardSet.modifiedAt = .now
        flashcardSet.subject?.modifiedAt = .now

        do {
            try modelContext.save()
        } catch {
            print("Failed to save set appearance: \(error)")
        }
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

    /// Deletes the set and all of its cards, then dismisses the editor.
    private func deleteSet() {
        guard let subject = flashcardSet.subject else { return }

        flashcardSet.removeMediaFiles()
        modelContext.delete(flashcardSet)

        subject.modifiedAt = .now

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete flashcard set: \(error)")
        }

        dismiss()
    }

    private func addCard() {
        let card = makeCard(at: cards.count)

        flashcardSet.modifiedAt = .now

        // Jump straight into the editor for the new card.
        path.append(card)
    }

    /// Creates an empty card at the end of the set and opens it, so a run of
    /// cards can be typed without going back to the list every time.
    private func addAnotherCard() {
        let card = makeCard(at: cards.count)

        flashcardSet.modifiedAt = .now

        try? modelContext.save()

        // The open card editor is replaced instead of stacked, so the back
        // button returns to the set instead of walking through every card
        // that was added.
        if path.isEmpty {
            path.append(card)
        } else {
            path[path.count - 1] = card
        }
    }

    /// Creates a card with both sides and attaches it to the set.
    @discardableResult
    private func makeCard(at position: Int) -> Flashcard {
        let card = Flashcard(position: position)
        modelContext.insert(card)
        card.flashcardSet = flashcardSet

        let front = FlashcardSide(role: .front)
        let back = FlashcardSide(role: .back)
        modelContext.insert(front)
        modelContext.insert(back)

        card.setFront(front)
        card.setBack(back)

        return card
    }

    /// Adds parsed cards to the end of the set.
    private func importCards(_ imported: [TextCardImporter.Card]) {
        var position = cards.count

        for parsed in imported {
            let card = makeCard(at: position)
            position += 1

            card.front?.setPlainText(parsed.front)
            card.back?.setPlainText(parsed.back)
        }

        flashcardSet.modifiedAt = .now

        try? modelContext.save()
    }

    private func delete(_ card: Flashcard) {
        let remaining = cards.filter { $0.id != card.id }

        withAnimation(.snappy(duration: 0.3)) {
            card.removeMediaFiles()
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
}

// MARK: - Card Row

private struct ReorderableCardRow: View {

    let card: Flashcard
    let index: Int
    let tint: Color
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
                        ? tint
                        : Color.primary.opacity(0.3)
                )
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .draggable(card.id.uuidString) {
                    CardRow(card: card, index: index)
                        .cardSurface(padding: 10)
                        .frame(width: 300)
                }
                .help("setEditView.cardRow.dragHelp")
        }
        .cardSurface(padding: 12)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint, lineWidth: 2)
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
                Label("setEditView.cardRow.moveUp", systemImage: "arrow.up")
            }
            .disabled(index == 0)

            Button(action: onMoveDown) {
                Label(
                    "setEditView.cardRow.moveDown",
                    systemImage: "arrow.down"
                )
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("setEditView.cardRow.delete", systemImage: "trash")
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

                    Text(
                        card.front?.summary
                            ?? String(localized: "shared.content.empty")
                    )
                    .font(.headline)
                    .lineLimit(1)
                }

                Text(
                    card.back?.summary
                        ?? String(localized: "shared.content.empty")
                )
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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let card: Flashcard
    var tint: Color = KotoeTheme.accent

    /// Creates the next card of the set and opens it. `nil` when the editor
    /// is used without a set to add to.
    var onNextCard: (() -> Void)? = nil

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    #if os(macOS)
                    macBackButton
                    #endif

                    metaRow

                    if let front = card.front {
                        SideEditorSection(
                            title: "cardEditor.front.title",
                            subtitle: "cardEditor.front.subtitle",
                            placeholder: "cardEditor.front.textPlaceholder",
                            systemImage: "questionmark.circle.fill",
                            tint: tint,
                            accent: tint,
                            side: front
                        )
                    }

                    if let back = card.back {
                        SideEditorSection(
                            title: "cardEditor.back.title",
                            subtitle: "cardEditor.back.subtitle",
                            placeholder: "cardEditor.back.textPlaceholder",
                            systemImage: "checkmark.circle.fill",
                            tint: KotoeTheme.success,
                            accent: tint,
                            side: back
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 18)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
        }
        .clearInitialFocusOnMac()
        .tint(tint)
        .navigationTitle("cardEditor.navigation.title")
        .inlineNavigationBarTitle()
        #if os(macOS)
        // The window toolbar is hidden, so the back affordance lives in the
        // content and the ambient gradient can reach the sheet's top edge.
        .toolbarVisibility(.hidden, for: .windowToolbar)
        #endif
        .onAppear(perform: ensureSides)
        .onDisappear(perform: save)
    }

    // MARK: - Meta

    /// Shows where the card sits in its set.
    private var metaRow: some View {
        HStack(spacing: 8) {
            if let position = positionLabel {
                Label(position, systemImage: "rectangle.stack")
            }

            if let set = card.flashcardSet {
                Text(set.name)
                    .lineLimit(1)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var positionLabel: String? {
        guard
            let set = card.flashcardSet,
            let index = set.sortedFlashcards.firstIndex(
                where: { $0.id == card.id }
            )
        else { return nil }

        return String(
            localized: "cardEditor.position.label",
            defaultValue: "Card \(index + 1) of \(set.sortedFlashcards.count)"
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack() {
            Spacer()

            Button {
                nextCard()
            } label: {
                Label("cardEditor.actions.nextCard", systemImage: "arrow.right")
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .disabled(onNextCard == nil)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    #if os(macOS)
    private var macBackButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))

                Text("Edit Card")
                    .font(.headline)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .help("Back to set")
    }
    #endif

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

    // MARK: - Actions

    private func save() {
        try? modelContext.save()
    }

    /// Saves the card and moves on to a fresh one.
    private func nextCard() {
        save()

        onNextCard?()
    }
}

// MARK: - Side Editor

/// Editor for one side of a card.
///
/// Text, drawing and file share one screen. A file can be an image, a PDF or
/// a text file; the picker decides what it becomes. The gallery picker stays
/// available for photos.
private struct SideEditorSection: View {

    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let accent: Color

    @Bindable var side: FlashcardSide

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCanvas = false
    @State private var drawingDraft = PKDrawing()
    @State private var showingFileImporter = false
    @State private var showingPDFViewer = false
    @State private var importError: FileImportError?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            typePicker
            content
        }
        .cardSurface(padding: 18)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item]
        ) { result in
            importFile(result)
        }
        .editorCover(isPresented: $showingPDFViewer) {
            if let fileName = side.mediaFileName {
                PDFDocumentView(fileName: fileName)
            }
        }
        .alert(
            importError?.title ?? "sideEditor.file.unsupported.title",
            isPresented: Binding(
                get: { importError != nil },
                set: { isPresented in
                    if !isPresented { importError = nil }
                }
            ),
            presenting: importError
        ) { _ in
            Button("shared.actions.ok", role: .cancel) {}
        } message: { error in
            Text(verbatim: error.message)
        }
    }

    // MARK: - Header

    private var header: some View {
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

            Text(selectedChoice.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.10), in: Capsule())
        }
    }

    // MARK: - Type picker

    /// Picks what the side holds. Images and documents share the file entry,
    /// because the file itself decides which one it is.
    private var typePicker: some View {
        HStack(spacing: 4) {
            ForEach(SideContentChoice.allCases) { choice in
                Button {
                    select(choice)
                } label: {
                    Label {
                        Text(choice.label)
                    } icon: {
                        Image(systemName: choice.symbolName)
                    }
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                choice == selectedChoice
                                    ? KotoeTheme.cardBackground
                                    : Color.clear
                            )
                            .shadow(
                                color: .black.opacity(
                                    choice == selectedChoice ? 0.10 : 0
                                ),
                                radius: 3,
                                y: 1
                            )
                    )
                    .foregroundStyle(
                        choice == selectedChoice ? accent : Color.secondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            KotoeTheme.fieldBackground,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("sideEditor.contentPicker.label")
    }

    /// The entry that matches the content the side currently holds.
    private var selectedChoice: SideContentChoice {
        switch side.contentType {
        case .richText: return .text
        case .drawing: return .drawing
        case .image, .pdf: return .file
        }
    }

    private func select(_ choice: SideContentChoice) {
        switch choice {
        case .text:
            side.contentType = .richText
        case .drawing:
            side.contentType = .drawing
        case .file:
            // A PDF stays a PDF; anything else starts as an image.
            if side.contentType != .pdf {
                side.contentType = .image
            }
        }

        side.modifiedAt = .now
        side.flashcard?.modifiedAt = .now
    }

    @ViewBuilder
    private var content: some View {
        switch side.contentType {
        case .richText:
            textControls

        case .image, .pdf:
            fileControls

        case .drawing:
            drawingControls
        }
    }

    // MARK: Text

    private var textBinding: Binding<NSAttributedString> {
        Binding(
            get: { side.attributedText },
            set: { side.attributedText = $0 }
        )
    }

    private var textControls: some View {
        RichTextField(
            placeholder: placeholder,
            attributedText: textBinding,
            tint: tint,
            minHeight: 100,
            maxHeight: 400
        )
    }

    // MARK: File

    /// Preview of the file the side holds, if there is one.
    @ViewBuilder
    private var filePreview: some View {
        if side.hasImage {
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
        } else if side.hasPDF {
            ZStack(alignment: .topTrailing) {
                PDFSideView(fileName: side.mediaFileName)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 260)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
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
    }

    @ViewBuilder
    private var fileControls: some View {
        VStack(spacing: 10) {
            filePreview

            if side.hasPDF {
                Button {
                    showingPDFViewer = true
                } label: {
                    mediaButtonLabel(
                        title: "sideEditor.pdf.view",
                        systemImage: "arrow.up.left.and.arrow.down.right"
                    )
                }
                .buttonStyle(.plain)
                .tint(accent)
            }

            HStack(spacing: 10) {
                fileButton

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    mediaButtonLabel(
                        title: galleryActionTitle,
                        systemImage: "photo.on.rectangle.angled"
                    )
                }
                .tint(accent)
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }

                    Task {
                        if let data = try? await item.loadTransferable(
                            type: Data.self
                        ) {
                            side.updateImage(data)
                        }
                        pickerItem = nil
                    }
                }
            }

            fileHint
        }
    }

    private var fileActionTitle: LocalizedStringKey {
        side.mediaFileName == nil
            ? "sideEditor.file.choose"
            : "sideEditor.file.replace"
    }

    private var galleryActionTitle: LocalizedStringKey {
        side.hasImage
            ? "sideEditor.image.replace"
            : "sideEditor.image.choose"
    }

    /// One picker for images and documents. It accepts every file and lets
    /// the content decide which kind of side the file becomes.
    private var fileButton: some View {
        Button {
            showingFileImporter = true
        } label: {
            mediaButtonLabel(
                title: fileActionTitle,
                systemImage: "folder"
            )
        }
        .buttonStyle(.plain)
        .tint(accent)
    }

    private func mediaButtonLabel(
        title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }

    /// Reminds what the file picker accepts, since it takes every file.
    private var fileHint: some View {
        Text("sideEditor.file.hint")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func importFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result {
                print("[Media] File import failed: \(error)")
            }
            return
        }

        Task { @MainActor in
            let outcome = await Task.detached(priority: .userInitiated) {
                ImportedFile.read(url: url)
            }.value

            switch outcome {
            case .imported(.image(let data)):
                side.updateImage(data)

            case .imported(.pdf(let data)):
                side.updatePDF(data)

            case .imported(.text(let text)):
                side.setPlainText(text)

            case .unsupported(let fileName):
                importError = FileImportError(
                    fileName: fileName,
                    kind: .unsupported
                )

            case .failed(let fileName):
                importError = FileImportError(fileName: fileName, kind: .failed)
            }
        }
    }

    // MARK: Drawing

    private var drawingActionTitle: LocalizedStringKey {
        side.hasDrawing
            ? "sideEditor.drawing.edit"
            : "sideEditor.drawing.draw"
    }

    @ViewBuilder
    private var drawingControls: some View {
        if side.hasDrawing {
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
            // A drawing that only exists as an iCloud placeholder has to be
            // downloaded before the editor opens; otherwise saving a blank
            // canvas would replace it.
            Task { @MainActor in
                if side.hasDrawing {
                    guard
                        let data = await side.loadDrawingData(),
                        let drawing = try? PKDrawing(data: data)
                    else {
                        print("[Media] Drawing is not available yet.")
                        return
                    }

                    drawingDraft = drawing
                } else {
                    drawingDraft = PKDrawing()
                }

                showingCanvas = true
            }
        } label: {
            mediaButtonLabel(
                title: drawingActionTitle,
                systemImage: "pencil.tip.crop.circle"
            )
        }
        .buttonStyle(.plain)
        .tint(accent)
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
        .help("sideEditor.removeContent.help")
    }
}

// MARK: - Content choice

/// What a card side can hold, as offered by the side editor.
///
/// Images and documents share the file entry: the file itself decides which
/// one a side ends up with.
private enum SideContentChoice: String, CaseIterable, Identifiable {

    case text
    case drawing
    case file

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .drawing: return "pencil.tip"
        case .file: return "paperclip"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .text: return "shared.contentType.text"
        case .drawing: return "shared.contentType.drawing"
        case .file: return "shared.contentType.file"
        }
    }
}

// MARK: - File import error

/// A file that could not be added to a card.
private struct FileImportError: Identifiable {

    enum Kind {
        case unsupported
        case failed
    }

    let id = UUID()
    let fileName: String
    let kind: Kind

    var title: LocalizedStringKey {
        switch kind {
        case .unsupported:
            return "sideEditor.file.unsupported.title"
        case .failed:
            return "sideEditor.file.failed.title"
        }
    }

    var message: String {
        let name = fileName

        switch kind {
        case .unsupported:
            return String(
                localized: "sideEditor.file.unsupported.message",
                defaultValue:
                    "“\(name)” is not supported. Use an image, PDF, or text."
            )
        case .failed:
            return String(
                localized: "sideEditor.file.failed.message",
                defaultValue: "“\(name)” could not be read."
            )
        }
    }
}

// MARK: - Previews

#Preview("Set Editor") {
    let scene = PreviewData.scene()

    return FlashcardSetEditView(flashcardSet: scene.set)
        .modelContainer(scene.container)
}

#Preview("Card Rows") {
    let scene = PreviewData.scene()
    let tint = KotoeTheme.palette[2]

    return VStack(spacing: 20) {
        CardRow(card: scene.card, index: 1)
        
        ReorderableCardRow(
            card: scene.card,
            index: 2,
            tint: tint,
            onMoveUp: {},
            onMoveDown: {},
            onDelete: {},
            onDrop: { _ in }
        )
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(KotoeTheme.windowBackground)
    .modelContainer(scene.container)
}

#Preview("Card Editor") {
    let scene = PreviewData.scene()

    return NavigationStack {
        FlashcardEditorView(card: scene.card)
    }
    .modelContainer(scene.container)
}

#Preview("Side Editor") {
    let scene = PreviewData.scene()
    let tint = KotoeTheme.palette[2]

    return ScrollView {
        SideEditorSection(
            title: "cardEditor.front.title",
            subtitle: "cardEditor.front.subtitle",
            placeholder: "cardEditor.front.textPlaceholder",
            systemImage: "questionmark.circle.fill",
            tint: tint,
            accent: tint,
            side: scene.frontSide
        )
        .padding(22)
    }
    .modelContainer(scene.container)
}
