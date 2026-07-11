//
//  MapScreenViewModel.swift
//  Layer
//
//  The map screen's brain. Views stay dumb; every decision — what to fetch,
//  when playing is allowed, what error to show — happens here.
//

import Combine
import CoreLocation
import Foundation
import SwiftData

@MainActor
final class MapScreenViewModel: ObservableObject {
    /// All songs the database returned for the last refresh, nearest first.
    @Published private(set) var songs: [Song] = []
    /// The song whose card is open at the bottom of the map (nil = no card).
    @Published var selectedSong: Song?
    /// True while the songs_near request is in flight (drives the top chip).
    @Published private(set) var isLoadingSongs = false
    /// True while audio bytes are downloading (drives the card's spinner).
    @Published private(set) var isFetchingAudio = false
    /// Human-readable problem to show on the card; nil when all is well.
    @Published var errorMessage: String?

    private let service: SongMapService

    /// Audio we already fetched this session, keyed by song ID — so playing a
    /// song and then downloading it costs ONE network trip, not two.
    private var audioCache: [UUID: FetchedAudio] = [:]

    struct FetchedAudio {
        let data: Data
        /// "mp3", "m4a", … taken from the storage path; used to name the saved file.
        let fileExtension: String
    }

    init(service: SongMapService = SongMapService()) {
        self.service = service
    }

    /// Fetches every song around the user and refreshes the pins.
    /// Runs when the map opens, when the location first resolves, and on ↻.
    func loadSongs(around location: CLLocation?) async {
        guard let coordinate = location?.coordinate, !isLoadingSongs else { return }

        isLoadingSongs = true
        errorMessage = nil

        do {
            songs = try await service.fetchSongs(around: coordinate)

            // Distances/in-range flags just changed; update the open card too.
            if let selected = selectedSong {
                selectedSong = songs.first { $0.id == selected.id }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingSongs = false
    }

    /// Opens a song's card, and auto-plays it when allowed (tunable via
    /// `LayerConfig.Map.autoPlayOnTap`). Runs when a map square is tapped.
    func select(
        _ song: Song,
        localCopy: DownloadedSong?,
        userLocation: CLLocation?,
        player: SongPlayer
    ) async {
        selectedSong = song
        errorMessage = nil

        let allowedToPlay = song.inRange || localCopy != nil
        guard LayerConfig.Map.autoPlayOnTap, allowedToPlay else { return }

        await playOrPause(song, localCopy: localCopy, userLocation: userLocation, player: player)
    }

    /// Plays a song — or pauses/resumes it if it's already the one playing.
    /// Prefers the copy saved on this device (instant + offline); otherwise
    /// asks the server for access and downloads the bytes.
    /// Example: tap "Hello Song" in range → server check → fetch → music.
    func playOrPause(
        _ song: Song,
        localCopy: DownloadedSong?,
        userLocation: CLLocation?,
        player: SongPlayer
    ) async {
        // Second tap on the song that's already loaded = pause/resume.
        if player.nowPlayingID == song.id {
            player.togglePause()
            return
        }

        errorMessage = nil

        do {
            if let localCopy {
                try player.play(fileURL: localCopy.fileURL, id: song.id, title: song.name)
            } else {
                let audio = try await fetchAudio(for: song, userLocation: userLocation)
                try player.play(data: audio.data, id: song.id, title: song.name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves the selected song permanently: audio file to disk, metadata into
    /// the SwiftData library. Runs when the card's Download button is tapped.
    func download(
        _ song: Song,
        userLocation: CLLocation?,
        modelContext: ModelContext
    ) async {
        errorMessage = nil

        do {
            let audio = try await fetchAudio(for: song, userLocation: userLocation)
            let fileName = "\(song.id.uuidString.lowercased()).\(audio.fileExtension)"
            _ = try SongFileStore.save(audio.data, fileName: fileName)

            modelContext.insert(
                DownloadedSong(
                    songID: song.id,
                    name: song.name,
                    artist: song.artistText,
                    fileName: fileName
                )
            )
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// The one place audio bytes come from: session cache first, otherwise
    /// the `song-access` Edge Function (which re-checks login + distance
    /// server-side and hands back a 5-minute signed download URL).
    private func fetchAudio(for song: Song, userLocation: CLLocation?) async throws -> FetchedAudio {
        if let cached = audioCache[song.id] {
            return cached
        }

        guard let coordinate = userLocation?.coordinate else {
            throw SongAccessError.waitingForLocation
        }

        isFetchingAudio = true
        defer { isFetchingAudio = false }

        let fetched = try await service.fetchAudio(
            songID: song.id,
            songName: song.name,
            at: coordinate
        )

        let audio = FetchedAudio(data: fetched.data, fileExtension: fetched.fileExtension)
        audioCache[song.id] = audio
        return audio
    }
}
