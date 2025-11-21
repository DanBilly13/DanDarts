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
                            .foregroundColor(AppColor.brandPrimary)
                        
                        Text("Welcome Back")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                        
                       /* Text("Sign in to your account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))*/
                    }
                    .padding(.top, 32)
                    
                    // Google Sign-In Button (Primary)
                    AppButton(
                        role: .primary,
                        controlSize: .extraLarge,
                        isDisabled: isLoading,
                        compact: true,
                        action: {
                            Task {
                                await signInWithGoogle()
                            }
                        }
                    ) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppColor.textOnPrimary))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            Text(isLoading ? "Signing in with Google..." : "Sign in with Google")
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppColor.textSecondary.opacity(0.3))
                        
                        Text("or email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(AppColor.textSecondary.opacity(0.3))
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    
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
                    
                    // Email Sign-In Form Section
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
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                        
                        // Sign In with Email Button (Primary Outline)
                        AppButton(
                            role: .primaryOutline,
                            controlSize: .extraLarge,
                            isDisabled: isLoading,
                            compact: true,
                            action: {
                                Task {
                                    await signIn()
                                }
                            }
                        ) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColor.interactivePrimaryBackground))
                                        .scaleEffect(0.8)
                                }
                                Text(isLoading ? "Signing In..." : "Sign in with Email")
                            }
                        }
                    }
                    .padding(.horizontal, 32)
          
                    
                    Spacer(minLength: 8)
                    
                    // Bottom Links
                    VStack(spacing: 16) {
                        // Sign Up Link
                        NavigationLink(destination: SignUpView()) {
                            HStack {
                                Text("Don't have an account?")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(AppColor.textSecondary)
                                
                                Text("Sign Up")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColor.interactivePrimaryBackground)
                            }
                        }
                        
                        
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.interactivePrimaryBackground)
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
