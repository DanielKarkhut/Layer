//
//  SupabaseConfig.swift
//  Layer
//
//  Created by Codex on 6/25/26.
//

import Foundation
import Supabase

enum LayerSupabase {
    nonisolated static let urlString = "https://fccorlnfoegipybtrdfq.supabase.co"
    nonisolated static let publishableKey = "sb_publishable_cDVGB2-0MobqybJtbkv4Ag_13dpr7M9"

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
