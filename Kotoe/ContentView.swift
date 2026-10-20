//
//  ContentView.swift
//  Flash
//
//  Created by Simon Weber on 18.10.26.
//

import SwiftData
import SwiftUI

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(
        filter: #Predicate<Subject> { !$0.isArchived },
        sort: \Subject.name,
        order: .forward
    )
    private var subjects: [Subject]

    @State private var showingNewSubject = false
    @State private var newSubjectName = ""
    @State private var subjectPendingDeletion: Subject?
    @State private var customizingSubject: Subject?

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        if subjects.isEmpty {
                            emptyState
                                .transition(
                                    .scale(scale: 0.97)
                                        .combined(with: .opacity)
                                )
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(subjects) { subject in
                                    subjectCard(for: subject)
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                    .frame(maxWidth: 1100, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            }
            .navigationTitle("Kōtoe")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewSubject = true
                    } label: {
                        Label("New Subject", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create a new subject")
                }
            }
            .sheet(isPresented: $showingNewSubject) {
                CreateItemSheet(
                    title: "New Subject",
                    prompt: "A subject groups related flashcard sets, like a course or a language.",
                    systemImage: "books.vertical.fill",
                    placeholder: "Subject name",
                    actionTitle: "Create",
                    name: $newSubjectName,
                    onCreate: createSubject,
                    onCancel: closeSheet
                )
                .dialogSheet()
            }
            .sheet(item: $customizingSubject) { subject in
                appearanceEditor(for: subject)
            }
            .confirmationDialog(
                "Delete Subject?",
                isPresented: deleteConfirmationBinding,
                titleVisibility: .visible,
                presenting: subjectPendingDeletion
            ) { subject in
                Button("Delete \(subject.name)", role: .destructive) {
                    delete(subject)
                }
                Button("Cancel", role: .cancel) {
                    subjectPendingDeletion = nil
                }
            } message: { subject in
                Text(
                    "\(subject.cardCount) cards in \(subject.sortedFlashcardSets.count) sets will be deleted. This can't be undone."
                )
            }
            .animation(.snappy(duration: 0.35), value: subjects.count)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your Library")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        guard !subjects.isEmpty else {
            return "Create a subject to organize your flashcard sets."
        }

        let setCount = subjects.reduce(0) {
            $0 + $1.sortedFlashcardSets.count
        }
        let cardCount = subjects.reduce(0) {
            $0 + $1.cardCount
        }

        return [
            pluralized(subjects.count, "subject"),
            pluralized(setCount, "set"),
            pluralized(cardCount, "card"),
        ]
        .joined(separator: " · ")
    }

    private func pluralized(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    // MARK: - Subject Cards

    private var columns: [GridItem] {
        #if os(macOS)
            [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: 14)]
        #else
            if horizontalSizeClass == .compact {
                [GridItem(.flexible())]
            } else {
                [GridItem(.adaptive(minimum: 270, maximum: 380), spacing: 14)]
            }
        #endif
    }

    private func subjectCard(for subject: Subject) -> some View {
        let sets = subject.sortedFlashcardSets
        let style = subject.style

        return NavigationLink {
            SubjectView(subject: subject)
        } label: {
            HStack(spacing: 14) {
                IconTile(
                    symbol: style.symbol,
                    tint: style.tint,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(subject.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(
                        "\(pluralized(sets.count, "set")) · \(pluralized(subject.cardCount, "card"))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .cardSurface(padding: 14, tint: style.tint)
            .contentShape(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(PressableCardStyle())
        .hoverLift()
        .contextMenu {
            Button {
                customizingSubject = subject
            } label: {
                Label("Change Icon…", systemImage: "paintpalette")
            }

            Divider()

            Button(role: .destructive) {
                subjectPendingDeletion = subject
            } label: {
                Label("Delete Subject", systemImage: "trash")
            }
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                KotoeTheme.accent.opacity(0.18),
                                KotoeTheme.gold.opacity(0.05),
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 70
                        )
                    )
                    .frame(width: 132, height: 132)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [KotoeTheme.accent, KotoeTheme.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text("Build Your First Subject")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(
                    "Subjects keep your sets organized — one for each course, language, or topic you're learning."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            Button {
                showingNewSubject = true
            } label: {
                Label("New Subject", systemImage: "plus")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(KotoeTheme.accent)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
    }

    // MARK: - Actions

    private func appearanceEditor(for subject: Subject) -> some View {
        AppearanceEditor(
            title: "Subject Appearance",
            subtitle: "Choose the icon and color that represent \(subject.name).",
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

    private func saveAppearance() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save subject appearance: \(error)")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { subjectPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    subjectPendingDeletion = nil
                }
            }
        )
    }

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

    private func delete(_ subject: Subject) {
        withAnimation(.snappy(duration: 0.35)) {
            modelContext.delete(subject)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete subject: \(error)")
        }

        subjectPendingDeletion = nil
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
