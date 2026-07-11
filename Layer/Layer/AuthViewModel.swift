//
//  AuthViewModel.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Combine
import Foundation
import Supabase

/// Owns everything about "who is signed in". The rest of the app only reads
/// `currentUser` — when it's nil, ContentView shows the sign-in screen.
@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isWorking = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var authChangesTask: Task<Void, Never>?

    /// Restores any session Supabase saved from a previous launch, so users
    /// don't sign in every time. Runs once when the app starts.
    init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
        currentUser = client.auth.currentUser
        observeAuthChanges()
    }

    deinit {
        authChangesTask?.cancel()
    }

    /// Creates a new Supabase account (this is what fills `auth.users`, and a
    /// database trigger mirrors it into `public.app_users`). Runs when the
    /// "Create Account" button is tapped.
    func signUp(email: String, password: String, fullName: String) async {
        await runAuthAction {
            let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let metadata: [String: AnyJSON]? = trimmedName.isEmpty
                ? nil
                : ["full_name": .string(trimmedName)]

            let response = try await client.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: metadata
            )

            currentUser = response.session?.user ?? response.user
            message = response.session == nil
                ? "Check your email to confirm the account, then sign in."
                : "Account created."
        }
    }

    /// Signs into an existing account. On success `currentUser` flips non-nil
    /// and ContentView switches to the main tabs. Runs on "Sign In".
    func signIn(email: String, password: String) async {
        await runAuthAction {
            let session = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            currentUser = session.user
            message = "Signed in."
        }
    }

    /// Ends the session; ContentView falls back to the sign-in screen.
    /// Runs when the Sign Out toolbar button is tapped on the Drop tab.
    func signOut() async {
        await runAuthAction {
            try await client.auth.signOut()
            currentUser = nil
            message = nil
        }
    }

    /// Listens for Supabase auth events for the app's whole lifetime, so
    /// `currentUser` stays correct even when a session expires or is restored
    /// in the background — no manual refresh needed anywhere else.
    private func observeAuthChanges() {
        authChangesTask = Task { [weak self, client] in
            for await change in client.auth.authStateChanges {
                await MainActor.run {
                    self?.currentUser = change.session?.user ?? client.auth.currentUser
                }
            }
        }
    }

    /// Shared wrapper for every auth call above: blocks double-taps, clears
    /// old status text, shows the spinner, and turns thrown errors into the
    /// red `errorMessage` the form displays.
    private func runAuthAction(_ action: () async throws -> Void) async {
        guard !isWorking else { return }

        isWorking = true
        errorMessage = nil
        message = nil

        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorking = false
    }
}
