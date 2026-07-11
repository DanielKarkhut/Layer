//
//  AudioPlayerViewModel.swift
//  Layer
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerViewModel: ObservableObject {
    @Published private(set) var currentSongID: UUID?
    @Published private(set) var currentTitle: String?
    @Published private(set) var currentArtist: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?

    private var player: AVPlayer?
    private var playbackEndedCancellable: AnyCancellable?

    /// Cancels the playback-finished observation when the shared player is released.
    deinit {
        playbackEndedCancellable?.cancel()
    }

    /// Replaces the current item with the supplied local or remote audio URL and starts playback.
    func play(songID: UUID, title: String, artist: String, url: URL) {
        do {
            try configureAudioSession()

            playbackEndedCancellable?.cancel()

            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            currentSongID = songID
            currentTitle = title
            currentArtist = artist
            errorMessage = nil

            playbackEndedCancellable = NotificationCenter.default
                .publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.isPlaying = false
                }

            player?.play()
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
            isPlaying = false
        }
    }

    /// Pauses a playing song or resumes the current paused song.
    func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    /// Stops playback and clears all now-playing state from the shared player.
    func stop() {
        player?.pause()
        player = nil
        currentSongID = nil
        currentTitle = nil
        currentArtist = nil
        isPlaying = false
    }

    /// Configures iOS for media playback, including playback while the silent switch is enabled.
    private func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    }
}
