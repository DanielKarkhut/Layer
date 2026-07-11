//
//  SongPlayer.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import AVFoundation
import Combine
import SwiftUI

@MainActor
final class SongPlayer: ObservableObject {
    @Published private(set) var currentTitle: String?
    @Published private(set) var isPlaying = false

    private var player: AVPlayer?

    func play(url: URL, title: String) {
        player = AVPlayer(url: url)
        currentTitle = title
        isPlaying = true
        player?.play()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        guard player != nil else { return }

        player?.play()
        isPlaying = true
    }

    func stop() {
        player?.pause()
        player = nil
        currentTitle = nil
        isPlaying = false
    }
}

struct PlayerBar: View {
    @ObservedObject var player: SongPlayer

    var body: some View {
        if let title = player.currentTitle {
            HStack(spacing: 12) {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Button {
                    if player.isPlaying {
                        player.pause()
                    } else {
                        player.resume()
                    }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    player.stop()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }
}
