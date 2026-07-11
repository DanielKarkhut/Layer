//
//  SongUploadService.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import CoreLocation
import Foundation
import Supabase
import UniformTypeIdentifiers

struct UploadedSong {
    let id: UUID
    let storagePath: String
}

enum SongUploadError: LocalizedError {
    case missingSession
    case missingFileExtension
    case unsupportedFileType
    case fileTooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "Sign in before uploading a song."
        case .missingFileExtension:
            "Choose an audio file with a file extension."
        case .unsupportedFileType:
            "Choose an audio file."
        case .fileTooLarge(let maxBytes):
            "Choose a file smaller than \(ByteCountFormatter.string(fromByteCount: Int64(maxBytes), countStyle: .file))."
        }
    }
}

/// Talks to Supabase for the upload flow. The mirror image of
/// `SongMapService`: this writes songs, that one reads them.
struct SongUploadService {
    private static let maxFileBytes = 50 * 1024 * 1024

    private let client: SupabaseClient

    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

    /// The whole upload, in two server calls: (1) put the audio file in the
    /// private `song` Storage bucket under `{your-user-id}/{random}.mp3`,
    /// (2) call the `create_song` database function, which validates
    /// everything and inserts the song row at (lat, lng).
    /// Runs when the Drop tab's Upload button is tapped.
    func uploadSong(
        name: String,
        fileURL: URL,
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Int,
        expiresAt: Date?
    ) async throws -> UploadedSong {
        let session = try await client.auth.session
        let userID = session.user.id.uuidString.lowercased()
        let fileData = try readAudioData(from: fileURL)

        guard fileData.count <= Self.maxFileBytes else {
            throw SongUploadError.fileTooLarge(maxBytes: Self.maxFileBytes)
        }

        let fileExtension = try audioFileExtension(for: fileURL)
        let storagePath = "\(userID)/\(UUID().uuidString.lowercased()).\(fileExtension)"

        try await client.storage
            .from("song")
            .upload(
                storagePath,
                data: fileData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: mimeType(for: fileExtension),
                    upsert: false
                )
            )

        let params = CreateSongParameters(
            name: name,
            storagePath: storagePath,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            radiusMeters: radiusMeters,
            expiresAt: expiresAt
        )

        let songID: UUID = try await client
            .rpc("create_song", params: params)
            .execute()
            .value

        return UploadedSong(id: songID, storagePath: storagePath)
    }

    /// Reads the picked file's bytes. The "security scope" dance is required
    /// because the file lives outside our sandbox (Files app, iCloud Drive…)
    /// and iOS only lends us access to it briefly.
    private func readAudioData(from fileURL: URL) throws -> Data {
        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: fileURL, options: .mappedIfSafe)
    }

    /// Makes sure the picked file really is audio and returns its extension
    /// ("mp3", "m4a", …) for building the storage path.
    /// Example: "demo.pdf" → throws; "demo.mp3" → "mp3".
    private func audioFileExtension(for fileURL: URL) throws -> String {
        let fileExtension = fileURL.pathExtension.lowercased()

        guard !fileExtension.isEmpty else {
            throw SongUploadError.missingFileExtension
        }

        guard UTType(filenameExtension: fileExtension)?.conforms(to: .audio) == true else {
            throw SongUploadError.unsupportedFileType
        }

        return fileExtension
    }

    /// The content type sent with the upload — the bucket only accepts audio
    /// MIME types, so this must match. Example: "mp3" → "audio/mpeg".
    private func mimeType(for fileExtension: String) -> String {
        UTType(filenameExtension: fileExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}

private struct CreateSongParameters: Encodable {
    let name: String
    let storagePath: String
    let lat: Double
    let lng: Double
    let radiusMeters: Int
    let expiresAt: Date?
    let misc: [String: String]? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case storagePath = "storage_path"
        case lat
        case lng
        case radiusMeters = "radius_m"
        case expiresAt = "expires_at"
        case misc
    }
}
