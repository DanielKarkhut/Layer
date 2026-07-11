//
//  LibraryView.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @ObservedObject var player: SongPlayer
    @Query(sort: \DownloadedSong.downloadedAt, order: .reverse) private var songs: [DownloadedSong]
    @State private var errorMessage: String?

    private let fileStore = SongFileStore()

    var body: some View {
        NavigationStack {
            List {
                if songs.isEmpty {
                    ContentUnavailableView("No Downloads", systemImage: "music.note.list")
                } else {
                    ForEach(songs) { song in
                        Button {
                            play(song)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle")
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.name)
                                        .font(.headline)
                                    Text(song.uploadedBy)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Library")
            .safeAreaInset(edge: .bottom) {
                PlayerBar(player: player)
            }
        }
    }

    private func play(_ song: DownloadedSong) {
        do {
            let url = try fileStore.fileURL(for: song)
            player.play(url: url, title: song.name)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
