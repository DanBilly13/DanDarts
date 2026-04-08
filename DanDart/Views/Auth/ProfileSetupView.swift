//
//  ProfileSetupView.swift
//  Dart Freak
//
//  Profile setup screen for new users
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    private let analytics = AnalyticsService.shared
    
    // MARK: - Form State
    @State private var displayName: String = ""
    @State private var nickname: String = ""
    @State private var originalDisplayName: String = ""
    @State private var originalNickname: String = ""
    @State private var selectedAvatar: String = "avatar1" // Default to first avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    
    // MARK: - UI State
    @State private var errorMessage = ""
    @State private var isCompleting = false
    @State private var isUploadingAvatar = false
    
    // Focus state for keyboard navigation
    @FocusState private var displayNameFieldIsFocused: Bool
    @FocusState private var nicknameFieldIsFocused: Bool
    
    // MARK: - Computed Properties
    private var isGoogleUser: Bool {
        authService.currentUser?.authProvider == .google
    }
    
    private var isNameValid: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count >= 2 && trimmed.count <= 50
    }
    
    private var isNicknameValid: Bool {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed.count >= 2 && trimmed.count <= 20
    }
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 16) {
                        Text("Complete profile")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Choose your avatar and set your details")
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
                    
                    // Name and Nickname Fields
                    VStack(spacing: 24) {
                        // Name Field (locked for Google users)
                        if isGoogleUser {
                            LockedTextField(
                                label: "Name",
                                value: displayName,
                                subtitle: "Managed by Google"
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                DartTextField(
                                    label: "Name",
                                    placeholder: "Enter your name",
                                    text: $displayName,
                                    textContentType: .name,
                                    autocapitalization: .words,
                                    submitLabel: .done,
                                    onSubmit: {
                                        nicknameFieldIsFocused = true
                                    }
                                )
                                .focused($displayNameFieldIsFocused)
                                .id("displayNameField")
                                
                                // Show character count only when approaching limit or invalid
                                if displayName.count > 45 || displayName.count < 2 && !displayName.isEmpty {
                                    Text("\(displayName.count)/50 characters")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(displayName.count > 50 || displayName.count < 2 ? .red : AppColor.textSecondary)
                                        .padding(.leading, 2)
                                }
                            }
                        }
                        
                        // Nickname Field (always editable)
                        VStack(alignment: .leading, spacing: 8) {
                            DartTextField(
                                label: "Nickname",
                                placeholder: "Your game nickname",
                                text: $nickname,
                                autocapitalization: .never,
                                autocorrectionDisabled: true,
                                submitLabel: .done
                            )
                            .focused($nicknameFieldIsFocused)
                            .id("nicknameField")
                            
                            // Show character count only when approaching limit or invalid
                            if nickname.count > 15 || nickname.count < 2 && !nickname.isEmpty {
                                Text("\(nickname.count)/20 characters")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(nickname.count > 20 || nickname.count < 2 ? .red : AppColor.textSecondary)
                                    .padding(.leading, 2)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
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
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: nicknameFieldIsFocused) { _, isFocused in
                if isFocused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("nicknameField", anchor: .bottom)
                        }
                    }
                }
            }
        }
            .background(AppColor.backgroundPrimary)
            // Removed navigationTitle and toolbar
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
            .onAppear {
                loadUserProfile()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Actions
    
    private func loadUserProfile() {
        guard let currentUser = authService.currentUser else { return }
        
        displayName = currentUser.displayName
        nickname = currentUser.nickname
        originalDisplayName = currentUser.displayName
        originalNickname = currentUser.nickname
        
        print("📥 ProfileSetupView - Loaded user profile:")
        print("  displayName: '\(displayName)'")
        print("  nickname: '\(nickname)'")
    }
    
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
        
        // Validate fields first
        guard isNameValid && isNicknameValid else {
            errorMessage = "Please check your name (2-50 characters) and nickname (2-20 characters)"
            return
        }
        
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
            
            // Update user profile with name, nickname, and avatar
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            print("🔧 ProfileSetupView - Calling updateProfile with:")
            print("  displayName: '\(trimmedName)'")
            print("  nickname: '\(trimmedNickname)'")
            print("  avatarURL: '\(avatarURL)'")
            
            try await authService.updateProfile(
                displayName: trimmedName,
                nickname: trimmedNickname,
                email: nil, // Not shown in ProfileSetupView
                avatarURL: avatarURL
            )
            
            // Complete profile setup - sets needsProfileSetup = false and isAuthenticated = true
            authService.completeProfileSetup()
            
            // Log profile setup completed event
            let hasAvatar = selectedAvatarImage != nil
            let signupMethod = authService.currentUser?.email?.contains("@") == true ? "email" : "google"
            analytics.logProfileSetupCompleted(hasAvatar: hasAvatar, signupMethod: signupMethod)
            
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
