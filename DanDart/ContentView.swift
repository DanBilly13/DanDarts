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
        SplashView()
            .environmentObject(authService)
    }
}

#Preview {
    ContentView()
}
