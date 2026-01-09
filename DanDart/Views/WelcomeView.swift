//
//  WelcomeView.swift
//  Dart Freak
//
//  Welcome screen for unauthenticated users
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingSignIn = false
    @State private var showingSignUp = false
    @State private var navigateToGames = false
    @State private var showMainTabPreview = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top section with logo and tagline
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Logo Icon
                    Image(systemName: "target")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundColor(AppColor.brandPrimary)
                    
                    // App Logo Text (Hidden tap for MainTab preview)
                    Text("DanDarts")
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundColor(AppColor.brandPrimary)
                        .onTapGesture(count: 3) {
                            // Triple tap to show MainTabView preview
                            showMainTabPreview = true
                        }
                    
                    // Tagline
                    Text("Focus on the fun, not the math")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.6)
                
                // Bottom section with buttons
                VStack(spacing: 16) {
                    // Sign In Button
                    AppButton(role: .primary, controlSize: .large) {
                        showingSignIn = true
                    } label: {
                        Text("Sign in")
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Sign Up Button
                    AppButton(role: .secondary, controlSize: .large) {
                        showingSignUp = true
                    } label: {
                        Text("Create a new account")
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Continue as Guest Button
                    Button(action: {
                        showMainTabPreview = true
                    }) {
                        Text("Continue as Guest")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                    
                    // Mock User Button (for testing)
                    Button(action: {
                        authService.setMockUser()
                    }) {
                        Text("Use Mock User (Testing)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.interactivePrimaryForeground)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 32))
                .frame(height: geometry.size.height * 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundPrimary)
        .ignoresSafeArea()
        .sheet(isPresented: $showingSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
        }
        .fullScreenCover(isPresented: $navigateToGames) {
            // Navigate to Games Tab (placeholder until MainTabView is created)
            VStack(spacing: 20) {
                Text("🎯")
                    .font(.system(size: 80))
                
                Text("Games Tab")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("MainTabView will be implemented in Phase 5")
                    .font(.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Back to Welcome") {
                    navigateToGames = false
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(AppColor.interactivePrimaryBackground)
                .cornerRadius(25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
        }
        .fullScreenCover(isPresented: $showMainTabPreview) {
            // Clean MainTabView Preview - no extra UI elements
            MainTabView()
                .environmentObject(AuthService())
        }
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    WelcomeView()
}

#Preview("Welcome Screen - Light") {
    WelcomeView()
        .preferredColorScheme(.light)
}

#Preview("Welcome Screen - Dark") {
    WelcomeView()
        .preferredColorScheme(.dark)
}
