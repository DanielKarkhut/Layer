//
//  ContentView.swift
//  Layer
//
//  Created by Daniel Karkhut on 6/17/26.
//

import CoreLocation
import SwiftUI
import UniformTypeIdentifiers

/// The app's front door: decides between the config warning, the sign-in
/// screen, and (once signed in) the main tabbed app.
struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if LayerSupabase.isConfigured {
                if authViewModel.currentUser == nil {
                    AuthView(viewModel: authViewModel)
                } else {
                    MainTabView(authViewModel: authViewModel)
                }
            } else {
                SupabaseConfigurationView()
            }
        }
    }
}

/// The three tabs of the signed-in app: find songs (Map), replay what you
/// kept (Library), share your own (Drop).
///
/// The two `@StateObject`s below are created ONCE here and shared with every
/// tab via `.environmentObject`, so all screens agree on one audio player and
/// one location. Example: start a song on the Map, switch to Library, tap a
/// row — the map's song stops because both tabs use the same `SongPlayer`.
private struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel

    @StateObject private var player = SongPlayer()
    @StateObject private var locationProvider = LocationProvider()

    var body: some View {
        TabView {
            MapScreen()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            LibraryScreen()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            UploadSongView(authViewModel: authViewModel)
                .tabItem {
                    Label("Drop", systemImage: "icloud.and.arrow.up")
                }
        }
        .environmentObject(player)
        .environmentObject(locationProvider)
    }
}

/// Sign-in / create-account form shown until `AuthViewModel.currentUser`
/// becomes non-nil.
private struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(isCreatingAccount ? .newPassword : .password)

                    if isCreatingAccount {
                        TextField("Artist name", text: $fullName)
                            .textContentType(.name)
                    }
                }

                Section {
                    Button {
                        Task {
                            if isCreatingAccount {
                                await viewModel.signUp(
                                    email: email,
                                    password: password,
                                    fullName: fullName
                                )
                            } else {
                                await viewModel.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Label(
                            isCreatingAccount ? "Create Account" : "Sign In",
                            systemImage: "person.crop.circle.badge.checkmark"
                        )
                    }
                    .disabled(viewModel.isWorking || email.isEmpty || password.isEmpty)

                    Button {
                        isCreatingAccount.toggle()
                    } label: {
                        Label(
                            isCreatingAccount ? "Use Existing Account" : "Create New Account",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                    .disabled(viewModel.isWorking)
                }

                if viewModel.isWorking {
                    ProgressView()
                }

                StatusSection(message: viewModel.message, errorMessage: viewModel.errorMessage)
            }
            .navigationTitle("Layer")
        }
    }
}

/// The "Drop" tab: pick an audio file, choose a radius/expiry, and upload the
/// song pinned to wherever you're standing.
private struct UploadSongView: View {
    @ObservedObject var authViewModel: AuthViewModel

    // Shared with the Map tab (injected by MainTabView) so both screens use
    // the same location fix.
    @EnvironmentObject private var locationProvider: LocationProvider

    @StateObject private var uploadViewModel = SongUploadViewModel()
    @State private var isShowingFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Song") {
                    TextField("Song name", text: $uploadViewModel.songName)

                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Label(uploadViewModel.selectedFileName, systemImage: "music.note")
                    }
                }

                Section("Drop") {
                    Stepper(
                        "Radius: \(Int(uploadViewModel.radiusMeters)) m",
                        value: $uploadViewModel.radiusMeters,
                        in: 25...1_000,
                        step: 25
                    )

                    Toggle("Expires", isOn: $uploadViewModel.hasExpiration)

                    if uploadViewModel.hasExpiration {
                        DatePicker(
                            "Expires at",
                            selection: $uploadViewModel.expiresAt,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section("Location") {
                    HStack {
                        Label(locationText, systemImage: "location")
                        Spacer()
                        Button {
                            locationProvider.requestCurrentLocation()
                        } label: {
                            Image(systemName: "location.fill")
                        }
                        .accessibilityLabel("Use Current Location")
                    }

                    if let errorMessage = locationProvider.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await uploadViewModel.upload(at: locationProvider.currentLocation)
                        }
                    } label: {
                        if uploadViewModel.isUploading {
                            ProgressView()
                        } else {
                            Label("Upload Song", systemImage: "icloud.and.arrow.up")
                        }
                    }
                    .disabled(!uploadViewModel.canUpload || locationProvider.currentLocation == nil)
                }

                StatusSection(
                    message: uploadViewModel.message,
                    errorMessage: uploadViewModel.errorMessage
                )
            }
            .navigationTitle("Upload Song")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await authViewModel.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.audio]
            ) { result in
                uploadViewModel.handleFileImport(result)
            }
            .onAppear {
                locationProvider.requestCurrentLocation()
            }
        }
    }

    private var locationText: String {
        guard let coordinate = locationProvider.currentLocation?.coordinate else {
            return "No location set"
        }

        return String(
            format: "%.5f, %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }
}

/// Reusable form footer: gray text for progress/success, red for errors.
/// Renders nothing at all when both are nil.
private struct StatusSection: View {
    let message: String?
    let errorMessage: String?

    var body: some View {
        if let message {
            Section {
                Text(message)
                    .foregroundStyle(.secondary)
            }
        }

        if let errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Shown instead of the app when SupabaseConfig.swift still has placeholder
/// values, so a fresh checkout fails loudly and helpfully.
private struct SupabaseConfigurationView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Supabase Not Configured",
                systemImage: "wrench.and.screwdriver",
                description: Text("Set LayerSupabase.urlString and LayerSupabase.publishableKey.")
            )
            .navigationTitle("Layer")
        }
    }
}

#Preview {
    ContentView()
}
