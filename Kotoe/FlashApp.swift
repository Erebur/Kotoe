//
//  FlashApp.swift
//  Kōtoe
//
//  Created by Simon Weber on 18.10.26.
//

import SwiftData
import SwiftUI

@main
struct FlashApp: App {

    /// Observes CloudKit's import and export events so the library screen can
    /// show whether the last sync succeeded and which local item a failed
    /// record belongs to.
    @State private var syncMonitor = CloudKitSyncMonitor(
        container: Self.modelContainer
    )

    private static let modelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            FlashcardSet.self,
            Flashcard.self,
            FlashcardSide.self,
            FlashcardReview.self,
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(KotoeTheme.accent)
                .environment(syncMonitor)
        }
        .modelContainer(Self.modelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .windowToolbarStyle(.unified)
        #endif
    }
}
