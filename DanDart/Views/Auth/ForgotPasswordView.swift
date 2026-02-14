//
//  ForgotPasswordView.swift
//  Dart Freak
//
//  Password reset screen for forgotten passwords
//

import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 16) {
                        // App Logo
                        Image("DartHeadOnly")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 100)
                        
                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                    }
                    
                    // Success Message
                    if !successMessage.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            
                            Text(successMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 32)
                    }
                    
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
                    
                    // Email Form Section
                    VStack(spacing: 16) {
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
                        .disabled(isLoading || !successMessage.isEmpty)
                        
                        // Send Reset Link Button
                        AppButton(
                            role: .primaryOutline,
                            controlSize: .extraLarge,
                            isDisabled: isLoading || !successMessage.isEmpty,
                            compact: true,
                            action: {
                                Task {
                                    await sendResetLink()
                                }
                            }
                        ) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(AppColor.interactivePrimaryBackground)
                                        .frame(width: 16, height: 16)
                                }
                                Text(isLoading ? "Sending..." : "Send Reset Link")
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Bottom Section
                    VStack(spacing: 16) {
                        // Back to Sign In Button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("Back to Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.surfacePrimary)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Private Methods
    
    /// Send password reset link
    private func sendResetLink() async {
        // Clear previous messages
        errorMessage = ""
        successMessage = ""
        
        // Validate input
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email"
            return
        }
        
        // Set loading state
        isLoading = true
        
        do {
            // Call AuthService to send reset email
            try await authService.resetPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            
            // Success - show success message
            successMessage = "Password reset email sent! Check your inbox and follow the link to reset your password."
            
        } catch {
            // Handle error
            if let authError = error as? AuthError {
                switch authError {
                case .invalidEmail:
                    errorMessage = "Please enter a valid email address"
                case .networkError:
                    errorMessage = "Network error. Please check your connection and try again"
                default:
                    errorMessage = "Failed to send reset email. Please try again"
                }
            } else {
                errorMessage = "Failed to send reset email. Please try again"
            }
        }
        
        // Reset loading state
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthService.shared)
}
