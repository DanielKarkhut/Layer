//
//  RemoteSong.swift
//  Layer
//

import CoreLocation
import Foundation

/// A discoverable song returned by the Supabase `songs_near` RPC.
struct RemoteSong: Decodable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let uploadedBy: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
    let distanceMeters: Double
    let isInRange: Bool
    let expiresAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var distanceDescription: String {
        if distanceMeters < 1_000 {
            return "\(Int(distanceMeters.rounded())) m away"
        }

        return String(format: "%.1f km away", distanceMeters / 1_000)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uploadedBy = "uploaded_by"
        case latitude = "lat"
        case longitude = "lng"
        case radiusMeters = "radius_m"
        case distanceMeters = "distance_m"
        case isInRange = "in_range"
        case expiresAt = "expires_at"
    }
}
