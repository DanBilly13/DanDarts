//
//  SignUpView.swift
//  DanDart
//
//  Sign up screen for user registration
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                            
                            TextField("Your full name", text: .constant(""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("BackgroundSecondary"))
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
                                
                                TextField("username", text: .constant(""))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextPrimary"))
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 14)
                            }
                            .background(Color("BackgroundSecondary"))
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
                            
                            TextField("Enter your email", text: .constant(""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("BackgroundSecondary"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                                )
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password SecureField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            SecureField("Create a password", text: .constant(""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("BackgroundSecondary"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                                )
                                .textContentType(.newPassword)
                        }
                        
                        // Confirm Password SecureField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            SecureField("Confirm your password", text: .constant(""))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color("BackgroundSecondary"))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                                )
                                .textContentType(.newPassword)
                        }
                        
                        // Password Requirements
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must contain:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green.opacity(0.6))
                                Text("At least 8 characters")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 32)
                    
                    // Create Account Button
                    VStack(spacing: 16) {
                        Button(action: {
                            // TODO: Implement sign up action
                        }) {
                            Text("Create Account")
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
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.1), value: false)
                    }
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
}

// MARK: - Custom Styles
// Note: CustomTextFieldStyle and SecondaryButtonStyle are defined in SignInView.swift

// MARK: - Preview
#Preview {
    SignUpView()
}

#Preview("Sign Up - Dark") {
    SignUpView()
        .preferredColorScheme(.dark)
}

#Preview("Sign Up - Light") {
    SignUpView()
        .preferredColorScheme(.light)
}
