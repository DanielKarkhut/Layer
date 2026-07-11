//
//  SongDiscoveryService.swift
//  Layer
//

import Combine
import CoreLocation
import Foundation
import Supabase

struct SongDiscoveryService: Sendable {
    private let client: SupabaseClient

    /// Creates a discovery service using the shared Supabase client by default.
    nonisolated init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
    }

    /// Calls `songs_near` and decodes the active song pins around the supplied coordinate.
    func songs(near coordinate: CLLocationCoordinate2D) async throws -> [RemoteSong] {
        let parameters = SongsNearParameters(
            userLatitude: coordinate.latitude,
            userLongitude: coordinate.longitude,
            searchRadiusMeters: AppTuning.Map.searchRadiusMeters
        )

        let songs: [RemoteSong] = try await client
            .rpc("songs_near", params: parameters)
            .execute()
            .value

        return songs
    }
}

private struct SongsNearParameters: Encodable, Sendable {
    let userLatitude: Double
    let userLongitude: Double
    let searchRadiusMeters: Double

    enum CodingKeys: String, CodingKey {
        case userLatitude = "user_lat"
        case userLongitude = "user_lng"
        case searchRadiusMeters = "search_radius_m"
    }
}

@MainActor
final class SongDiscoveryViewModel: ObservableObject {
    @Published private(set) var songs: [RemoteSong] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: SongDiscoveryService

    /// Creates the map's discovery state manager with an injectable service.
    init(service: SongDiscoveryService = SongDiscoveryService()) {
        self.service = service
    }

    /// Refreshes the map songs while publishing loading and error state for the UI.
    func loadSongs(near coordinate: CLLocationCoordinate2D) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            songs = try await service.songs(near: coordinate)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
