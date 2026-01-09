//
//  SplashView.swift
//  Dart Freak
//
//  Splash screen shown during app launch
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var isCheckingSession = true
    @State private var shouldNavigate = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo Icon
            Image(systemName: "target")
                .font(.system(size: 80, weight: .medium))
                .foregroundColor(AppColor.brandPrimary)
            
            // App Logo Text
            Text("DanDarts")
                .font(.system(size: 48, weight: .bold, design: .default))
                .foregroundColor(AppColor.brandPrimary)
            
            Spacer()
            
            // Loading Indicator
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppColor.interactivePrimaryForeground))
                    .scaleEffect(1.2)
                
                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundPrimary)
        .ignoresSafeArea()
        .onAppear {
            Task {
                await checkSessionWithMinimumDelay()
            }
        }
        .fullScreenCover(isPresented: $shouldNavigate) {
            if authService.isAuthenticated {
                // Navigate to main app (Games tab)
                Text("Main App - Games Tab")
                    .font(.largeTitle)
                    .foregroundColor(AppColor.textPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.backgroundPrimary)
            } else {
                // Navigate to welcome screen
                WelcomeView()
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Check session with minimum display time for better UX
    private func checkSessionWithMinimumDelay() async {
        // Start session check and minimum delay concurrently
        async let sessionCheck: Void = authService.checkSession()
        async let minimumDelay: Void = {
            do {
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            } catch {
                // Handle cancellation gracefully
            }
        }()
        
        // Wait for both to complete
        _ = await (sessionCheck, minimumDelay)
        
        // Update UI on main thread
        await MainActor.run {
            isCheckingSession = false
            shouldNavigate = true
        }
    }
}

// MARK: - Preview
#Preview {
    SplashView()
        .environmentObject(AuthService.mockUnauthenticated)
}

// MARK: - Preview with Different States
#Preview("Splash Screen - Loading") {
    SplashView()
        .environmentObject(AuthService.mockLoading)
        .preferredColorScheme(.dark)
}

#Preview("Splash Screen - Authenticated") {
    SplashView()
        .environmentObject(AuthService.mockAuthenticated)
        .preferredColorScheme(.dark)
}
