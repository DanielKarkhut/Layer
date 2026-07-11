//
//  SongAccessService.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import CoreLocation
import Foundation
import Supabase

enum SongAccessError: LocalizedError {
    case missingSession
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            "Sign in before listening to a song."
        case .invalidResponse:
            "The song access response was invalid."
        case .serverMessage(let message):
            message
        }
    }
}

struct SongAccessService {
    private let client: SupabaseClient
    private let session: URLSession

    nonisolated init(
        client: SupabaseClient = LayerSupabase.client,
        session: URLSession = .shared
    ) {
        self.client = client
        self.session = session
    }

    func playbackURL(for song: MapSong, at coordinate: CLLocationCoordinate2D) async throws -> URL {
        let authSession = try await client.auth.session
        let endpoint = URL(string: "\(LayerSupabase.urlString)/functions/v1/song-access")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(LayerSupabase.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            SongAccessRequest(
                songID: song.id,
                lat: coordinate.latitude,
                lng: coordinate.longitude
            )
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SongAccessError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(SongAccessErrorResponse.self, from: data) {
                throw SongAccessError.serverMessage(errorResponse.error)
            }

            throw SongAccessError.serverMessage("Song access failed with status \(httpResponse.statusCode).")
        }

        let accessResponse = try JSONDecoder().decode(SongAccessResponse.self, from: data)
        return accessResponse.signedURL
    }
}

private struct SongAccessRequest: Encodable {
    let songID: UUID
    let lat: Double
    let lng: Double

    enum CodingKeys: String, CodingKey {
        case songID = "song_id"
        case lat
        case lng
    }
}

private struct SongAccessResponse: Decodable {
    let signedURL: URL

    enum CodingKeys: String, CodingKey {
        case signedURL = "signed_url"
    }
}

private struct SongAccessErrorResponse: Decodable {
    let error: String
}
