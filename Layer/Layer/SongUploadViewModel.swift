//
//  SongUploadViewModel.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class SongUploadViewModel: ObservableObject {
    @Published var songName = ""
    @Published var radiusMeters = 100.0
    @Published var hasExpiration = false
    @Published var expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @Published private(set) var selectedFileURL: URL?
    @Published private(set) var selectedFileName = "No file selected"
    @Published private(set) var isUploading = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let uploadService: SongUploadService

    init(uploadService: SongUploadService = SongUploadService()) {
        self.uploadService = uploadService
    }

    var canUpload: Bool {
        !songName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedFileURL != nil
            && !isUploading
    }

    func handleFileImport(_ result: Result<URL, any Error>) {
        do {
            let fileURL = try result.get()
            selectedFileURL = fileURL
            selectedFileName = fileURL.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func upload(at location: CLLocation?) async {
        guard !isUploading else { return }

        let trimmedName = songName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Add a song name."
            return
        }

        guard let selectedFileURL else {
            errorMessage = "Choose an audio file."
            return
        }

        guard let coordinate = location?.coordinate else {
            errorMessage = "Set the current location before uploading."
            return
        }

        isUploading = true
        errorMessage = nil
        message = nil

        do {
            let song = try await uploadService.uploadSong(
                name: trimmedName,
                fileURL: selectedFileURL,
                coordinate: coordinate,
                radiusMeters: Int(radiusMeters),
                expiresAt: hasExpiration ? expiresAt : nil
            )

            songName = ""
            self.selectedFileURL = nil
            selectedFileName = "No file selected"
            message = "Uploaded song \(song.id.uuidString)."
        } catch {
            errorMessage = error.localizedDescription
        }

        isUploading = false
    }
}
