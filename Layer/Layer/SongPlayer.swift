//
//  SongPlayer.swift
//  Layer
//
//  One shared audio player for the whole app. The Map and the Library both
//  talk to the same instance (injected via .environmentObject), so starting a
//  song in one place automatically stops the one playing elsewhere.
//

import AVFoundation
import Combine
import Foundation

final class SongPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    /// ID of the song that's loaded right now (playing OR paused); nil when silent.
    /// Screens compare this against their own song IDs to decorate buttons.
    @Published private(set) var nowPlayingID: UUID?
    /// Title of whatever is playing (or paused) right now; nil when silent.
    @Published private(set) var nowPlayingTitle: String?
    /// True while audio is actually coming out of the speaker.
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    /// Plays audio straight from downloaded bytes (no file needed).
    /// Runs when you tap a song square on the map.
    /// Example: `player.play(data: audioBytes, id: song.id, title: "Hello Song")`
    func play(data: Data, id: UUID, title: String) throws {
        try startPlayback(with: AVAudioPlayer(data: data), id: id, title: title)
    }

    /// Plays a song already saved on disk.
    /// Runs when you tap a row in the Library.
    /// Example: `player.play(fileURL: saved.fileURL, id: saved.songID, title: saved.name)`
    func play(fileURL: URL, id: UUID, title: String) throws {
        try startPlayback(with: AVAudioPlayer(contentsOf: fileURL), id: id, title: title)
    }

    /// Pauses if playing, resumes if paused. Runs when you tap the play/pause button.
    func togglePause() {
        guard let player else { return }

        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    /// Stops playback completely and clears the "now playing" state.
    /// Runs when a song card is dismissed.
    func stop() {
        player?.stop()
        player = nil
        nowPlayingID = nil
        nowPlayingTitle = nil
        isPlaying = false
    }

    /// Shared setup for both `play` variants: route audio properly (so songs
    /// play even with the iPhone's silent switch on) and start from the top.
    private func startPlayback(with newPlayer: AVAudioPlayer, id: UUID, title: String) throws {
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)

        player?.stop()
        player = newPlayer
        newPlayer.delegate = self
        newPlayer.play()

        nowPlayingID = id
        nowPlayingTitle = title
        isPlaying = true
    }

    /// Called by iOS when a song reaches its end, so the UI flips back from
    /// "pause" to "play" on its own. (`nonisolated` because iOS may call this
    /// from a background thread; we hop back to the main thread inside.)
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}
