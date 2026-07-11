//
//  SongMapService.swift
//  Layer
//
//  Everything the map needs from Supabase, in two steps:
//    1. fetchSongs — "what songs exist around me?"  (songs_near RPC)
//    2. fetchAudio — "let me hear THIS one"         (song-access Edge Function)
//
//  Playback security model: the private `song` bucket is deliberately
//  unreadable by clients. The ONLY way to audio bytes is the `song-access`
//  Edge Function, which verifies your login, re-checks your distance
//  server-side (get_song_access), and only then mints a signed URL that's
//  valid for 5 minutes. So "you must be physically near a drop to hear it"
//  is enforced by the server, not trusted to the app.
//

import CoreLocation
import Foundation
import Supabase

/// What the `song-access` Edge Function returns when you ARE in range:
/// a short-lived, self-authorizing URL for the audio file.
struct SongAccessGrant: Decodable {
    let signedURL: URL
    /// Seconds until `signedURL` stops working (the server uses 300 = 5 min).
    let expiresIn: Int
    let name: String
    let uploadedBy: String?

    enum CodingKeys: String, CodingKey {
        case signedURL = "signed_url"
        case expiresIn = "expires_in"
        case name = "name"
        case uploadedBy = "uploaded_by"
    }
}

/// Friendly, user-visible reasons a song can't play right now.
enum SongAccessError: LocalizedError {
    /// We don't know where the user is yet, so the server can't check distance.
    case waitingForLocation
    /// The server checked your distance and said you're outside the song's radius.
    case outOfRange(songName: String)
    /// Anything else the server refused or that failed mid-download.
    case playbackFailed(serverMessage: String)

    var errorDescription: String? {
        switch self {
        case .waitingForLocation:
            "Still finding your location — try again in a second."
        case .outOfRange(let songName):
            "You're too far from “\(songName)” — walk closer to unlock it."
        case .playbackFailed(let serverMessage):
            "Couldn't fetch this song's audio. (Server said: \(serverMessage))"
        }
    }
}

struct SongMapService {
    private let client: SupabaseClient

    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

    /// Asks the database for every song around a point, sorted nearest-first.
    /// Runs when the map opens, when your location resolves, and on refresh.
    /// Example: with the default 20,000 km search radius this returns every
    /// song in the DB; shrink `LayerConfig.Map.searchRadiusMeters` to filter.
    func fetchSongs(around coordinate: CLLocationCoordinate2D) async throws -> [Song] {
        let params = SongsNearParams(
            userLat: coordinate.latitude,
            userLng: coordinate.longitude,
            searchRadiusM: LayerConfig.Map.searchRadiusMeters
        )

        return try await client
            .rpc("songs_near", params: params)
            .execute()
            .value
    }

    /// Fetches a song's audio bytes the only way possible: ask the
    /// `song-access` Edge Function for permission (login + distance are
    /// verified server-side), then download from the signed URL it mints.
    /// Runs when you tap Play/Download on a song card.
    /// Example: standing 40 m from a song with a 100 m radius → bytes;
    /// 400 m away → throws `.outOfRange`.
    func fetchAudio(
        songID: UUID,
        songName: String,
        at coordinate: CLLocationCoordinate2D
    ) async throws -> (data: Data, fileExtension: String) {
        let grant = try await requestAccess(songID: songID, songName: songName, at: coordinate)

        let (data, response) = try await URLSession.shared.data(from: grant.signedURL)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SongAccessError.playbackFailed(
                serverMessage: "signed URL download returned HTTP \(http.statusCode)"
            )
        }

        // The signed URL's path ends in the real file name — its extension
        // ("mp3", "m4a", …) is reused when saving the file to the library.
        let pathExtension = grant.signedURL.pathExtension
        return (data, pathExtension.isEmpty ? "m4a" : pathExtension)
    }

    /// Calls the Edge Function and translates its HTTP errors into the
    /// friendly `SongAccessError` cases above (403 = too far away).
    private func requestAccess(
        songID: UUID,
        songName: String,
        at coordinate: CLLocationCoordinate2D
    ) async throws -> SongAccessGrant {
        let body = SongAccessRequest(
            songId: songID,
            lat: coordinate.latitude,
            lng: coordinate.longitude
        )

        do {
            return try await client.functions.invoke(
                "song-access",
                options: FunctionInvokeOptions(body: body)
            )
        } catch let FunctionsError.httpError(code, data) {
            if code == 403 {
                throw SongAccessError.outOfRange(songName: songName)
            }
            throw SongAccessError.playbackFailed(serverMessage: serverMessage(from: data, code: code))
        }
    }

    /// Digs the {"error": "…"} message out of an Edge Function failure body.
    private func serverMessage(from data: Data, code: Int) -> String {
        struct ErrorBody: Decodable { let error: String? }

        if let body = try? JSONDecoder().decode(ErrorBody.self, from: data), let message = body.error {
            return message
        }

        return "HTTP \(code)"
    }
}

/// Parameter names must match the SQL function's argument names exactly.
private struct SongsNearParams: Encodable {
    let userLat: Double
    let userLng: Double
    let searchRadiusM: Double

    enum CodingKeys: String, CodingKey {
        case userLat = "user_lat"
        case userLng = "user_lng"
        case searchRadiusM = "search_radius_m"
    }
}

/// Request body for the `song-access` Edge Function.
private struct SongAccessRequest: Encodable {
    let songId: UUID
    let lat: Double
    let lng: Double

    enum CodingKeys: String, CodingKey {
        case songId = "song_id"
        case lat
        case lng
    }
}
