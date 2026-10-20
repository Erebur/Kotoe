//
//  SubjectView.swift
//  Kōtoe
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

    var body: some View {
        Form {
            titleSection
            overviewSection
            notesSection
            setsSection
        }
        // Tap on a set -> study mode
        .navigationDestination(for: FlashcardSet.self) { set in
            StudyView(flashcardSet: set)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSet = true
                } label: {
                    Label("Add Set", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewSet) {
            newSetSheet
        }
        // Swipe left / long press -> edit the set's cards
        .sheet(item: $editingSet) { set in
            FlashcardSetEditView(flashcardSet: set)
        }
        .onChange(of: subject.name) {
            subject.modifiedAt = .now
        }
        .onAppear {
            subject.lastAccessedAt = .now
        }
    }
    
    // MARK: - Title

    private var titleSection: some View {
        Section {
            TextField("Subject name", text: $subject.name, axis: .vertical)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1...3)
                .submitLabel(.done)
                .textFieldStyle(.plain)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
    }

    // MARK: - Overview

    private var overviewSection: some View {
        let allCards = subject.sortedFlashcardSets.flatMap { $0.sortedFlashcards }

        return Section {
            NavigationLink {
                StudyView(title: subject.name, cards: allCards)
            } label: {
                Label("Study All", systemImage: "rectangle.on.rectangle.angled")
                    .font(.headline)
            }
            .disabled(allCards.isEmpty)
        } footer: {
            Text(
                allCards.isEmpty
                    ? "Add cards to a set to start studying."
                    : "\(allCards.count) cards from \(subject.sortedFlashcardSets.count) sets"
            )
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField(
                "Add notes about this subject…",
                text: notesBinding,
                axis: .vertical
            )
            .lineLimit(3...12)
        }
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
        Section("Flashcard Sets") {
            let sets = subject.sortedFlashcardSets

            if sets.isEmpty {
                Text("No flashcard sets yet. Tap + to add one.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sets) { set in
                    NavigationLink {
                        StudyView(flashcardSet: set)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(set.name)
                                .font(.headline)

                            Text("\(set.sortedFlashcards.count) cards")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editingSet = set
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            delete(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button {
                            editingSet = set
                        } label: {
                            Label("Edit Cards", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            delete(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - New Set Sheet

    private var newSetSheet: some View {
        NavigationStack {
            Form {
                Section("Set Details") {
                    TextField("Set name", text: $newSetName)
                }
            }
            .navigationTitle("New Flashcard Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { closeSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createSet() }
                        .disabled(
                            newSetName.trimmingCharacters(
                                in: .whitespacesAndNewlines
                            ).isEmpty
                        )
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

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
        modelContext.delete(set)
        subject.modifiedAt = .now

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete flashcard set: \(error)")
        }
    }

    private func closeSheet() {
        newSetName = ""
        showingNewSet = false
    }
}
