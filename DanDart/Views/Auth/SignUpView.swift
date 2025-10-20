//
//  SignUpView.swift
//  DanDart
//
//  Sign up screen for user registration
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    // MARK: - Form State
    @State private var displayName = ""
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // MARK: - UI State
    @State private var showErrors = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !displayName.isEmpty &&
        !nickname.isEmpty &&
        nickname.count >= 3 &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        confirmPassword == password
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8
    }
    
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
                        
                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Join the DanDarts community")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.top, 20)
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Display Name TextField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Display Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            TextField("Your full name", text: $displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("InputBackground"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                                )
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }
                        
                        // Nickname TextField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nickname")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack(spacing: 0) {
                                Text("@")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                    .padding(.leading, 16)
                                    .padding(.trailing, 4)
                                
                                TextField("username", text: $nickname)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextPrimary"))
                                    .textContentType(.nickname)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 14)
                            }
                            .background(Color("InputBackground"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Email TextField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            TextField("Enter your email", text: $email)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("InputBackground"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                                )
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.next)
                                .onChange(of: email) { oldValue, newValue in
                                    // Fix Swedish keyboard @ symbol issue
                                    let correctedEmail = newValue.replacingOccurrences(of: "™", with: "@")
                                    if correctedEmail != newValue {
                                        email = correctedEmail
                                    }
                                }
                        }
                        
                        // Password SecureField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack {
                                if showPassword {
                                    TextField("Create a password", text: $password)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color("TextPrimary"))
                                        .textContentType(.newPassword)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Create a password", text: $password)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color("TextPrimary"))
                                        .textContentType(.newPassword)
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color("TextSecondary"))
                                }
                                .padding(.trailing, 16)
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 14)
                            .background(Color("InputBackground"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Confirm Password SecureField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack {
                                if showConfirmPassword {
                                    TextField("Confirm your password", text: $confirmPassword)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color("TextPrimary"))
                                        .textContentType(.newPassword)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                } else {
                                    SecureField("Confirm your password", text: $confirmPassword)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color("TextPrimary"))
                                        .textContentType(.newPassword)
                                }
                                
                                Button(action: {
                                    showConfirmPassword.toggle()
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color("TextSecondary"))
                                }
                                .padding(.trailing, 16)
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 14)
                            .background(Color("InputBackground"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Password Requirements
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack(spacing: 8) {
                                Image(systemName: isPasswordValid ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(isPasswordValid ? .green : Color("TextSecondary").opacity(0.6))
                                Text("At least 8 characters")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(isPasswordValid ? .green : Color("TextSecondary"))
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 32)
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Create Account Button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await handleSignUp()
                            }
                        }) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(authService.isLoading ? "Creating Account..." : "Create Account")
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
                        .disabled(!isFormValid || authService.isLoading)
                        .opacity((isFormValid && !authService.isLoading) ? 1.0 : 0.6)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.1), value: false)
                    }
                    .padding(.horizontal, 32)
                    
                    // OR Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color("TextSecondary").opacity(0.3))
                        
                        Text("OR")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(Color("TextSecondary").opacity(0.3))
                    }
                    .padding(.horizontal, 32)
                    
                    // Google Sign Up Button
                    Button(action: {
                        Task {
                            await handleGoogleSignUp()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if authService.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("TextPrimary")))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color("TextPrimary"))
                            }
                            
                            Text(authService.isLoading ? "Signing up with Google..." : "Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color("BackgroundSecondary"))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                        )
                    }
                    .disabled(authService.isLoading)
                    .opacity(authService.isLoading ? 0.6 : 1.0)
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                    
                    // Sign In Link
                    HStack {
                        Text("Already have an account?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                        
                        Button("Sign In") {
                            // TODO: Navigate to sign in
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color("AccentPrimary"))
                    }
                    .padding(.bottom, 32)
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
    
    // MARK: - Actions
    private func handleSignUp() async {
        print("🚀 handleSignUp called")
        showErrors = true
        errorMessage = ""
        
        guard isFormValid else {
            print("❌ Form validation failed")
            errorMessage = "Please fill in all fields correctly"
            return
        }
        
        print("✅ Form validation passed")
        
        do {
            // Call AuthService to create the account
            try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            // Success! Dismiss SignUpView - ContentView will show ProfileSetupView
            dismiss()
            
        } catch let error as AuthError {
            // Handle specific auth errors
            switch error {
            case .emailAlreadyExists:
                errorMessage = "An account with this email already exists"
            case .nicknameAlreadyExists:
                errorMessage = "This nickname is already taken"
            case .weakPassword:
                errorMessage = "Password is too weak. Please choose a stronger password"
            case .invalidEmail:
                errorMessage = "Please enter a valid email address"
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again"
            default:
                errorMessage = "Failed to create account. Please try again"
            }
        } catch {
            // Handle unexpected errors
            print("❌ Unexpected error: \(error)")
            
            // Check if it's a timeout
            if error.localizedDescription.contains("timed out") || 
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") {
                errorMessage = "Connection timeout. Please try signing in with Google instead."
            } else {
                errorMessage = "An unexpected error occurred. Please try again"
            }
        }
    }
    
    private func handleGoogleSignUp() async {
        errorMessage = ""
        
        do {
            // Call AuthService Google OAuth
            let isNewUser = try await authService.signInWithGoogle()
            
            // Dismiss SignUpView
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
    }
}

// MARK: - Custom Styles
// Note: CustomTextFieldStyle and SecondaryButtonStyle are defined in SignInView.swift

// MARK: - Preview
#Preview {
    SignUpView()
        .environmentObject(AuthService())
}

#Preview("Sign Up - Dark") {
    SignUpView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}

#Preview("Sign Up - Light") {
    SignUpView()
        .environmentObject(AuthService())
        .preferredColorScheme(.light)
}
