//
//  LayerApp.swift
//  Layer
//
//  Created by Daniel Karkhut on 6/17/26.
//

import SwiftUI
import SwiftData

@main
struct LayerApp: App {
    /// The on-device database (SwiftData) that backs the Library tab.
    /// Every type listed in the Schema gets its own persisted table;
    /// `isStoredInMemoryOnly: false` means it survives app relaunches.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DownloadedSong.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
