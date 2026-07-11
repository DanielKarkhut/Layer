//
//  SupabaseConfig.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Foundation
import Supabase

/// The single connection to our Supabase project. Everything that touches the
/// server (auth, RPCs, Storage) goes through `LayerSupabase.client`.
/// The publishable key is safe to ship in the app — row-level security and
/// SECURITY DEFINER functions decide what it may actually do. A secret /
/// service_role key must NEVER appear here.
enum LayerSupabase {
    nonisolated static let urlString = "https://fccorlnfoegipybtrdfq.supabase.co"
    nonisolated static let publishableKey = "sb_publishable_cDVGB2-0MobqybJtbkv4Ag_13dpr7M9"

    /// False when the placeholders above haven't been filled in yet — the app
    /// then shows a "Supabase Not Configured" screen instead of crashing.
    nonisolated static var isConfigured: Bool {
        !urlString.contains("YOUR-PROJECT-REF")
            && !publishableKey.contains("YOUR-SUPABASE")
            && URL(string: urlString) != nil
    }

    nonisolated static let client = SupabaseClient(
        supabaseURL: URL(string: urlString)!,
        supabaseKey: publishableKey
    )
}
