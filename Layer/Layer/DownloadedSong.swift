//
//  DownloadedSong.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import Foundation
import SwiftData

@Model
final class DownloadedSong {
    @Attribute(.unique) var remoteSongID: UUID
    var name: String
    var uploadedBy: String
    var localFilename: String
    var downloadedAt: Date
    var latitude: Double
    var longitude: Double
    var radiusMeters: Int

    init(
        remoteSongID: UUID,
        name: String,
        uploadedBy: String,
        localFilename: String,
        downloadedAt: Date = Date(),
        latitude: Double,
        longitude: Double,
        radiusMeters: Int
    ) {
        self.remoteSongID = remoteSongID
        self.name = name
        self.uploadedBy = uploadedBy
        self.localFilename = localFilename
        self.downloadedAt = downloadedAt
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }

    func update(from song: MapSong, localFilename: String) {
        self.name = song.name
        uploadedBy = song.uploadedBy
        self.localFilename = localFilename
        downloadedAt = Date()
        latitude = song.latitude
        longitude = song.longitude
        radiusMeters = song.radiusMeters
    }
}
