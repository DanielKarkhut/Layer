//
//  DownloadedSong.swift
//  Layer
//

import Foundation
import SwiftData

@Model
final class DownloadedSong {
    var remoteSongID: UUID
    var ownerUserID: UUID
    var name: String
    /// A declaration-site default lets SwiftData migrate downloads created before artist was stored.
    var artist: String = "Unknown Artist"
    var localRelativePath: String
    var downloadedAt: Date

    /// Creates the metadata record that points from a remote song to its local audio file.
    init(
        remoteSongID: UUID,
        ownerUserID: UUID,
        name: String,
        artist: String,
        localRelativePath: String,
        downloadedAt: Date = Date()
    ) {
        self.remoteSongID = remoteSongID
        self.ownerUserID = ownerUserID
        self.name = name
        self.artist = artist
        self.localRelativePath = localRelativePath
        self.downloadedAt = downloadedAt
    }
}
