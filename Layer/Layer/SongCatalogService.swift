//
//  SongCatalogService.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import CoreLocation
import Foundation
import Supabase

struct SongCatalogService {
    private let client: SupabaseClient
    private let defaultSearchRadiusMeters = 20_000_000

    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

    func fetchSongs(near coordinate: CLLocationCoordinate2D) async throws -> [MapSong] {
        let params = SongsNearParameters(
            userLat: coordinate.latitude,
            userLng: coordinate.longitude,
            searchRadiusMeters: defaultSearchRadiusMeters
        )

        return try await client
            .rpc("songs_near", params: params)
            .execute()
            .value
    }
}

private struct SongsNearParameters: Encodable {
    let userLat: Double
    let userLng: Double
    let searchRadiusMeters: Int

    enum CodingKeys: String, CodingKey {
        case userLat = "user_lat"
        case userLng = "user_lng"
        case searchRadiusMeters = "search_radius_m"
    }
}
