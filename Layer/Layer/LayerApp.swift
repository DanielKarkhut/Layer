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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            DownloadedSong.self,
        ])

        do {
            let applicationSupportURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let didResetLocalLibrary = try LocalLibraryStore.resetIfNeeded(
                in: applicationSupportURL
            )
            let modelConfiguration = ModelConfiguration(
                "Downloads",
                schema: schema,
                url: LocalLibraryStore.storeURL(in: applicationSupportURL)
            )

            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            if didResetLocalLibrary {
                LocalLibraryStore.markResetComplete()
            }

            return container
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
