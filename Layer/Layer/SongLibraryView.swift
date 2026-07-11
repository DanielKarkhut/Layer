//
//  SongLibraryView.swift
//  Layer
//

import SwiftData
import SwiftUI

struct SongLibraryView: View {
    let userID: UUID
    @ObservedObject var audioPlayer: AudioPlayerViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadedSong.downloadedAt, order: .reverse)
    private var allDownloadedSongs: [DownloadedSong]

    @State private var errorMessage: String?

    private let downloadStore = SongDownloadStore()

    private var librarySongs: [DownloadedSong] {
        allDownloadedSongs.filter { $0.ownerUserID == userID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if librarySongs.isEmpty {
                    ContentUnavailableView(
                        "No Downloaded Songs",
                        systemImage: "music.note.list",
                        description: Text("Songs you download from the map appear here and play offline.")
                    )
                } else {
                    List(librarySongs) { song in
                        Button {
                            play(song)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: audioPlayer.currentSongID == song.remoteSongID
                                    ? "speaker.wave.2.fill"
                                    : "music.note")
                                    .foregroundStyle(
                                        audioPlayer.currentSongID == song.remoteSongID
                                            ? Color.accentColor
                                            : Color.secondary
                                    )
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(song.name)
                                        .font(.headline)
                                    Text(song.artist)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "play.circle")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(song)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .alert("Library Error", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    /// Resolves a downloaded song's local file and sends it to the shared audio player.
    private func play(_ song: DownloadedSong) {
        do {
            let localURL = try downloadStore.localURL(for: song.localRelativePath)
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                throw CocoaError(.fileNoSuchFile)
            }

            audioPlayer.play(
                songID: song.remoteSongID,
                title: song.name,
                artist: song.artist,
                url: localURL
            )
        } catch {
            errorMessage = "The audio file is missing. Delete this entry and download the song again."
        }
    }

    /// Stops the song when necessary, then removes its file and SwiftData record.
    private func delete(_ song: DownloadedSong) {
        do {
            if audioPlayer.currentSongID == song.remoteSongID {
                audioPlayer.stop()
            }
            try downloadStore.delete(song, modelContext: modelContext)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
