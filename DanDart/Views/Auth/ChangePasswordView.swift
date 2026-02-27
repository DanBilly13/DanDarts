//
//  ChangePasswordView.swift
//  Dart Freak
//
//  Password change screen for password reset flow
//

import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var authService: AuthService
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 60))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                        
                        Text("Create New Password")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Please enter a new password for your account")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 40)
                    
                    // Error message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal, 32)
                    }
                    
                    // Password fields
                    VStack(spacing: 16) {
                        DartSecureField(
                            label: "New Password",
                            placeholder: "Enter new password",
                            text: $newPassword,
                            textContentType: .newPassword
                        )
                        
                        DartSecureField(
                            label: "Confirm Password",
                            placeholder: "Confirm new password",
                            text: $confirmPassword,
                            textContentType: .newPassword
                        )
                        
                        AppButton(
                            role: .primaryOutline,
                            controlSize: .extraLarge,
                            isDisabled: isLoading || newPassword.isEmpty || confirmPassword.isEmpty,
                            compact: true,
                            action: {
                                Task {
                                    await updatePassword()
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
                                Text(isLoading ? "Updating..." : "Update Password")
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .background(AppColor.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
    
    private func updatePassword() async {
        errorMessage = ""
        
        // Validation
        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Update password via Supabase
            try await authService.updatePassword(newPassword: newPassword)
            
            // Exit recovery mode
            await MainActor.run {
                authService.isInRecoveryMode = false
            }
            
            // ContentView will now show MainTabView
            print("✅ Password changed successfully, exiting recovery mode")
            
        } catch {
            errorMessage = "Failed to update password. Please try again."
            print("❌ Password update failed: \(error)")
        }
    }
}

#Preview {
    ChangePasswordView()
        .environmentObject(AuthService())
}
