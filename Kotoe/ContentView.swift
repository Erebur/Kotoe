import SwiftData
//
//  ContentView.swift
//  Flash
//
//  Created by Simon Weber on 18.10.26.
//
import SwiftUI

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<Subject> { !$0.isArchived },
        sort: \Subject.name,
        order: .forward
    )
    private var subjects: [Subject]

    @State private var showingNewSubject = false
    @State private var newSubjectName = ""

    var body: some View {
        NavigationStack {
            Group {
                if subjects.isEmpty {
                    ContentUnavailableView(
                        "No Subjects Yet",
                        systemImage: "books.vertical",
                        description: Text("Create a subject to get started.")
                    )
                } else {
                    List {
                        ForEach(subjects) { subject in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(subject.name)
                                    .font(.headline)

                                Text("\((subject.flashcardSets ?? []).count) flashcard sets")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteSubjects)
                    }
                }
            }
            .navigationTitle("My Subjects")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingNewSubject = true
                    } label: {
                        Label("Add Subject", systemImage: "plus")
                    }
                }

                ToolbarItem(placement: .automatic) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingNewSubject) {
                newSubjectSheet
            }
        }
    }

    // MARK: - New Subject Sheet

    private var newSubjectSheet: some View {
        NavigationStack {
            Form {
                Section("Subject Details") {
                    TextField("Subject name", text: $newSubjectName)
                        .autocorrectionDisabled(false)
                }
            }
            .navigationTitle("New Subject")
            //            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        closeSheet()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSubject()
                    }
                    .disabled(
                        newSubjectName.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func createSubject() {
        let name = newSubjectName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !name.isEmpty else { return }

        let subject = Subject(name: name)

        modelContext.insert(subject)

        do {
            try modelContext.save()
            closeSheet()
        } catch {
            print("Failed to save subject: \(error)")
        }
    }

    private func deleteSubjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(subjects[index])
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete subjects: \(error)")
        }
    }

    private func closeSheet() {
        newSubjectName = ""
        showingNewSubject = false
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Subject.self,
                FlashcardSet.self,
                Flashcard.self,
                FlashcardSide.self,
            ],
            inMemory: true
        )
}
