//
//  ContentView.swift
//  DanDart
//
//  Main app entry point with authentication flow
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // User is authenticated - show main app
                MainTabView()
                    .environmentObject(authService)
            } else {
                // User is not authenticated - show splash/auth flow
                SplashView()
                    .environmentObject(authService)
            }
        }
        .onAppear {
            // Check for existing session on app launch
            Task {
                await authService.checkSession()
            }
        }
    }
}

#Preview {
    ContentView()
}
