//
//  AppTuning.swift
//  Layer
//
//  Change these values to experiment with Layer's user-facing behavior.
//  Names include their units so it is clear what each number controls.
//

import CoreLocation
import Foundation

enum AppTuning {
    enum Map {
        /// The height and width of the map area shown after centering on the user.
        static let initialCameraDistanceMeters: CLLocationDistance = 2_000

        /// Zero asks `songs_near` for every active song. Try 50_000 for a 50 km search.
        static let searchRadiusMeters = 0.0

        /// The visible side length of each square song marker.
        static let songPinSidePoints = 28.0

        /// Rounds the corners of each square song marker.
        static let songPinCornerRadiusPoints = 5.0
    }

    enum Upload {
        static let defaultRadiusMeters = 100.0
        static let minimumRadiusMeters = 25.0
        static let maximumRadiusMeters = 1_000.0
        static let radiusStepMeters = 25.0
        static let maximumFileBytes = 50 * 1_024 * 1_024
        static let defaultExpirationDays = 7.0
    }

    enum Location {
        /// Best accuracy is useful because a song's download radius can be small.
        static let desiredAccuracy = kCLLocationAccuracyBest
    }
}
