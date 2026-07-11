//
//  LibraryScreen.swift
//  Layer
//
//  Every song the user has permanently downloaded, newest first.
//  Works fully offline: rows play straight from files on disk.
//

import SwiftData
import SwiftUI

struct LibraryScreen: View {
    @EnvironmentObject private var player: SongPlayer
    @Environment(\.modelContext) private var modelContext

    /// Auto-updating list of saved songs — SwiftData re-runs this query and
    /// refreshes the view whenever a song is downloaded or deleted.
    @Query(sort: \DownloadedSong.downloadedAt, order: .reverse)
    private var downloadedSongs: [DownloadedSong]

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if downloadedSongs.isEmpty {
                    ContentUnavailableView(
                        "No Songs Yet",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Find a song on the map and tap Download to keep it here.")
                    )
                } else {
                    songList
                }
            }
            .navigationTitle("Library")
        }
    }

    private var songList: some View {
        List {
            ForEach(downloadedSongs) { song in
                LibraryRow(
                    song: song,
                    isThisSongPlaying: player.nowPlayingID == song.songID && player.isPlaying
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    playOrPause(song)
                }
            }
            .onDelete(perform: delete)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Plays a saved song from disk — or pauses/resumes it if it's already the
    /// one loaded. Runs when a library row is tapped.
    private func playOrPause(_ song: DownloadedSong) {
        errorMessage = nil

        if player.nowPlayingID == song.songID {
            player.togglePause()
            return
        }

        do {
            try player.play(fileURL: song.fileURL, id: song.songID, title: song.name)
        } catch {
            errorMessage = "Couldn't play “\(song.name)”: \(error.localizedDescription)"
        }
    }

    /// Removes swiped songs: the audio file on disk AND the library record.
    /// Runs when the user swipes a row and taps Delete.
    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let song = downloadedSongs[index]

            if player.nowPlayingID == song.songID {
                player.stop()
            }

            SongFileStore.delete(fileName: song.fileName)
            modelContext.delete(song)
        }

        try? modelContext.save()
    }
}

// MARK: - One row in the library list

private struct LibraryRow: View {
    let song: DownloadedSong
    let isThisSongPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isThisSongPlaying ? "speaker.wave.2.fill" : "music.note")
                .font(.title3)
                .foregroundStyle(isThisSongPlaying ? LayerConfig.Map.inRangeColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.headline)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(song.downloadedAt, format: .dateTime.month().day())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
