//
//  LayerTests.swift
//  LayerTests
//
//  Created by Daniel Karkhut on 6/17/26.
//

import CoreLocation
import Foundation
import Testing
@testable import Layer

@MainActor
struct LayerTests {
    /// Verifies that a reset deletes old stores and audio, then runs only once per version.
    @Test func localLibraryResetRemovesOldStoresAndAudioOnlyOnce() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "LayerTests.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: defaultsSuiteName)!

        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
            preferences.removePersistentDomain(forName: defaultsSuiteName)
        }

        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        let oldStoreFiles = [
            "default.store",
            "default.store-shm",
            "default.store-wal",
            "LayerDownloads.store",
            "LayerDownloads.store-shm",
            "LayerDownloads.store-wal",
        ]
        for filename in oldStoreFiles {
            try Data("old".utf8).write(
                to: temporaryDirectory.appendingPathComponent(filename)
            )
        }

        let audioDirectory = temporaryDirectory
            .appendingPathComponent("DownloadedSongs", isDirectory: true)
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: audioDirectory.appendingPathComponent("song.m4a"))

        let didReset = try LocalLibraryStore.resetIfNeeded(
            in: temporaryDirectory,
            preferences: preferences,
            fileManager: fileManager
        )

        #expect(didReset)
        for filename in oldStoreFiles {
            #expect(!fileManager.fileExists(
                atPath: temporaryDirectory.appendingPathComponent(filename).path
            ))
        }
        #expect(!fileManager.fileExists(atPath: audioDirectory.path))

        LocalLibraryStore.markResetComplete(preferences: preferences)
        let didResetAgain = try LocalLibraryStore.resetIfNeeded(
            in: temporaryDirectory,
            preferences: preferences,
            fileManager: fileManager
        )
        #expect(!didResetAgain)
    }

    /// Verifies that RPC latitude and longitude decode into the correct coordinate fields.
    @Test func remoteSongDecodesLatitudeAndLongitudeDeliberately() throws {
        let json = """
        {
          "id": "2e97e937-35b2-4cc9-8f49-f11884687051",
          "name": "Test Drop",
          "uploaded_by": "Layer Artist",
          "lat": 40.7128,
          "lng": -74.0060,
          "radius_m": 100,
          "distance_m": 42.4,
          "in_range": true,
          "expires_at": null
        }
        """

        let song = try JSONDecoder().decode(RemoteSong.self, from: Data(json.utf8))

        #expect(song.coordinate.latitude == 40.7128)
        #expect(song.coordinate.longitude == -74.0060)
        #expect(song.isInRange)
        #expect(song.distanceDescription == "42 m away")
    }

    /// Verifies that the Edge Function's signed-URL response maps to the Swift access model.
    @Test func songAccessDecodesEdgeFunctionResponse() throws {
        let json = """
        {
          "signed_url": "https://example.com/song.m4a?token=short-lived",
          "expires_in": 300,
          "name": "Test Drop",
          "uploaded_by": "Layer Artist"
        }
        """

        let access = try JSONDecoder().decode(SongAccess.self, from: Data(json.utf8))

        #expect(access.name == "Test Drop")
        #expect(access.uploadedBy == "Layer Artist")
        #expect(access.expiresInSeconds == 300)
        #expect(access.signedURL.host == "example.com")
    }

    /// Verifies that the default map setting asks the RPC for every discoverable song.
    @Test func zeroMapSearchRadiusRequestsAllDiscoverableSongs() {
        #expect(AppTuning.Map.searchRadiusMeters == 0)
    }
}
