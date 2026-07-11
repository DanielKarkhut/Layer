//
//  LocationProvider.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Combine
import CoreLocation
import Foundation

/// The app's single window into "where is the user?". One shared instance is
/// injected into the Map and Drop tabs — publishes `currentLocation` whenever
/// iOS answers a request.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// Asks iOS for one location fix (asking permission first if needed).
    /// The answer arrives later via `didUpdateLocations` below — watch
    /// `currentLocation` with `.onChange` to react, like MapScreen does.
    /// Runs when the map opens, on ↻, and before an upload.
    func requestCurrentLocation() {
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location permission is required to drop a song."
        @unknown default:
            errorMessage = "Location permission is unavailable."
        }
    }

    /// Called by iOS when the user answers the permission popup — if they
    /// said yes, immediately fetch the location they originally asked for.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    /// Called by iOS when a location fix arrives; publishing it here is what
    /// triggers the map to zoom in and load songs.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    /// Called by iOS when it couldn't get a fix (no GPS, simulator with no
    /// simulated location set, …); the message shows up in the UI.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        errorMessage = error.localizedDescription
    }
}
