//
//  SignInView.swift
//  DanDart
//
//  Sign in screen for user authentication
//

import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // App Logo
                        Image(systemName: "target")
                            .font(.system(size: 60, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                        
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Sign in to your account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.top, 32)
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Email TextField
                        DartTextField(
                            label: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            autocorrectionDisabled: true
                        )
                        .onChange(of: email) { oldValue, newValue in
                            // Fix Swedish keyboard @ symbol issue
                            let correctedEmail = newValue.replacingOccurrences(of: "™", with: "@")
                            if correctedEmail != newValue {
                                email = correctedEmail
                            }
                        }
                        
                        // Password SecureField
                        DartSecureField(
                            label: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            textContentType: .password
                        )
                        
                        // Forgot Password Link
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                // TODO: Implement forgot password
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 32)
                    }
                    
                    // Buttons Section
                    VStack(spacing: 16) {
                        // Sign In Button
                        Button(action: {
                            Task {
                                await signIn()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Signing In..." : "Sign In")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
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
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isLoading)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color("TextSecondary").opacity(0.3))
                            
                            Text("or")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color("TextSecondary").opacity(0.3))
                        }
                        
                        // Sign in with Google Button
                        Button(action: {
                            Task {
                                await signInWithGoogle()
                            }
                        }) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("TextPrimary")))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "globe")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text(isLoading ? "Signing in with Google..." : "Sign in with Google")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(Color("TextPrimary"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color("BackgroundSecondary"))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 32)
                    
                    // Bottom Links
                    VStack(spacing: 16) {
                        // Sign Up Link
                        HStack {
                            Text("Don't have an account?")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            Button("Sign Up") {
                                // TODO: Navigate to sign up
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                        }
                        
                        // Continue as Guest Link
                        Button("Continue as Guest") {
                            // TODO: Navigate to main app as guest
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("BackgroundPrimary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Sign in with email and password
    private func signIn() async {
        // Clear previous error
        errorMessage = ""
        
        // Validate input
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        guard !password.isEmpty else {
            errorMessage = "Please enter your password"
            return
        }
        
        // Set loading state
        isLoading = true
        
        do {
            // Call AuthService sign in
            try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            
            // Success - dismiss the sheet
            dismiss()
            
        } catch {
            // Handle sign in error
            if let authError = error as? AuthError {
                errorMessage = authError.localizedDescription
            } else {
                errorMessage = "Sign in failed. Please try again."
            }
        }
        
        // Reset loading state
        isLoading = false
    }
    
    /// Sign in with Google OAuth
    private func signInWithGoogle() async {
        // Clear previous error
        errorMessage = ""
        
        // Set loading state
        isLoading = true
        
        do {
            // Call AuthService Google OAuth
            let isNewUser = try await authService.signInWithGoogle()
            
            // Dismiss SignInView
            // If new user: ContentView will show ProfileSetupView
            // If existing user: ContentView will show MainTabView
            dismiss()
            
        } catch let error as AuthError {
            // Handle specific OAuth errors
            switch error {
            case .oauthCancelled:
                // Don't show error for cancelled OAuth
                break
            case .oauthFailed:
                errorMessage = "Google sign in failed. Please try again"
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again"
            default:
                errorMessage = "Failed to sign in with Google. Please try again"
            }
        } catch {
            errorMessage = "An unexpected error occurred. Please try again"
        }
        
        // Reset loading state
        isLoading = false
    }
}

// MARK: - Custom Styles

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    SignInView()
}

#Preview("Sign In - Dark") {
    SignInView()
        .preferredColorScheme(.dark)
}

#Preview("Sign In - Light") {
    SignInView()
        .preferredColorScheme(.light)
}
