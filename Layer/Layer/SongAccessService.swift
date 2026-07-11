//
//  SongAccessService.swift
//  Layer
//

import CoreLocation
import Foundation
import Supabase

struct SongAccess: Decodable, Equatable, Sendable {
    let signedURL: URL
    let expiresInSeconds: Int
    let name: String
    let uploadedBy: String

    enum CodingKeys: String, CodingKey {
        case signedURL = "signed_url"
        case expiresInSeconds = "expires_in"
        case name
        case uploadedBy = "uploaded_by"
    }
}

enum SongAccessError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            message
        }
    }
}

struct SongAccessService: Sendable {
    private let client: SupabaseClient

    /// Creates a service that uses the shared Supabase client unless a test client is supplied.
    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

    /// Asks the protected Edge Function for a short-lived playback URL at the user's location.
    func requestAccess(
        to songID: UUID,
        from coordinate: CLLocationCoordinate2D
    ) async throws -> SongAccess {
        // This also produces a clearer client-side error if the session has expired.
        _ = try await client.auth.session

        let request = SongAccessRequest(
            songID: songID,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        do {
            let access: SongAccess = try await client.functions.invoke(
                "song-access",
                options: .init(body: request)
            )
            return access
        } catch let FunctionsError.httpError(_, data) {
            if let response = try? JSONDecoder().decode(SongAccessErrorResponse.self, from: data) {
                throw SongAccessError.server(response.error)
            }
            throw SongAccessError.server("Song access failed.")
        }
    }
}

private struct SongAccessRequest: Encodable, Sendable {
    let songID: UUID
    let latitude: Double
    let longitude: Double

    enum CodingKeys: String, CodingKey {
        case songID = "song_id"
        case latitude = "lat"
        case longitude = "lng"
    }
}

private struct SongAccessErrorResponse: Decodable {
    let error: String
}
