//
//  MainTabView.swift
//  Layer
//

import SwiftUI

struct MainTabView: View {
    let userID: UUID
    @ObservedObject var authViewModel: AuthViewModel

    @StateObject private var audioPlayer = AudioPlayerViewModel()

    var body: some View {
        TabView {
            SongMapView(userID: userID, audioPlayer: audioPlayer)
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            SongLibraryView(userID: userID, audioPlayer: audioPlayer)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            UploadSongView(authViewModel: authViewModel)
                .tabItem {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if audioPlayer.currentSongID != nil {
                MiniPlayerView(audioPlayer: audioPlayer)
            }
        }
    }
}

private struct MiniPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.currentTitle ?? "Unknown Song")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(audioPlayer.currentArtist ?? "Unknown Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

            Button {
                audioPlayer.stop()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 30, height: 36)
            }
            .accessibilityLabel("Close Player")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
