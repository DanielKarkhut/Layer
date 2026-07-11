//
//  AuthViewModel.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Combine
import Foundation
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isWorking = false
    @Published var message: String?
    @Published var errorMessage: String?

    private let client: SupabaseClient
    private var authChangesTask: Task<Void, Never>?

    /// Initializes authentication state and starts observing future session changes.
    init(client: SupabaseClient = LayerSupabase.client) {
        self.client = client
        currentUser = client.auth.currentUser
        observeAuthChanges()
    }

    /// Cancels the long-lived authentication observer when this view model is released.
    deinit {
        authChangesTask?.cancel()
    }

    var currentUserID: UUID? {
        currentUser?.id
    }

    /// Creates a Supabase account and optionally stores the artist's display name as metadata.
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

    /// Signs an existing user in with an email address and password.
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

    /// Ends the current Supabase session and clears the local signed-in user.
    func signOut() async {
        await runAuthAction {
            try await client.auth.signOut()
            currentUser = nil
            message = nil
        }
    }

    /// Keeps `currentUser` synchronized with Supabase authentication events.
    private func observeAuthChanges() {
        authChangesTask = Task { [weak self, client] in
            for await change in client.auth.authStateChanges {
                await MainActor.run {
                    self?.currentUser = change.session?.user ?? client.auth.currentUser
                }
            }
        }
    }

    /// Runs an authentication operation while managing loading, success, and error state.
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
