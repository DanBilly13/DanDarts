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
import UIKit

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
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()

                ContentView()
                    .environmentObject(authService)
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                        guard let url = activity.webpageURL else { return }

                        guard url.host == "www.dartfreak.com" || url.host == "dartfreak.com" else { return }

                        if url.path == "/invite" || url.path == "/invite/" {
                            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            let queryItems = components?.queryItems ?? []
                            let token = queryItems.first(where: { $0.name == "token" })?.value
                                ?? queryItems.first(where: { $0.name == "code" })?.value

                            if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                PendingInviteStore.shared.setToken(token)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("InviteLinkReceived"),
                                    object: nil
                                )
                            }
                        }
                    }
                    .onOpenURL { url in
                        // Handle OAuth redirect URLs
                        if url.scheme == "dartfreak" && url.host == "auth" {
                            // Supabase SDK will automatically handle the OAuth callback
                            // The session will be established and AuthService will be notified
                            Task {
                                await authService.checkSession()
                            }
                            return
                        }
                        
                        // Handle password reset deep link
                        if url.scheme == "dandarts" && url.host == "reset-password" {
                            // Extract tokens from URL fragment
                            if let fragment = url.fragment {
                                // Supabase sends: #access_token=...&refresh_token=...&type=recovery
                                let components = URLComponents(string: "?" + fragment)
                                
                                if let accessToken = components?.queryItems?.first(where: { $0.name == "access_token" })?.value,
                                   let refreshToken = components?.queryItems?.first(where: { $0.name == "refresh_token" })?.value {
                                    
                                    Task {
                                        do {
                                            // Set the session with the tokens
                                            try await authService.setPasswordResetSession(
                                                accessToken: accessToken,
                                                refreshToken: refreshToken
                                            )
                                            
                                            // Mark as recovery mode to show password change screen
                                            await MainActor.run {
                                                authService.isInRecoveryMode = true
                                            }
                                            
                                        } catch {
                                            print("❌ Failed to set session from reset link: \(error)")
                                        }
                                    }
                                }
                            }
                            return
                        }

                        // Handle universal links that arrive via onOpenURL
                        if url.scheme == "https",
                           (url.host == "www.dartfreak.com" || url.host == "dartfreak.com"),
                           (url.path == "/invite" || url.path == "/invite/") {
                            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            let queryItems = components?.queryItems ?? []
                            let token = queryItems.first(where: { $0.name == "token" })?.value
                                ?? queryItems.first(where: { $0.name == "code" })?.value

                            if let token, !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                PendingInviteStore.shared.setToken(token)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("InviteLinkReceived"),
                                    object: nil
                                )
                            }

                            return
                        }

                        // Handle invite links: dandarts://invite?token=...
                        if url.scheme == "dandarts" && url.host == "invite" {
                            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                               let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
                               !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                PendingInviteStore.shared.setToken(token)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("InviteLinkReceived"),
                                    object: nil
                                )
                            }
                        }
                    }
            }
        }
    }
}
