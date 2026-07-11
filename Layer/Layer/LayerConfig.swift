//
//  LayerConfig.swift
//  Layer
//
//  Every "magic number" in the app lives here so you can tweak one value,
//  rebuild, and immediately see what it controls. Nothing in this file has
//  logic — it is purely knobs.
//

import SwiftUI

enum LayerConfig {
    /// Knobs for the map screen (pins, search, camera).
    enum Map {
        /// controls: how far around the user we ask the database for songs, in meters.
        /// 20,000,000 m ≈ half the planet's circumference, i.e. "every song in the DB".
        /// Try 5_000 to only see songs within 5 km of your (simulated) location.
        static let searchRadiusMeters: Double = 20_000_000

        /// controls: how zoomed-in the camera is once we know your location, in meters
        /// of "camera height". Smaller = closer to the street. Try 300 or 50_000.
        static let initialZoomMeters: Double = 1_500

        /// controls: the width/height of each song square on the map, in points.
        static let songSquareSize: CGFloat = 22

        /// controls: how rounded the song squares' corners are. 0 = sharp square.
        static let songSquareCornerRadius: CGFloat = 4

        /// controls: square color for songs you are close enough to play/download.
        static let inRangeColor: Color = .green

        /// controls: square color for songs that are too far away right now.
        static let outOfRangeColor: Color = .gray

        /// controls: how much bigger the currently selected square grows (1.0 = no change).
        static let selectedSquareScale: CGFloat = 1.35

        /// controls: whether tapping an in-range square starts playing immediately,
        /// or just opens the song card and waits for you to press Play.
        static let autoPlayOnTap = true
    }

    /// Knobs for downloaded songs kept on this device.
    enum Library {
        /// controls: the folder name (inside the app's private Application Support
        /// directory) where downloaded audio files are stored.
        static let audioFolderName = "Songs"
    }
}
