//
//  SubjectView.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import SwiftData
import SwiftUI

struct SubjectView: View {

    @Environment(\.modelContext) private var modelContext

    @Bindable var subject: Subject

    @State private var showingNewSet = false
    @State private var newSetName = ""
    @State private var editingSet: FlashcardSet?
    @State private var setPendingDeletion: FlashcardSet?
    @State private var customizingSet: FlashcardSet?
    @State private var showingAppearance = false
    @State private var isRenaming = false
    @State private var draftName = ""
    @FocusState private var isEditingName: Bool

    private var sets: [FlashcardSet] {
        subject.sortedFlashcardSets
    }

    private var allCards: [Flashcard] {
        subject.allCards
    }

    var body: some View {
        ZStack {
            AmbientBackground(tint: subject.style.tint)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    studyAllCard
                    notesCard
                    setsSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 34)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(subject.style.tint)
        .clearInitialFocusOnMac()
        .macNavigationTitle(subject.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSet = true
                } label: {
                    Label("subjectView.toolbar.addSet", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("subjectView.toolbar.createSetHelp")
            }
        }
        .sheet(isPresented: $showingNewSet) {
            CreateItemSheet(
                title: "subjectView.newSetSheet.title",
                prompt: "subjectView.newSetSheet.prompt",
                systemImage: "rectangle.stack.fill",
                placeholder: "subjectView.newSetSheet.namePlaceholder",
                actionTitle: "subjectView.newSetSheet.create",
                tint: subject.style.tint,
                name: $newSetName,
                onCreate: createSet,
                onCancel: closeSheet
            )
            .dialogSheet()
        }
        .sheet(item: $editingSet) { set in
            FlashcardSetEditView(flashcardSet: set)
                .editorSheetSize()
        }
        .sheet(isPresented: $showingAppearance) {
            subjectAppearanceEditor
        }
        .sheet(item: $customizingSet) { set in
            setAppearanceEditor(for: set)
        }
        .confirmationDialog(
            "subjectView.deleteSetDialog.title",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: setPendingDeletion
        ) { set in
            Button(
                String(
                    localized: "subjectView.deleteSetDialog.delete",
                    defaultValue: "Delete \(set.name)"
                ),
                role: .destructive
            ) {
                delete(set)
            }
            Button("shared.actions.cancel", role: .cancel) {
                setPendingDeletion = nil
            }
        } message: { set in
            Text(
                String(
                    localized: "subjectView.deleteSetDialog.message",
                    defaultValue:
                        "\(set.sortedFlashcards.count) cards will be deleted. This can't be undone."
                )
            )
        }
        .onChange(of: subject.name) {
            subject.modifiedAt = .now
        }
        .onAppear {
            subject.lastAccessedAt = .now
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                showingAppearance = true
            } label: {
                IconTile(
                    symbol: subject.style.symbol,
                    tint: subject.style.tint,
                    size: 68
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 21, height: 21)
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

            VStack(alignment: .leading, spacing: 6) {
                if isRenaming {
                    HStack(spacing: 8) {
                        TextField(
                            "subjectView.header.renamePlaceholder",
                            text: $draftName
                        )
                            .textFieldStyle(.plain)
                            .font(
                                .system(
                                    size: 30,
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
                                .font(.system(size: 18))
                                .foregroundStyle(subject.style.tint)
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
                            subject.style.tint.opacity(0.45),
                            lineWidth: 1
                        )
                    )
                } else {
                    HStack(spacing: 9) {
                        Text(subject.name)
                            .font(
                                .system(
                                    size: 30,
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
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("subjectView.header.renameHelp")
                    }
                }

                HStack(spacing: 13) {
                    StatLabel(
                        text: LocalizedCounts.sets(sets.count),
                        systemImage: "square.stack.3d.up.fill"
                    )

                    StatLabel(
                        text: LocalizedCounts.cards(allCards.count),
                        systemImage: "rectangle.on.rectangle.angled"
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Study All

    private var studyAllSubtitle: String {
        guard !allCards.isEmpty else {
            return String(localized: "subjectView.studyAll.emptySubtitle")
        }

        let cardCount = LocalizedCounts.cards(allCards.count)
        let setCount = LocalizedCounts.sets(sets.count)

        return String(
            localized: "subjectView.studyAll.subtitle",
            defaultValue: "\(cardCount) across \(setCount)"
        )
    }

    private var studyAllCard: some View {
        NavigationLink {
            StudyView(
                title: subject.name,
                cards: allCards,
                tint: subject.style.tint
            )
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.19))
                        .frame(width: 46, height: 46)

                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("subjectView.studyAll.title")
                        .font(.headline)

                    Text(verbatim: studyAllSubtitle)
                        .font(.subheadline)
                        .opacity(0.85)
                }

                Spacer(minLength: 8)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.75)
            }
            .foregroundStyle(.white)
            .padding(18)
            .background(
                subject.style.gradient,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(
                color: subject.style.tint.opacity(0.28),
                radius: 16,
                y: 8
            )
        }
        .buttonStyle(PressableCardStyle())
        .hoverLift()
        .disabled(allCards.isEmpty)
        .opacity(allCards.isEmpty ? 0.52 : 1)
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "shared.section.notes",
                systemImage: "note.text"
            )

            TextField(
                "subjectView.notes.placeholder",
                text: notesBinding,
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .lineLimit(3...12)
        }
        .cardSurface(padding: 18)
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { subject.notes ?? "" },
            set: { newValue in
                subject.notes = newValue.isEmpty ? nil : newValue
                subject.modifiedAt = .now
            }
        )
    }

    // MARK: - Flashcard Sets

    private var setsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SectionHeader(
                    title: "subjectView.sets.sectionTitle",
                    systemImage: "square.stack.3d.up.fill"
                )

                Spacer()

                Button {
                    showingNewSet = true
                } label: {
                    Label("subjectView.sets.newSet", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(subject.style.tint)
            }

            if sets.isEmpty {
                emptySetsCard
            } else {
                ForEach(sets) { set in
                    setRow(set)
                }
            }
        }
        .animation(.snappy(duration: 0.35), value: sets.map(\.id))
    }

    private func setRow(_ set: FlashcardSet) -> some View {
        let style = set.style

        return HStack(spacing: 10) {
            NavigationLink {
                StudyView(flashcardSet: set)
            } label: {
                HStack(spacing: 14) {
                    IconTile(
                        symbol: style.symbol,
                        tint: style.tint,
                        size: 42
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(set.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(
                            LocalizedCounts.cards(
                                set.sortedFlashcards.count
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    customizingSet = set
                } label: {
                    Label(
                        "shared.actions.changeIcon",
                        systemImage: "paintpalette"
                    )
                }

                Button {
                    editingSet = set
                } label: {
                    Label("subjectView.setRow.editCards", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    setPendingDeletion = set
                } label: {
                    Label("subjectView.setRow.deleteSet", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Color.primary.opacity(0.05),
                        in: Circle()
                    )
                    .contentShape(Circle())
            }
            .compactMenuStyle()
            .fixedSize()
            .help("subjectView.setRow.actionsHelp")
        }
        .cardSurface(padding: 12, tint: style.tint)
        .hoverLift()
        .contextMenu {
            Button {
                customizingSet = set
            } label: {
                Label(
                    "shared.actions.changeIcon",
                    systemImage: "paintpalette"
                )
            }

            Button {
                editingSet = set
            } label: {
                Label("subjectView.setRow.editCards", systemImage: "pencil")
            }

            Button(role: .destructive) {
                setPendingDeletion = set
            } label: {
                Label("subjectView.setRow.deleteSet", systemImage: "trash")
            }
        }
        .transition(.scale(scale: 0.97).combined(with: .opacity))
    }

    private var emptySetsCard: some View {
        Button {
            showingNewSet = true
        } label: {
            VStack(spacing: 9) {
                Image(systemName: "plus.rectangle.on.folder.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(subject.style.tint)

                Text("subjectView.emptyState.title")
                    .font(.headline)

                Text(
                    "subjectView.emptyState.message"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
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
                        subject.style.tint.opacity(0.32),
                        style: StrokeStyle(
                            lineWidth: 1.5,
                            dash: [6, 4]
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var subjectAppearanceEditor: some View {
        AppearanceEditor(
            title: "subjectView.subjectAppearanceEditor.title",
            subtitle: String(
                localized: "subjectView.subjectAppearanceEditor.subtitle",
                defaultValue:
                    "Choose the icon and color for \(subject.name)."
            ),
            symbols: KotoeTheme.subjectSymbols,
            defaultSymbol: KotoeTheme.style(for: subject.name).symbol,
            defaultTintIndex: subject.effectiveTintIndex,
            iconName: Binding(
                get: { subject.iconName },
                set: { subject.iconName = $0 }
            ),
            tintIndex: Binding(
                get: { subject.tintIndex },
                set: { subject.tintIndex = $0 }
            )
        )
        .editorSheetSize(width: 460, height: 560)
        .onChange(of: subject.iconName) {
            subject.modifiedAt = .now
            saveAppearance()
        }
        .onChange(of: subject.tintIndex) {
            subject.modifiedAt = .now
            saveAppearance()
        }
    }

    private func setAppearanceEditor(for set: FlashcardSet) -> some View {
        AppearanceEditor(
            title: "subjectView.appearanceEditor.title",
            subtitle: String(
                localized: "subjectView.appearanceEditor.subtitle",
                defaultValue: "Choose the icon and color for \(set.name)."
            ),
            symbols: KotoeTheme.setSymbols,
            defaultSymbol: "rectangle.stack.fill",
            defaultTintIndex: set.effectiveTintIndex,
            iconName: Binding(
                get: { set.iconName },
                set: { set.iconName = $0 }
            ),
            tintIndex: Binding(
                get: { set.tintIndex },
                set: { set.tintIndex = $0 }
            )
        )
        .editorSheetSize(width: 460, height: 560)
        .onChange(of: set.iconName) {
            set.modifiedAt = .now
            subject.modifiedAt = .now
            saveAppearance()
        }
        .onChange(of: set.tintIndex) {
            set.modifiedAt = .now
            subject.modifiedAt = .now
            saveAppearance()
        }
    }

    private func saveAppearance() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save appearance: \(error)")
        }
    }

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginRenaming() {
        draftName = subject.name
        isRenaming = true

        DispatchQueue.main.async {
            isEditingName = true
        }
    }

    private func finishRenaming() {
        guard isRenaming else { return }

        if !trimmedDraftName.isEmpty {
            subject.name = trimmedDraftName
            subject.modifiedAt = .now
        }

        isEditingName = false
        isRenaming = false
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { setPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    setPendingDeletion = nil
                }
            }
        )
    }

    private func createSet() {
        let name = newSetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let set = FlashcardSet(name: name)
        set.position = subject.sortedFlashcardSets.count
        set.subject = subject

        modelContext.insert(set)
        subject.modifiedAt = .now

        do {
            try modelContext.save()
            closeSheet()
        } catch {
            print("Failed to save flashcard set: \(error)")
        }
    }

    private func delete(_ set: FlashcardSet) {
        withAnimation(.snappy(duration: 0.35)) {
            modelContext.delete(set)
        }

        subject.modifiedAt = .now

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete flashcard set: \(error)")
        }

        setPendingDeletion = nil
    }

    private func closeSheet() {
        newSetName = ""
        showingNewSet = false
    }
}
