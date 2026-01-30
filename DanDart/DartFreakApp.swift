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
