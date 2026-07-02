//
//  LayerHomeView.swift
//  Layer
//
//  Created by Codex on 7/2/26.
//

import SwiftUI

struct LayerHomeView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var songPlayer = SongPlayer()

    var body: some View {
        TabView {
            SongMapView(player: songPlayer)
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            LibraryView(player: songPlayer)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            UploadSongView(authViewModel: authViewModel)
                .tabItem {
                    Label("Upload", systemImage: "icloud.and.arrow.up")
                }
        }
    }
}
