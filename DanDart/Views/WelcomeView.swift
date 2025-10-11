//
//  WelcomeView.swift
//  DanDart
//
//  Welcome screen for unauthenticated users
//

import SwiftUI

struct WelcomeView: View {
    @State private var showingSignIn = false
    @State private var showingSignUp = false
    @State private var navigateToGames = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top section with logo and tagline
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Logo Icon
                    Image(systemName: "target")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                    
                    // App Logo Text
                    Text("DanDarts")
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundColor(Color("TextPrimary"))
                    
                    // Tagline
                    Text("Focus on the fun, not the math")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .frame(height: geometry.size.height * 0.6)
                
                // Bottom section with buttons
                VStack(spacing: 16) {
                    // Sign In Button
                    Button(action: {
                        showingSignIn = true
                    }) {
                        Text("Sign In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color("AccentPrimary"), Color("AccentPrimary").opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Sign Up Button
                    Button(action: {
                        showingSignUp = true
                    }) {
                        Text("Sign Up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color("AccentSecondary"), Color("AccentSecondary").opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Continue as Guest Button
                    Button(action: {
                        navigateToGames = true
                    }) {
                        Text("Continue as Guest")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 32))
                .frame(height: geometry.size.height * 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BackgroundPrimary"))
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
                    .foregroundColor(Color("TextPrimary"))
                
                Text("MainTabView will be implemented in Phase 5")
                    .font(.body)
                    .foregroundColor(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("Back to Welcome") {
                    navigateToGames = false
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color("AccentPrimary"))
                .cornerRadius(25)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("BackgroundPrimary"))
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
