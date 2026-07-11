//
//  Song.swift
//  Layer
//
//  A song pin as the `songs_near` database function returns it.
//  This is a read-only snapshot for the map — the full row (including the
//  audio file's storage path) is intentionally not exposed here.
//

import CoreLocation
import Foundation

/// One row from the `songs_near(user_lat, user_lng, search_radius_m)` RPC.
/// The database computes `distanceMeters` and `inRange` for us, so the app
/// never does its own geo math.
struct Song: Decodable, Identifiable, Equatable {
    let id: UUID
    let name: String
    /// Artist display name; the database may not have one for old rows.
    let uploadedBy: String?
    let lat: Double
    let lng: Double
    /// This song's own "grab distance" in meters — NOT the map search radius.
    let radiusMeters: Int
    /// How far you were from the song when the map last refreshed, in meters.
    let distanceMeters: Double
    /// True when the server says you are inside this song's `radiusMeters`.
    let inRange: Bool
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uploadedBy = "uploaded_by"
        case lat
        case lng
        case radiusMeters = "radius_m"
        case distanceMeters = "distance_m"
        case inRange = "in_range"
        case expiresAt = "expires_at"
    }

    /// Where this song sits on the map. The database sends `lat`/`lng` as two
    /// plain numbers; we deliberately name the mapping here because PostGIS is
    /// longitude-first and CoreLocation is latitude-first — the classic swap bug.
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Artist name that is always safe to show in the UI.
    var artistText: String {
        uploadedBy?.isEmpty == false ? uploadedBy! : "Unknown artist"
    }

    /// Human-friendly distance like "80 m away" or "3.4 km away".
    var distanceText: String {
        if distanceMeters < 1_000 {
            return "\(Int(distanceMeters)) m away"
        }
        return String(format: "%.1f km away", distanceMeters / 1_000)
    }
}
