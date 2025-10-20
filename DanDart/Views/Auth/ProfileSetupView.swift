//
//  ProfileSetupView.swift
//  DanDart
//
//  Profile setup screen for new users
//

import SwiftUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    // MARK: - Form State
    @State private var selectedAvatar: String = "avatar1" // Default to first avatar
    
    // MARK: - UI State
    @State private var errorMessage = ""
    @State private var isCompleting = false
    
    // MARK: - Avatar Options (same as AddGuestPlayerView)
    private let avatarOptions: [AvatarOption] = [
        // Asset avatars
        AvatarOption(id: "avatar1", type: .asset),
        AvatarOption(id: "avatar2", type: .asset),
        AvatarOption(id: "avatar3", type: .asset),
        AvatarOption(id: "avatar4", type: .asset),
        // SF Symbol avatars
        AvatarOption(id: "person.circle.fill", type: .symbol),
        AvatarOption(id: "person.crop.circle.fill", type: .symbol),
        AvatarOption(id: "figure.wave.circle.fill", type: .symbol),
        AvatarOption(id: "person.2.circle.fill", type: .symbol)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Choose Your Avatar")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Pick an avatar to personalize your profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Avatar Selection (same as AddGuestPlayerView)
                    VStack(spacing: 20) {
                        // Avatar Options Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(avatarOptions, id: \.id) { option in
                                Button(action: {
                                    selectedAvatar = option.id
                                }) {
                                    AvatarOptionView(
                                        option: option,
                                        isSelected: selectedAvatar == option.id,
                                        size: 70
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Complete Setup Button
                    VStack(spacing: 16) {
                        Button(action: {
                            Task {
                                await handleCompleteSetup()
                            }
                        }) {
                            HStack {
                                if isCompleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isCompleting ? "Completing Setup..." : "Complete Setup")
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
                        .disabled(isCompleting)
                        .opacity(!isCompleting ? 1.0 : 0.6)
                        
                        // Skip Button
                        Button("Skip for now") {
                            Task {
                                await handleSkipSetup()
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .disabled(isCompleting)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                }
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("AccentPrimary"))
                    .disabled(isCompleting)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func handleCompleteSetup() async {
        errorMessage = ""
        isCompleting = true
        defer { isCompleting = false }
        
        do {
            // Update user profile with selected avatar
            try await authService.updateProfile(
                handle: nil, // Handle not needed - nickname already set during signup
                bio: nil, // Bio removed
                avatarIcon: selectedAvatar
            )
            
            // Navigate to main app
            dismiss()
            
        } catch let error as AuthError {
            switch error {
            case .networkError:
                errorMessage = "Network error. Please check your connection and try again."
            default:
                errorMessage = "Failed to complete setup. Please try again."
            }
        } catch {
            errorMessage = "Failed to complete setup. Please try again."
        }
    }
    
    private func handleSkipSetup() async {
        isCompleting = true
        defer { isCompleting = false }
        
        // Complete profile setup without updating profile
        authService.completeProfileSetup()
        
        // Brief delay for smooth transition
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    ProfileSetupView()
        .environmentObject(AuthService())
}

#Preview("Profile Setup - Dark") {
    ProfileSetupView()
        .environmentObject(AuthService())
        .preferredColorScheme(.dark)
}
