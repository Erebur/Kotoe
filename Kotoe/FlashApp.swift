//
//  FlashApp.swift
//  Flash
//
//  Created by Simon Weber on 18.10.26.
//

import SwiftUI
import SwiftData

@main
struct FlashApp: App {
    private static let demoContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            FlashcardSet.self,
            Flashcard.self,
            FlashcardSide.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        DemoSeed.populate(container.mainContext)
        return container
    }()

    private static let liveContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            FlashcardSet.self,
            Flashcard.self,
            FlashcardSide.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var sharedModelContainer: ModelContainer {
        DemoMode.isActive ? Self.demoContainer : Self.liveContainer
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if DemoMode.isActive {
                    DemoRootView()
                } else {
                    ContentView()
                }
            }
            .tint(KotoeTheme.accent)
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .windowToolbarStyle(.unified)
        #endif
    }
}
