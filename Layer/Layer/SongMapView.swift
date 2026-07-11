//
//  SongMapView.swift
//  Layer
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct SongMapView: View {
    let userID: UUID
    @ObservedObject var audioPlayer: AudioPlayerViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DownloadedSong.downloadedAt, order: .reverse)
    private var allDownloadedSongs: [DownloadedSong]

    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var discoveryViewModel = SongDiscoveryViewModel()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentLocation: CLLocation?
    @State private var hasCenteredOnUser = false
    @State private var selectedSong: RemoteSong?
    @State private var isRequestingAccess = false
    @State private var isDownloading = false
    @State private var actionErrorMessage: String?

    private let accessService = SongAccessService()
    private let downloadStore = SongDownloadStore()

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(discoveryViewModel.songs) { song in
                    Annotation(song.name, coordinate: song.coordinate) {
                        songPin(for: song)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .overlay(alignment: .top) {
                mapStatusOverlay
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recenterAndRefresh()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                    .accessibilityLabel("Recenter on My Location")
                }
            }
            .sheet(item: $selectedSong) { song in
                songDetails(for: song)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                locationProvider.requestCurrentLocation()
            }
            .onReceive(locationProvider.$currentLocation) { location in
                guard let location else { return }
                currentLocation = location

                if !hasCenteredOnUser {
                    centerMap(on: location.coordinate)
                    hasCenteredOnUser = true
                }

                Task {
                    await discoveryViewModel.loadSongs(near: location.coordinate)
                }
            }
        }
    }

    /// Builds an accessible square map button whose appearance reflects the song's state.
    private func songPin(for song: RemoteSong) -> some View {
        let isDownloaded = downloadedSong(for: song.id) != nil

        return Button {
            selectedSong = song
            actionErrorMessage = nil

            Task {
                await play(song)
            }
        } label: {
            RoundedRectangle(cornerRadius: AppTuning.Map.songPinCornerRadiusPoints)
                .fill(pinColor(isDownloaded: isDownloaded, isInRange: song.isInRange))
                .frame(
                    width: AppTuning.Map.songPinSidePoints,
                    height: AppTuning.Map.songPinSidePoints
                )
                .overlay {
                    Image(systemName: pinSymbol(isDownloaded: isDownloaded, isInRange: song.isInRange))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                }
                .shadow(radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(song.name) by \(song.uploadedBy)")
        .accessibilityHint(song.isInRange || isDownloaded ? "Plays the song" : "Shows how close you need to get")
    }

    @ViewBuilder
    private var mapStatusOverlay: some View {
        VStack(spacing: 8) {
            if discoveryViewModel.isLoading {
                Label("Finding songs…", systemImage: "magnifyingglass")
                    .statusCapsule()
            }

            if let errorMessage = locationProvider.errorMessage ?? discoveryViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .statusCapsule()
            }
        }
        .padding(.top, 8)
        .padding(.horizontal)
    }

    /// Builds the detail sheet containing distance, playback, lock, and download controls.
    private func songDetails(for song: RemoteSong) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.name)
                        .font(.title2.weight(.bold))
                    Text(song.uploadedBy)
                        .foregroundStyle(.secondary)
                    Text(song.distanceDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if downloadedSong(for: song.id) != nil {
                    Label("Saved to your library", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if !song.isInRange {
                    Label(
                        "Move within \(song.radiusMeters) m to unlock this song.",
                        systemImage: "lock.fill"
                    )
                    .foregroundStyle(.secondary)
                }

                if let actionErrorMessage {
                    Text(actionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    if audioPlayer.currentSongID == song.id {
                        audioPlayer.togglePlayback()
                    } else {
                        Task {
                            await play(song)
                        }
                    }
                } label: {
                    Label(
                        audioPlayer.currentSongID == song.id && audioPlayer.isPlaying ? "Pause" : "Play",
                        systemImage: audioPlayer.currentSongID == song.id && audioPlayer.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingAccess || (!song.isInRange && downloadedSong(for: song.id) == nil))

                Button {
                    Task {
                        await download(song)
                    }
                } label: {
                    if isDownloading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Download", systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    isDownloading
                        || !song.isInRange
                        || downloadedSong(for: song.id) != nil
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Song")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Plays a local download when available or requests authorized remote playback in range.
    private func play(_ song: RemoteSong) async {
        actionErrorMessage = nil

        if let downloadedSong = downloadedSong(for: song.id) {
            do {
                let localURL = try downloadStore.localURL(for: downloadedSong.localRelativePath)
                guard FileManager.default.fileExists(atPath: localURL.path) else {
                    throw CocoaError(.fileNoSuchFile)
                }

                audioPlayer.play(
                    songID: song.id,
                    title: song.name,
                    artist: song.uploadedBy,
                    url: localURL
                )
            } catch {
                actionErrorMessage = "The downloaded file is missing. Remove it from Library and download it again."
            }
            return
        }

        guard song.isInRange else {
            actionErrorMessage = "Move within \(song.radiusMeters) m to listen."
            return
        }

        guard let coordinate = currentLocation?.coordinate else {
            actionErrorMessage = "Your current location is not available yet."
            return
        }

        isRequestingAccess = true
        defer { isRequestingAccess = false }

        do {
            let access = try await accessService.requestAccess(to: song.id, from: coordinate)
            audioPlayer.play(
                songID: song.id,
                title: access.name,
                artist: access.uploadedBy,
                url: access.signedURL
            )
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    /// Requests a fresh signed URL and permanently saves the selected song on this device.
    private func download(_ song: RemoteSong) async {
        guard let coordinate = currentLocation?.coordinate else {
            actionErrorMessage = "Your current location is not available yet."
            return
        }

        isDownloading = true
        actionErrorMessage = nil
        defer { isDownloading = false }

        do {
            let access = try await accessService.requestAccess(to: song.id, from: coordinate)
            try await downloadStore.download(
                song: song,
                from: access.signedURL,
                ownerUserID: userID,
                modelContext: modelContext
            )
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    /// Finds the current user's local library record for a remote song, if one exists.
    private func downloadedSong(for remoteSongID: UUID) -> DownloadedSong? {
        allDownloadedSongs.first {
            $0.remoteSongID == remoteSongID && $0.ownerUserID == userID
        }
    }

    /// Recenters on the last known location and refreshes pins, or requests a location first.
    private func recenterAndRefresh() {
        if let currentLocation {
            centerMap(on: currentLocation.coordinate)
            Task {
                await discoveryViewModel.loadSongs(near: currentLocation.coordinate)
            }
        } else {
            locationProvider.requestCurrentLocation()
        }
    }

    /// Moves the map camera to a coordinate using the configurable initial viewing distance.
    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: AppTuning.Map.initialCameraDistanceMeters,
                longitudinalMeters: AppTuning.Map.initialCameraDistanceMeters
            )
        )
    }

    /// Chooses green for downloaded songs, accent color for unlocked songs, and gray for locked songs.
    private func pinColor(isDownloaded: Bool, isInRange: Bool) -> Color {
        if isDownloaded { return .green }
        return isInRange ? .accentColor : .gray
    }

    /// Chooses the checkmark, play, or lock symbol displayed inside a song pin.
    private func pinSymbol(isDownloaded: Bool, isInRange: Bool) -> String {
        if isDownloaded { return "checkmark" }
        return isInRange ? "play.fill" : "lock.fill"
    }
}

private extension View {
    /// Styles short map-status messages as readable material capsules.
    func statusCapsule() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}
