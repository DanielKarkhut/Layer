//
//  LocalLibraryStore.swift
//  Layer
//

import Foundation

enum LocalLibraryStore {
    static let filename = "LayerDownloads.store"

    /// Increase this number when a development build should discard and rebuild local library data.
    static let resetVersion = 1

    private static let resetVersionKey = "localLibraryResetVersion"
    private static let legacyStoreFilename = "default.store"
    private static let sqliteCompanionSuffixes = ["", "-shm", "-wal", "_SUPPORT"]
    private static let downloadedAudioDirectoryName = "DownloadedSongs"

    /// Returns the full URL for Layer's dedicated SwiftData download store.
    static func storeURL(in applicationSupportURL: URL) -> URL {
        applicationSupportURL.appendingPathComponent(filename)
    }

    /// Removes stores from earlier development builds once for each `resetVersion`.
    /// Returns true when the caller should mark the reset complete after opening the new store.
    static func resetIfNeeded(
        in applicationSupportURL: URL,
        preferences: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard preferences.integer(forKey: resetVersionKey) < resetVersion else {
            return false
        }

        for storeFilename in [legacyStoreFilename, filename] {
            for suffix in sqliteCompanionSuffixes {
                try removeIfPresent(
                    applicationSupportURL.appendingPathComponent(storeFilename + suffix),
                    fileManager: fileManager
                )
            }
        }

        try removeIfPresent(
            applicationSupportURL.appendingPathComponent(downloadedAudioDirectoryName),
            fileManager: fileManager
        )

        return true
    }

    /// Records that the reset completed after the fresh store opened successfully.
    static func markResetComplete(preferences: UserDefaults = .standard) {
        preferences.set(resetVersion, forKey: resetVersionKey)
    }

    /// Deletes a file or directory only when it currently exists.
    private static func removeIfPresent(_ url: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
