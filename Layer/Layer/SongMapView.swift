//
//  SongMapView.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import CoreLocation
import Combine
import MapKit
import SwiftData
import SwiftUI

struct SongMapView: View {
    @ObservedObject var player: SongPlayer

    @StateObject private var locationProvider = LocationProvider()
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )
    @State private var songs: [MapSong] = []
    @State private var selectedSong: MapSong?
    @State private var isLoading = false
    @State private var message: String?
    @State private var errorMessage: String?

    private let catalogService = SongCatalogService()
    private let accessService = SongAccessService()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(songs) { song in
                        Annotation(song.name, coordinate: song.coordinate) {
                            Button {
                                selectedSong = song
                                Task {
                                    await play(song)
                                }
                            } label: {
                                SongMapSquare(isInRange: song.inRange)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(song.name)
                        }
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(10)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    PlayerBar(player: player)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        locationProvider.requestCurrentLocation()
                    } label: {
                        Image(systemName: "location.fill")
                    }
                    .accessibilityLabel("Use Current Location")

                    Button {
                        Task {
                            await loadSongs()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(locationProvider.currentLocation == nil || isLoading)
                    .accessibilityLabel("Refresh Songs")
                }
            }
            .sheet(item: $selectedSong) { song in
                SongDetailView(
                    song: song,
                    currentLocation: locationProvider.currentLocation,
                    player: player
                )
            }
            .onAppear {
                if let coordinate = locationProvider.currentLocation?.coordinate {
                    centerMap(on: coordinate, animated: false)

                    Task {
                        await loadSongs(near: coordinate)
                    }
                }

                locationProvider.requestCurrentLocation()
            }
            .onReceive(locationProvider.$currentLocation.compactMap { $0 }) { location in
                centerMap(on: location.coordinate)

                Task {
                    await loadSongs(near: location.coordinate)
                }
            }
        }
    }

    @MainActor
    private func loadSongs() async {
        guard let coordinate = locationProvider.currentLocation?.coordinate else {
            errorMessage = "Current location is needed before loading songs."
            return
        }

        await loadSongs(near: coordinate)
    }

    @MainActor
    private func loadSongs(near coordinate: CLLocationCoordinate2D) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            songs = try await catalogService.fetchSongs(near: coordinate)
            message = songs.isEmpty ? "No songs found yet." : nil
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    private func play(_ song: MapSong) async {
        guard let coordinate = locationProvider.currentLocation?.coordinate else {
            errorMessage = "Current location is needed before playing songs."
            return
        }

        errorMessage = nil

        do {
            let url = try await accessService.playbackURL(for: song, at: coordinate)
            player.play(url: url, title: song.name)
        } catch {
            errorMessage = error.localizedDescription
        }

    }

    private func centerMap(on coordinate: CLLocationCoordinate2D, animated: Bool = true) {
        let updateCamera = {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: coordinate,
                    distance: 800, // 1_200,
                    heading: 0,
                    pitch: 30
                )
            )
        }

        if animated {
            withAnimation {
                updateCamera()
            }
        } else {
            updateCamera()
        }
    }
}

private struct SongMapSquare: View {
    let isInRange: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isInRange ? Color.green : Color.blue)
            .frame(width: 18, height: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(.white, lineWidth: 2)
            }
            .shadow(radius: 2)
    }
}

private struct SongDetailView: View {
    let song: MapSong
    let currentLocation: CLLocation?
    @ObservedObject var player: SongPlayer

    @Environment(\.modelContext) private var modelContext
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    private let accessService = SongAccessService()
    private let fileStore = SongFileStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("Song") {
                    Text(song.name)
                    Text(song.uploadedBy)
                        .foregroundStyle(.secondary)
                    Text(distanceText)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task {
                            await play()
                        }
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .disabled(isWorking)

                    Button {
                        Task {
                            await download()
                        }
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    .disabled(isWorking)
                }

                if isWorking {
                    ProgressView()
                }

                StatusSection(message: message, errorMessage: errorMessage)
            }
            .navigationTitle("Song")
            .safeAreaInset(edge: .bottom) {
                PlayerBar(player: player)
            }
        }
    }

    private var distanceText: String {
        let formattedDistance = Measurement(
            value: song.distanceMeters,
            unit: UnitLength.meters
        )
        .formatted(.measurement(width: .abbreviated, usage: .asProvided))

        return "\(formattedDistance) away"
    }

    @MainActor
    private func play() async {
        guard let coordinate = currentLocation?.coordinate else {
            errorMessage = "Current location is needed before playing songs."
            return
        }

        isWorking = true
        message = nil
        errorMessage = nil

        do {
            let url = try await accessService.playbackURL(for: song, at: coordinate)
            player.play(url: url, title: song.name)
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    @MainActor
    private func download() async {
        guard let coordinate = currentLocation?.coordinate else {
            errorMessage = "Current location is needed before downloading songs."
            return
        }

        isWorking = true
        message = nil
        errorMessage = nil

        do {
            let url = try await accessService.playbackURL(for: song, at: coordinate)
            let localFilename = try await fileStore.saveRemoteFile(from: url, songID: song.id)
            try upsertDownloadedSong(localFilename: localFilename)
            message = "Downloaded."
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }

    private func upsertDownloadedSong(localFilename: String) throws {
        let descriptor = FetchDescriptor<DownloadedSong>()
        let existingSong = try modelContext.fetch(descriptor).first {
            $0.remoteSongID == song.id
        }

        if let existingSong {
            existingSong.update(from: song, localFilename: localFilename)
        } else {
            modelContext.insert(
                DownloadedSong(
                    remoteSongID: song.id,
                    name: song.name,
                    uploadedBy: song.uploadedBy,
                    localFilename: localFilename,
                    latitude: song.latitude,
                    longitude: song.longitude,
                    radiusMeters: song.radiusMeters
                )
            )
        }

        try modelContext.save()
    }
}
