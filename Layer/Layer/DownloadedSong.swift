//
//  DownloadedSong.swift
//  Layer
//
//  The on-device library. Each record is one song the user chose to keep.
//  The database row (SwiftData) stores the metadata; the audio bytes live as
//  a plain file in Application Support, referenced by `fileName`.
//

import Foundation
import SwiftData

/// One song saved permanently on this device. Stored with SwiftData, so it
/// survives app relaunches and works with zero network.
///
/// Every property has a default value ON PURPOSE: when the model gains a new
/// field, SwiftData's automatic migration fills existing rows with the default
/// instead of crashing at launch with "missing attribute values on mandatory
/// destination attribute". Keep defaults on anything you add here.
@Model
final class DownloadedSong {
    /// The song's ID from the server — unique so the same song can't be saved twice.
    @Attribute(.unique) var songID: UUID = UUID()
    var name: String = ""
    var artist: String = ""
    /// Name of the audio file inside our private songs folder (see `SongFileStore`).
    var fileName: String = ""
    var downloadedAt: Date = Date.now

    init(songID: UUID, name: String, artist: String, fileName: String, downloadedAt: Date = .now) {
        self.songID = songID
        self.name = name
        self.artist = artist
        self.fileName = fileName
        self.downloadedAt = downloadedAt
    }

    /// Full path to this song's audio file on disk. Example: hand this to
    /// `SongPlayer.play(fileURL:title:)` when a library row is tapped.
    var fileURL: URL {
        SongFileStore.url(for: fileName)
    }
}

/// Tiny helper for reading/writing the audio files that back `DownloadedSong`
/// records. All files live in one app-private folder:
/// `Application Support/<LayerConfig.Library.audioFolderName>/`.
enum SongFileStore {
    /// The folder where every downloaded audio file lives, created on first use.
    /// Runs whenever we save, load, or delete a song file.
    static func folderURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent(LayerConfig.Library.audioFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Where a given file name lives on disk (whether or not it exists yet).
    static func url(for fileName: String) -> URL {
        let folder = (try? folderURL()) ?? FileManager.default.temporaryDirectory
        return folder.appendingPathComponent(fileName)
    }

    /// Writes downloaded audio bytes to disk and returns the file's URL.
    /// Runs when the user taps "Download" on the map's song card.
    static func save(_ data: Data, fileName: String) throws -> URL {
        let destination = try folderURL().appendingPathComponent(fileName)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    /// Removes a song's audio file from disk (ignores files already gone).
    /// Runs when the user swipe-deletes a song in the Library.
    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
