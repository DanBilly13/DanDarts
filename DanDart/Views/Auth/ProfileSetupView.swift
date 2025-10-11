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
    @State private var handle = ""
    @State private var bio = ""
    @State private var selectedAvatarIndex = 0
    
    // MARK: - UI State
    @State private var showErrors = false
    @State private var errorMessage = ""
    @State private var isCompleting = false
    
    // MARK: - Avatar Options
    private let avatarOptions = [
        "person.circle.fill",
        "gamecontroller.fill",
        "target",
        "trophy.fill",
        "star.fill",
        "flame.fill",
        "bolt.fill",
        "heart.fill"
    ]
    
    // MARK: - Computed Properties
    private var isFormValid: Bool {
        !handle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        handle.count >= 3 &&
        handle.count <= 20 &&
        handle.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Complete Your Profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("Add a few details to personalize your DanDarts experience")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Avatar Selection
                    VStack(spacing: 20) {
                        Text("Choose Your Avatar")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        // Selected Avatar Display
                        Image(systemName: avatarOptions[selectedAvatarIndex])
                            .font(.system(size: 80, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                            .frame(width: 120, height: 120)
                            .background(Color("InputBackground"))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color("AccentPrimary"), lineWidth: 3)
                            )
                        
                        // Avatar Options Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                            ForEach(0..<avatarOptions.count, id: \.self) { index in
                                Button(action: {
                                    selectedAvatarIndex = index
                                }) {
                                    Image(systemName: avatarOptions[index])
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(selectedAvatarIndex == index ? Color("AccentPrimary") : Color("TextSecondary"))
                                        .frame(width: 60, height: 60)
                                        .background(
                                            selectedAvatarIndex == index ? 
                                            Color("AccentPrimary").opacity(0.1) : 
                                            Color("InputBackground")
                                        )
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedAvatarIndex == index ? 
                                                    Color("AccentPrimary") : 
                                                    Color("TextSecondary").opacity(0.2), 
                                                    lineWidth: selectedAvatarIndex == index ? 2 : 1
                                                )
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Handle TextField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Handle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            HStack(spacing: 0) {
                                Text("@")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                    .padding(.leading, 16)
                                    .padding(.trailing, 4)
                                
                                TextField("your_handle", text: $handle)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextPrimary"))
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .padding(.trailing, 16)
                                    .padding(.vertical, 14)
                            }
                            .background(Color("InputBackground"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
                            )
                            
                            Text("3-20 characters, letters, numbers, and underscores only")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .padding(.leading, 4)
                        }
                        
                        // Bio TextField
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio (Optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                            
                            TextField("Tell us about yourself...", text: $bio, axis: .vertical)
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
                                .lineLimit(3...6)
                            
                            Text("\(bio.count)/200 characters")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .padding(.leading, 4)
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
                        .disabled(!isFormValid || isCompleting)
                        .opacity((isFormValid && !isCompleting) ? 1.0 : 0.6)
                        
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
        showErrors = true
        errorMessage = ""
        isCompleting = true
        defer { isCompleting = false }
        
        guard isFormValid else {
            errorMessage = "Please enter a valid handle"
            return
        }
        
        // Limit bio to 200 characters
        let trimmedBio = String(bio.prefix(200))
        
        do {
            // Update user profile with AuthService
            try await authService.updateProfile(
                handle: handle.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                avatarIcon: avatarOptions[selectedAvatarIndex]
            )
            
            // Navigate to main app
            dismiss()
            
        } catch let error as AuthError {
            switch error {
            case .nicknameAlreadyExists:
                errorMessage = "This handle is already taken. Please choose another."
            case .invalidNickname:
                errorMessage = "Invalid handle format. Use 3-20 characters, letters, numbers, and underscores only."
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
        
        // Skip setup and go to main app
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
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
