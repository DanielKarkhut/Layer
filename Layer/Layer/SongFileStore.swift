//
//  SongFileStore.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import Foundation

enum SongFileStoreError: LocalizedError {
    case missingDownloadedFile

    var errorDescription: String? {
        switch self {
        case .missingDownloadedFile:
            "The downloaded audio file is missing from this device."
        }
    }
}

struct SongFileStore {
    private let folderName = "DownloadedSongs"
    private let fileManager = FileManager.default

    func saveRemoteFile(from url: URL, songID: UUID) async throws -> String {
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        let directory = try downloadsDirectory()
        let fileExtension = preferredFileExtension(responseURL: response.url, fallbackURL: url)
        let localFilename = "\(songID.uuidString.lowercased()).\(fileExtension)"
        let destinationURL = directory.appendingPathComponent(localFilename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        return localFilename
    }

    func fileURL(for downloadedSong: DownloadedSong) throws -> URL {
        let url = try downloadsDirectory().appendingPathComponent(downloadedSong.localFilename)
        guard fileManager.fileExists(atPath: url.path) else {
            throw SongFileStoreError.missingDownloadedFile
        }

        return url
    }

    private func downloadsDirectory() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = applicationSupportURL.appendingPathComponent(folderName, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }

        return directoryURL
    }

    private func preferredFileExtension(responseURL: URL?, fallbackURL: URL) -> String {
        let responseExtension = responseURL?.pathExtension
        if let responseExtension, !responseExtension.isEmpty {
            return responseExtension
        }

        let fallbackExtension = fallbackURL.pathExtension
        if !fallbackExtension.isEmpty {
            return fallbackExtension
        }

        return "m4a"
    }
}
