//
//  MapSong.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import CoreLocation
import Foundation

struct MapSong: Identifiable, Decodable {
    let id: UUID
    let name: String
    let uploadedBy: String
    let latitude: Double
    let longitude: Double
    let radiusMeters: Int
    let distanceMeters: Double
    let inRange: Bool
    let expiresAt: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uploadedBy = "uploaded_by"
        case latitude = "lat"
        case longitude = "lng"
        case radiusMeters = "radius_m"
        case distanceMeters = "distance_m"
        case inRange = "in_range"
        case expiresAt = "expires_at"
    }
}
