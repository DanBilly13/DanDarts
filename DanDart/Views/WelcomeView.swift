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
    @State private var pendingSheetSwap: SheetSwap?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top section with logo and tagline
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Logo
                    Image("DartFreakLogo02")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240)
                    
                    // Tagline
                    Text("Focus on the fun, not the math")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    /*Spacer()*/
                }
                /*.frame(height: geometry.size.height * 0.6)*/
                
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
                }
                .padding(.horizontal, 64)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 32))
                .frame(height: geometry.size.height * 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.backgroundPrimary)
        .ignoresSafeArea()
        .sheet(isPresented: $showingSignIn) {
            SignInView(onSwitchToSignUp: {
                showingSignIn = false
                pendingSheetSwap = .toSignUp
            })
            .modernSheet(title: "Sign In", detents: [.large], background: AppColor.surfacePrimary)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView(onSwitchToSignIn: {
                showingSignUp = false
                pendingSheetSwap = .toSignIn
            })
            .modernSheet(title: "Sign Up", detents: [.large], background: AppColor.surfacePrimary)
        }
        .onChange(of: showingSignIn) { _, isShowing in
            if !isShowing, pendingSheetSwap == .toSignUp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingSignUp = true
                    pendingSheetSwap = nil
                }
            }
        }
        .onChange(of: showingSignUp) { _, isShowing in
            if !isShowing, pendingSheetSwap == .toSignIn {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingSignIn = true
                    pendingSheetSwap = nil
                }
            }
        }
    }
}

// MARK: - Sheet Swap Enum
private enum SheetSwap {
    case toSignIn
    case toSignUp
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
