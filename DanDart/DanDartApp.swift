//
//  DanDartApp.swift
//  DanDart
//
//  Created by Billingham Daniel on 2025-10-10.
//

import SwiftUI

@main
struct DanDartApp: App {
    @StateObject private var authService = AuthService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onOpenURL { url in
                    // Handle OAuth redirect URLs
                    if url.scheme == "dandart" && url.host == "auth" {
                        // Supabase SDK will automatically handle the OAuth callback
                        // The session will be established and AuthService will be notified
                        Task {
                            await authService.checkSession()
                        }
                    }
                }
        }
    }
}
