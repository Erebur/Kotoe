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
                FlashcardEditorView(card: card, tint: tint)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .confirmationAction) {
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

    #if os(macOS)
    /// The native macOS sheet action bar does not pick up the tinted
    /// background, so the sheet uses an in-content footer instead.
    private var sheetFooter: some View {
        HStack {
            Spacer()

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

            TextField(
                "setEditView.notes.placeholder",
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
                SectionHeader(
                    title: "shared.section.cards",
                    systemImage: "rectangle.stack"
                )

                Spacer()

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

    var body: some View {
        ZStack {
            AmbientBackground(tint: tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    #if os(macOS)
                    macBackButton
                    #endif

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
}

// MARK: - Side Editor

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
    @State private var showingPDFImporter = false
    @State private var showingPDFViewer = false

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

            Picker(
                "sideEditor.contentPicker.label",
                selection: $side.contentType
            ) {
                Text("shared.contentType.text")
                    .tag(FlashcardContentType.richText)
                Text("shared.contentType.image")
                    .tag(FlashcardContentType.image)
                Text("shared.contentType.drawing")
                    .tag(FlashcardContentType.drawing)
                Text("shared.contentType.pdf")
                    .tag(FlashcardContentType.pdf)
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
        .fileImporter(
            isPresented: $showingPDFImporter,
            allowedContentTypes: [.pdf]
        ) { result in
            importPDF(result)
        }
        .editorCover(isPresented: $showingPDFViewer) {
            if let fileName = side.mediaFileName {
                PDFDocumentView(fileName: fileName)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch side.contentType {
        case .richText:
            TextField(placeholder, text: textBinding, axis: .vertical)
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

        case .pdf:
            pdfControls
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

    private var photoActionTitle: LocalizedStringKey {
        side.hasImage
            ? "sideEditor.image.replace"
            : "sideEditor.image.choose"
    }

    @ViewBuilder
    private var imageControls: some View {
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
        }

        PhotosPicker(selection: $pickerItem, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(photoActionTitle)
            }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Color.primary.opacity(0.05),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .tint(accent)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    side.updateImage(data)
                }
                pickerItem = nil
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
            HStack(spacing: 8) {
                Image(systemName: "pencil.tip.crop.circle")
                Text(drawingActionTitle)
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
        .tint(accent)
        .editorCover(isPresented: $showingCanvas) {
            DrawingEditorView(initial: drawingDraft) { drawing in
                side.updateDrawing(drawing)
            }
        }
    }

    // MARK: PDF

    private var pdfActionTitle: LocalizedStringKey {
        side.hasPDF
            ? "sideEditor.pdf.replace"
            : "sideEditor.pdf.choose"
    }

    @ViewBuilder
    private var pdfControls: some View {
        if side.hasPDF {
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

            Button {
                showingPDFViewer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("sideEditor.pdf.view")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Color.primary.opacity(0.05),
                    in: RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .tint(accent)
        }

        Button {
            showingPDFImporter = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.badge.plus")
                Text(pdfActionTitle)
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
        .tint(accent)
    }

    private func importPDF(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            if case .failure(let error) = result {
                print("[Media] PDF import failed: \(error)")
            }
            return
        }

        Task { @MainActor in
            let data = await Task.detached(priority: .userInitiated) {
                () -> Data? in
                let isScoped = url.startAccessingSecurityScopedResource()
                defer {
                    if isScoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                return try? Data(contentsOf: url)
            }.value

            guard let data else {
                print("[Media] Could not read \(url.lastPathComponent)")
                return
            }

            side.updatePDF(data)
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
