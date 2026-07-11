//
//  SongDownloadStore.swift
//  Layer
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

enum SongDownloadError: LocalizedError {
    case alreadyDownloaded
    case invalidServerResponse

    var errorDescription: String? {
        switch self {
        case .alreadyDownloaded:
            "This song is already in your library."
        case .invalidServerResponse:
            "The song download did not return a valid file."
        }
    }
}

struct SongDownloadStore {
    private let fileManager: FileManager
    private let session: URLSession

    /// Creates a download store with injectable file and network dependencies for testing.
    init(fileManager: FileManager = .default, session: URLSession = .shared) {
        self.fileManager = fileManager
        self.session = session
    }

    /// Downloads audio, moves it into Application Support, and saves its SwiftData metadata.
    @MainActor
    func download(
        song: RemoteSong,
        from remoteURL: URL,
        ownerUserID: UUID,
        modelContext: ModelContext
    ) async throws {
        let remoteSongID = song.id
        let ownerID = ownerUserID
        let descriptor = FetchDescriptor<DownloadedSong>(
            predicate: #Predicate {
                $0.remoteSongID == remoteSongID && $0.ownerUserID == ownerID
            }
        )

        guard try modelContext.fetchCount(descriptor) == 0 else {
            throw SongDownloadError.alreadyDownloaded
        }

        let (temporaryURL, response) = try await session.download(from: remoteURL)
        let temporaryFileSize = try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard temporaryFileSize > 0 else {
            throw SongDownloadError.invalidServerResponse
        }

        let fileExtension = preferredFileExtension(response: response, remoteURL: remoteURL)
        let relativePath = relativePath(
            songID: song.id,
            ownerUserID: ownerUserID,
            fileExtension: fileExtension
        )
        let destinationURL = try localURL(for: relativePath, createDirectory: true)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: destinationURL)

        let downloadedSong = DownloadedSong(
            remoteSongID: song.id,
            ownerUserID: ownerUserID,
            name: song.name,
            artist: song.uploadedBy,
            localRelativePath: relativePath
        )
        modelContext.insert(downloadedSong)

        do {
            try modelContext.save()
        } catch {
            modelContext.delete(downloadedSong)
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    /// Removes both a song's local audio file and its SwiftData library record.
    @MainActor
    func delete(_ song: DownloadedSong, modelContext: ModelContext) throws {
        let fileURL = try localURL(for: song.localRelativePath)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }

        modelContext.delete(song)
        try modelContext.save()
    }

    /// Resolves a stored relative path inside Application Support, optionally creating its folder.
    func localURL(for relativePath: String, createDirectory: Bool = false) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let fileURL = applicationSupportURL.appendingPathComponent(relativePath)

        if createDirectory {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        return fileURL
    }

    /// Builds the user-scoped relative filename used for a downloaded song.
    private func relativePath(
        songID: UUID,
        ownerUserID: UUID,
        fileExtension: String
    ) -> String {
        "DownloadedSongs/\(ownerUserID.uuidString.lowercased())/\(songID.uuidString.lowercased()).\(fileExtension)"
    }

    /// Chooses a useful audio extension from the response, signed URL, or MIME type.
    private func preferredFileExtension(response: URLResponse, remoteURL: URL) -> String {
        let suggestedExtension = response.suggestedFilename.map {
            URL(fileURLWithPath: $0).pathExtension
        }
        if let suggestedExtension, !suggestedExtension.isEmpty {
            return suggestedExtension.lowercased()
        }

        if !remoteURL.pathExtension.isEmpty {
            return remoteURL.pathExtension.lowercased()
        }

        if let mimeType = response.mimeType,
           let fileExtension = UTType(mimeType: mimeType)?.preferredFilenameExtension {
            return fileExtension
        }

        return "m4a"
    }
}
