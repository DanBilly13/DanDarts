//
//  ProfileSetupView.swift
//  DanDart
//
//  Profile setup screen for new users
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
    // MARK: - Form State
    @State private var selectedAvatar: String = "avatar1" // Default to first avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    
    // MARK: - UI State
    @State private var errorMessage = ""
    @State private var isCompleting = false
    @State private var isUploadingAvatar = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Choose Your Avatar")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Upload your own photo or pick an avatar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Avatar Selection Component
                    AvatarSelectionViewV2(
                        selectedAvatar: $selectedAvatar,
                        selectedPhotoItem: $selectedPhotoItem,
                        selectedAvatarImage: $selectedAvatarImage
                    )
                    
                    
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
                        AppButton(role: .primary,
                                  controlSize: .regular,
                                  isDisabled: isCompleting,
                                  action: {
                                      Task { await handleCompleteSetup() }
                                  }) {
                            HStack {
                                if isCompleting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppColor.textOnPrimary))
                                        .scaleEffect(0.8)
                                }
                                Text(isCompleting ? "Completing Setup..." : "Complete Setup")
                            }
                        }
                        .opacity(!isCompleting ? 1.0 : 0.6)
                        
                        // Skip Button
                        Button("Skip for now") {
                            Task {
                                await handleSkipSetup()
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .disabled(isCompleting)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 20)
                }
            }
            .background(AppColor.backgroundPrimary)
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                    .disabled(isCompleting)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Actions
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                return
            }

            selectedAvatarImage = uiImage.resized(toMaxDimension: 512)
        } catch {
            print("Failed to load photo")
            errorMessage = "Failed to load photo. Please try again."
        }
    }
    
    private func handleCompleteSetup() async {
        errorMessage = ""
        isCompleting = true
        defer { isCompleting = false }
        
        do {
            var avatarURL = selectedAvatar
            
            // Upload photo if one was selected
            if let selectedImage = selectedAvatarImage {
                isUploadingAvatar = true
                
                // Resize and compress image
                let resizedImage = selectedImage.resized(toMaxDimension: 512)
                guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageError", code: -1)
                }
                
                // Upload to Supabase
                avatarURL = try await authService.uploadAvatar(imageData: jpegData)
                
                isUploadingAvatar = false
            }
            
            // Update user profile with avatar
            try await authService.updateProfile(
                handle: nil,
                bio: nil,
                avatarIcon: avatarURL
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
