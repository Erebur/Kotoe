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
    @Environment(\.locale) private var locale

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

                        disclaimer
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
                        Label("contentView.toolbar.newSubject", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("contentView.toolbar.createSubjectHelp")
                }
            }
            .sheet(isPresented: $showingNewSubject) {
                CreateItemSheet(
                    title: "contentView.newSubjectSheet.title",
                    prompt: "contentView.newSubjectSheet.prompt",
                    systemImage: "books.vertical.fill",
                    placeholder: "contentView.newSubjectSheet.namePlaceholder",
                    actionTitle: "contentView.newSubjectSheet.create",
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
                "contentView.deleteSubjectDialog.title",
                isPresented: deleteConfirmationBinding,
                titleVisibility: .visible,
                presenting: subjectPendingDeletion
            ) { subject in
                Button(
                    String(
                        localized: "contentView.deleteSubjectDialog.delete",
                        defaultValue: "Delete \(subject.name)"
                    ),
                    role: .destructive
                ) {
                    delete(subject)
                }
                Button("shared.actions.cancel", role: .cancel) {
                    subjectPendingDeletion = nil
                }
            } message: { subject in
                Text(
                    String(
                        localized: "contentView.deleteSubjectDialog.message",
                        defaultValue:
                            "\(subject.cardCount) cards in \(subject.sortedFlashcardSets.count) sets will be deleted. This can't be undone."
                    )
                )
            }
            .animation(.snappy(duration: 0.35), value: subjects.count)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("contentView.header.title")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        guard !subjects.isEmpty else {
            return String(
                localized: "contentView.header.emptySummary"
            )
        }

        let setCount = subjects.reduce(0) {
            $0 + $1.sortedFlashcardSets.count
        }
        let cardCount = subjects.reduce(0) {
            $0 + $1.cardCount
        }

        return [
            LocalizedCounts.subjects(subjects.count),
            LocalizedCounts.sets(setCount),
            LocalizedCounts.cards(cardCount),
        ]
        .joined(separator: " · ")
    }

    // MARK: - Footer

    @ViewBuilder
    private var disclaimer: some View {
        if locale.language.languageCode?.identifier != "en" {
            Text("contentView.footer.disclaimer")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
        }
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

    private func subjectSummary(for subject: Subject) -> String {
        [
            LocalizedCounts.sets(subject.sortedFlashcardSets.count),
            LocalizedCounts.cards(subject.cardCount),
        ]
        .joined(separator: " · ")
    }

    private func subjectCard(for subject: Subject) -> some View {
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

                    Text(verbatim: subjectSummary(for: subject))
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
                Label("shared.actions.changeIcon", systemImage: "paintpalette")
            }

            Divider()

            Button(role: .destructive) {
                subjectPendingDeletion = subject
            } label: {
                Label(
                    "contentView.contextMenu.deleteSubject",
                    systemImage: "trash"
                )
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
                Text("contentView.emptyState.title")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                Text(
                    "contentView.emptyState.message"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            }

            Button {
                showingNewSubject = true
            } label: {
                Label("contentView.emptyState.newSubject", systemImage: "plus")
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
            title: "contentView.appearanceEditor.title",
            subtitle: String(
                localized: "contentView.appearanceEditor.subtitle",
                defaultValue:
                    "Choose the icon and color that represent \(subject.name)."
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
