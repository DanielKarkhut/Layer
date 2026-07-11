//
//  MapScreen.swift
//  Layer
//
//  The main discovery view: a map centered on you, with one square per song.
//  Tap a square → a card slides up from the bottom with play + download.
//  All the sizes/colors/behaviors here are tunable in LayerConfig.swift.
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct MapScreen: View {
    @EnvironmentObject private var locationProvider: LocationProvider
    @EnvironmentObject private var player: SongPlayer
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel = MapScreenViewModel()

    /// Live list of everything already saved to this device, so squares/cards
    /// can show "In Library ✓" and play saved songs without the network.
    @Query private var downloadedSongs: [DownloadedSong]

    /// Where the map camera points. Starts following the user's blue dot;
    /// we zoom in once (see below) when the first real location arrives.
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasZoomedToUser = false

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                // The user's blue location dot.
                UserAnnotation()

                // One square per song, at the coordinate it was dropped.
                ForEach(viewModel.songs) { song in
                    Annotation(song.name, coordinate: song.coordinate) {
                        SongSquare(
                            song: song,
                            isSelected: viewModel.selectedSong?.id == song.id,
                            isDownloaded: downloadedSong(for: song) != nil
                        )
                        .onTapGesture {
                            Task { await select(song) }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // The song card appears only while a square is selected.
                if let song = viewModel.selectedSong {
                    SongCard(
                        song: song,
                        downloaded: downloadedSong(for: song) != nil,
                        isBusy: viewModel.isFetchingAudio,
                        errorMessage: viewModel.errorMessage,
                        isThisSongPlaying: player.nowPlayingID == song.id && player.isPlaying,
                        onPlayPause: { Task { await playOrPause(song) } },
                        onDownload: { Task { await download(song) } },
                        onDismiss: { dismissCard() }
                    )
                }
            }
            .overlay(alignment: .top) {
                statusChip
            }
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refresh()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                refresh()
            }
            .onChange(of: locationProvider.currentLocation) { _, newLocation in
                zoomToUserOnce(newLocation)
                Task { await viewModel.loadSongs(around: newLocation) }
            }
        }
    }

    /// Small floating banner at the top of the map: progress while songs load,
    /// or the location error if iOS won't give us a position.
    @ViewBuilder
    private var statusChip: some View {
        if viewModel.isLoadingSongs {
            ProgressView("Finding songs…")
                .padding(8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
        } else if let locationError = locationProvider.errorMessage {
            Text(locationError)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 4)
        }
    }

    /// Finds this song in the local library, if the user already downloaded it.
    private func downloadedSong(for song: Song) -> DownloadedSong? {
        downloadedSongs.first { $0.songID == song.id }
    }

    /// Re-asks iOS for the current location; new songs load automatically when
    /// it arrives (see .onChange above). Runs on screen open and the ↻ button.
    private func refresh() {
        locationProvider.requestCurrentLocation()

        if let location = locationProvider.currentLocation {
            Task { await viewModel.loadSongs(around: location) }
        }
    }

    /// Zooms the camera to street level the FIRST time we learn where you are,
    /// then stops steering so your pinches and pans win.
    private func zoomToUserOnce(_ location: CLLocation?) {
        guard !hasZoomedToUser, let location else { return }

        hasZoomedToUser = true
        withAnimation {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: location.coordinate,
                    distance: LayerConfig.Map.initialZoomMeters
                )
            )
        }
    }

    /// Runs when a song square is tapped: opens its card and (if allowed)
    /// starts playing right away.
    private func select(_ song: Song) async {
        await viewModel.select(
            song,
            localCopy: downloadedSong(for: song),
            userLocation: locationProvider.currentLocation,
            player: player
        )
    }

    /// Runs when the card's play/pause button is tapped.
    private func playOrPause(_ song: Song) async {
        await viewModel.playOrPause(
            song,
            localCopy: downloadedSong(for: song),
            userLocation: locationProvider.currentLocation,
            player: player
        )
    }

    /// Runs when the card's Download button is tapped: saves the audio file to
    /// disk and records it in the on-device library.
    private func download(_ song: Song) async {
        await viewModel.download(
            song,
            userLocation: locationProvider.currentLocation,
            modelContext: modelContext
        )
    }

    /// Closes the song card and stops any preview that was playing.
    private func dismissCard() {
        viewModel.selectedSong = nil
        player.stop()
    }
}

// MARK: - The square drawn on the map for one song

private struct SongSquare: View {
    let song: Song
    let isSelected: Bool
    let isDownloaded: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: LayerConfig.Map.songSquareCornerRadius)
            .fill(squareColor)
            .frame(
                width: LayerConfig.Map.songSquareSize,
                height: LayerConfig.Map.songSquareSize
            )
            .overlay(
                RoundedRectangle(cornerRadius: LayerConfig.Map.songSquareCornerRadius)
                    .strokeBorder(.white, lineWidth: 2)
            )
            .overlay(
                Image(systemName: isDownloaded ? "checkmark" : "music.note")
                    .font(.system(size: LayerConfig.Map.songSquareSize * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            )
            .scaleEffect(isSelected ? LayerConfig.Map.selectedSquareScale : 1)
            .shadow(radius: 2)
            .animation(.spring(duration: 0.25), value: isSelected)
    }

    /// Green when you can grab the song here, gray when you're too far away.
    private var squareColor: Color {
        song.inRange ? LayerConfig.Map.inRangeColor : LayerConfig.Map.outOfRangeColor
    }
}

// MARK: - The bottom card shown for the selected song

private struct SongCard: View {
    let song: Song
    let downloaded: Bool
    let isBusy: Bool
    let errorMessage: String?
    let isThisSongPlaying: Bool
    let onPlayPause: () -> Void
    let onDownload: () -> Void
    let onDismiss: () -> Void

    /// Play/Download are allowed when the server says you're in range, or when
    /// you already own a local copy (then distance no longer matters).
    private var canUseSong: Bool {
        song.inRange || downloaded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.name)
                        .font(.headline)
                    Text(song.artistText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(song.distanceText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }

            if canUseSong {
                HStack(spacing: 12) {
                    Button(action: onPlayPause) {
                        Label(
                            isThisSongPlaying ? "Pause" : "Play",
                            systemImage: isThisSongPlaying ? "pause.fill" : "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onDownload) {
                        Label(
                            downloaded ? "In Library" : "Download",
                            systemImage: downloaded ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(downloaded)
                }
                .disabled(isBusy)
            } else {
                // Too far away: explain instead of showing dead buttons.
                Label(
                    "Walk closer to unlock — this song reaches \(song.radiusMeters) m from its drop point.",
                    systemImage: "figure.walk"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            if isBusy {
                ProgressView("Fetching audio…")
                    .font(.footnote)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}
