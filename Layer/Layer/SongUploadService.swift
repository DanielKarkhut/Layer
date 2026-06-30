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

struct SongUploadService {
    private static let maxFileBytes = 50 * 1024 * 1024

    private let client: SupabaseClient

    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

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

    private func readAudioData(from fileURL: URL) throws -> Data {
        let hasSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        return try Data(contentsOf: fileURL, options: .mappedIfSafe)
    }

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
