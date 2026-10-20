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
            AmbientBackground()

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
        .clearInitialFocusOnMac()
        .macNavigationTitle(subject.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSet = true
                } label: {
                    Label("Add Set", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Create a new flashcard set")
            }
        }
        .sheet(isPresented: $showingNewSet) {
            CreateItemSheet(
                title: "New Flashcard Set",
                prompt: "Sets keep a handful of related cards together, like one chapter or topic.",
                systemImage: "rectangle.stack.fill",
                placeholder: "Set name",
                actionTitle: "Create",
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
        .confirmationDialog(
            "Delete Set?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible,
            presenting: setPendingDeletion
        ) { set in
            Button("Delete \(set.name)", role: .destructive) {
                delete(set)
            }
            Button("Cancel", role: .cancel) {
                setPendingDeletion = nil
            }
        } message: { set in
            Text(
                "\(set.sortedFlashcards.count) cards will be deleted. This can't be undone."
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
            IconTile(
                symbol: subject.style.symbol,
                tint: subject.style.tint,
                size: 68
            )

            VStack(alignment: .leading, spacing: 6) {
                if isRenaming {
                    HStack(spacing: 8) {
                        TextField("Subject name", text: $draftName)
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
                        .help("Rename subject")
                    }
                }

                HStack(spacing: 13) {
                    StatLabel(
                        text: pluralized(sets.count, "set"),
                        systemImage: "square.stack.3d.up.fill"
                    )

                    StatLabel(
                        text: pluralized(allCards.count, "card"),
                        systemImage: "rectangle.on.rectangle.angled"
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Study All

    private var studyAllCard: some View {
        NavigationLink {
            StudyView(title: subject.name, cards: allCards)
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
                    Text("Study All")
                        .font(.headline)

                    Text(
                        allCards.isEmpty
                            ? "Add cards to a set to get started"
                            : "\(pluralized(allCards.count, "card")) across \(pluralized(sets.count, "set"))"
                    )
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
                LinearGradient(
                    colors: [
                        KotoeTheme.accent,
                        Color(red: 0.70, green: 0.28, blue: 0.23),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(
                color: KotoeTheme.accent.opacity(0.28),
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
            SectionHeader(title: "Notes", systemImage: "note.text")

            TextField(
                "Write down goals, reminders, or context for this subject…",
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
                    title: "Flashcard Sets",
                    systemImage: "square.stack.3d.up.fill"
                )

                Spacer()

                Button {
                    showingNewSet = true
                } label: {
                    Label("New Set", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(KotoeTheme.accent)
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
        HStack(spacing: 10) {
            NavigationLink {
                StudyView(flashcardSet: set)
            } label: {
                HStack(spacing: 14) {
                    IconTile(
                        symbol: "rectangle.stack.fill",
                        tint: subject.style.tint,
                        size: 42
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(set.name)
                            .font(.headline)
                            .lineLimit(1)

                        Text(
                            pluralized(set.sortedFlashcards.count, "card")
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
                    editingSet = set
                } label: {
                    Label("Edit Cards", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    setPendingDeletion = set
                } label: {
                    Label("Delete Set", systemImage: "trash")
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
            .help("Set actions")
        }
        .cardSurface(padding: 12)
        .hoverLift()
        .contextMenu {
            Button {
                editingSet = set
            } label: {
                Label("Edit Cards", systemImage: "pencil")
            }

            Button(role: .destructive) {
                setPendingDeletion = set
            } label: {
                Label("Delete Set", systemImage: "trash")
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
                    .foregroundStyle(KotoeTheme.accent)

                Text("Create Your First Set")
                    .font(.headline)

                Text(
                    "A set holds a small group of cards. Add one, then fill it with front and back content."
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
                        KotoeTheme.accent.opacity(0.32),
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

    private func pluralized(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
}
