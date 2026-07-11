//
//  LocationProvider.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Combine
import CoreLocation
import Foundation

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    /// Configures Core Location and begins publishing permission and location changes.
    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = AppTuning.Location.desiredAccuracy
    }

    /// Requests permission when needed, then asks Core Location for one current position fix.
    func requestCurrentLocation() {
        errorMessage = nil

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location permission is required to discover and drop songs."
        @unknown default:
            errorMessage = "Location permission is unavailable."
        }
    }

    /// Responds to permission changes and requests a location as soon as access is granted.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    /// Publishes the newest location returned by Core Location.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    /// Converts a Core Location failure into a message the UI can display.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        errorMessage = error.localizedDescription
    }
}
