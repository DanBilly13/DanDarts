//
//  DartFreakApp.swift
//  Dart Freak
//
//  Created by Billingham Daniel on 2025-10-10.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics
import FirebasePerformance

@main
struct DartFreakApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Enable Analytics collection
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Enable Crashlytics
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onOpenURL { url in
                    // Handle OAuth redirect URLs
                    if url.scheme == "dartfreak" && url.host == "auth" {
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
