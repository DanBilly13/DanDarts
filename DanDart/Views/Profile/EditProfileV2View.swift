//
//  EditProfileV2View.swift
//  Dart Freak
//
//  Edit profile view using standard navigation pattern
//

import SwiftUI
import PhotosUI

struct EditProfileV2View: View {
    @EnvironmentObject private var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Form State
    @State private var displayName: String = ""
    @State private var nickname: String = ""
    @State private var email: String = ""
    @State private var selectedAvatar: String = "avatar1"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    @State private var originalAvatarURL: String?
    @State private var isAvatarDirty: Bool = false
    @State private var isHydratingExistingAvatar: Bool = false
    @State private var isInitialLoad: Bool = true
    
    // MARK: - Original Values (for change detection)
    @State private var originalDisplayName: String = ""
    @State private var originalNickname: String = ""
    @State private var originalEmail: String = ""
    
    // MARK: - UI State
    @State private var isSaving: Bool = false
    @State private var isUploadingAvatar: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @State private var showUnsavedChangesAlert: Bool = false
    @FocusState private var focusedField: Field?
    
    // MARK: - Field Focus
    enum Field {
        case name, nickname, email
    }
    
    // MARK: - Computed Properties
    private var isGoogleUser: Bool {
        authService.currentUser?.authProvider == .google
    }
    
    private var hasUnsavedChanges: Bool {
        let nameChanged = displayName != originalDisplayName
        let nicknameChanged = nickname != originalNickname
        let emailChanged = email != originalEmail
        
        let hasChanges = nameChanged || nicknameChanged || emailChanged || isAvatarDirty
        
        // Debug logging
        print("🔍 hasUnsavedChanges check:")
        print("  - Name: '\(displayName)' vs '\(originalDisplayName)' = \(nameChanged)")
        print("  - Nickname: '\(nickname)' vs '\(originalNickname)' = \(nicknameChanged)")
        print("  - Email: '\(email)' vs '\(originalEmail)' = \(emailChanged)")
        print("  - Avatar dirty: \(isAvatarDirty)")
        print("  - RESULT: \(hasChanges)")
        
        return hasChanges
    }
    
    // MARK: - Validation
    private var isValid: Bool {
        let nameValid = !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
                       displayName.count >= 2 &&
                       displayName.count <= 50
        
        let nicknameValid = !nickname.trimmingCharacters(in: .whitespaces).isEmpty &&
                           nickname.count >= 2 &&
                           nickname.count <= 20
        
        let emailValid = !email.trimmingCharacters(in: .whitespaces).isEmpty &&
                        email.contains("@")
        
        return nameValid && nicknameValid && emailValid
    }
    
    private var canSave: Bool {
        return isValid && hasUnsavedChanges && !isSaving && !isUploadingAvatar
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar Selection
                VStack(spacing: 16) {
                    
                    
                    AvatarSelectionViewV2(
                        selectedAvatar: $selectedAvatar,
                        selectedPhotoItem: $selectedPhotoItem,
                        selectedAvatarImage: $selectedAvatarImage
                    )
                }
                
                // Name Field (locked for Google users)
                if isGoogleUser {
                    LockedTextField(
                        label: "Name",
                        value: displayName
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        DartTextField(
                            label: "Name",
                            placeholder: "Enter your name",
                            text: $displayName,
                            textContentType: .name,
                            autocapitalization: .words,
                            onSubmit: {
                                focusedField = nil
                            }
                        )
                        
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
                        onSubmit: {
                            focusedField = nil
                        }
                    )
                    
                    // Show character count only when approaching limit or invalid
                    if nickname.count > 15 || nickname.count < 2 && !nickname.isEmpty {
                        Text("\(nickname.count)/20 characters")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(nickname.count > 20 || nickname.count < 2 ? .red : AppColor.textSecondary)
                            .padding(.leading, 2)
                    }
                }
                
                // Email Field (locked for Google users)
                if isGoogleUser {
                    LockedTextField(
                        label: "Email",
                        value: email
                    )
                } else {
                    DartTextField(
                        label: "Email",
                        placeholder: "Enter your email",
                        text: $email,
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress,
                        autocapitalization: .never,
                        autocorrectionDisabled: true,
                        onSubmit: {
                            focusedField = nil
                        }
                    )
                }
                
                // Change Password Button (email users only)
                if !isGoogleUser {
                    Button(action: {
                        // TODO: Implement change password flow
                        print("Change password tapped")
                    }) {
                        HStack {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 16, weight: .medium))
                            Text("Change Password")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(AppColor.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(AppColor.inputBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColor.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                
                // Error Message
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                // Loading indicator when saving
                if isSaving || isUploadingAvatar {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColor.interactivePrimaryBackground))
                            .scaleEffect(0.8)
                        Text(isUploadingAvatar ? "Uploading photo..." : "Saving changes...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .padding(.top, 8)
                }
                
                // Save Button at Bottom
                AppButton(
                    role: .primary,
                    controlSize: .large,
                    isDisabled: !canSave,
                    action: {
                        Task {
                            await handleSave()
                        }
                    }
                ) {
                    Text(isSaving || isUploadingAvatar ? "Saving..." : "Save Changes")
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    print("⬅️ BACK/CANCEL button tapped")
                    print("  hasUnsavedChanges: \(hasUnsavedChanges)")
                    if hasUnsavedChanges {
                        print("  → Showing unsaved changes alert")
                        showUnsavedChangesAlert = true
                    } else {
                        print("  → Dismissing view")
                        dismiss()
                    }
                }) {
                    if hasUnsavedChanges {
                        Text("Cancel")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    } else {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
        }
        .background(AppColor.surfacePrimary)
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: selectedAvatar) { oldValue, newValue in
            print("🎨 selectedAvatar changed from '\(oldValue)' to: '\(newValue)', isInitialLoad: \(isInitialLoad), originalAvatarURL: '\(originalAvatarURL ?? "nil")'")
            // Only mark as dirty if not initial load AND the value is different from original
            if !isInitialLoad && !newValue.isEmpty && newValue != originalAvatarURL {
                print("  → Marking avatar as dirty (changed from original)")
                isAvatarDirty = true
            } else {
                print("  → Not marking as dirty (isInitialLoad: \(isInitialLoad), matches original: \(newValue == originalAvatarURL))")
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            print("📸 selectedPhotoItem changed, isInitialLoad: \(isInitialLoad)")
            if !isInitialLoad && newItem != nil {
                print("  → Marking avatar as dirty")
                isAvatarDirty = true
            }
        }
        .onChange(of: selectedAvatarImage) { _, newImage in
            print("🖼️ selectedAvatarImage changed, isInitialLoad: \(isInitialLoad), isHydratingExistingAvatar: \(isHydratingExistingAvatar)")
            if isHydratingExistingAvatar {
                return
            }
            if !isInitialLoad && newImage != nil && selectedPhotoItem == nil && selectedAvatar.isEmpty {
                print("  → Marking avatar as dirty")
                isAvatarDirty = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await handlePhotoSelection(newItem)
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Discard Changes", role: .destructive) {
                print("🗑️ DISCARD CHANGES tapped")
                resetForm()
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {
                print("✏️ KEEP EDITING tapped")
            }
        } message: {
            Text("You have unsaved changes. Are you sure you want to go back?")
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been updated successfully")
        }
    }
    
    // MARK: - Actions
    
    private func resetForm() {
        print("🔄 RESET FORM called")
        print("  Before reset:")
        print("    - displayName: '\(displayName)'")
        print("    - nickname: '\(nickname)'")
        print("    - email: '\(email)'")
        print("    - isAvatarDirty: \(isAvatarDirty)")
        
        // Reset all fields to original values
        displayName = originalDisplayName
        nickname = originalNickname
        email = originalEmail
        
        // Reset avatar to original state
        isAvatarDirty = false
        selectedPhotoItem = nil
        isInitialLoad = true
        
        if let originalURL = originalAvatarURL {
            if originalURL.hasPrefix("http://") || originalURL.hasPrefix("https://") {
                selectedAvatar = ""
                isHydratingExistingAvatar = true
                Task {
                    await loadCustomAvatar(from: originalURL)
                    await MainActor.run {
                        isHydratingExistingAvatar = false
                        isInitialLoad = false
                    }
                }
            } else {
                selectedAvatar = originalURL
                selectedAvatarImage = nil
                isInitialLoad = false
            }
        } else {
            selectedAvatar = "avatar1"
            selectedAvatarImage = nil
            isInitialLoad = false
        }
        
        print("  After reset:")
        print("    - displayName: '\(displayName)'")
        print("    - nickname: '\(nickname)'")
        print("    - email: '\(email)'")
        print("    - isAvatarDirty: \(isAvatarDirty)")
    }

    private func loadCurrentProfile() {
        print("📥 LOAD CURRENT PROFILE called")
        guard let currentUser = authService.currentUser else {
            print("  ⚠️ No current user found")
            return
        }
        
        displayName = currentUser.displayName
        nickname = currentUser.nickname
        email = currentUser.email ?? ""
        
        // Store original values for change detection
        originalDisplayName = displayName
        originalNickname = nickname
        originalEmail = email
        
        print("  Loaded values:")
        print("    - displayName: '\(displayName)'")
        print("    - nickname: '\(nickname)'")
        print("    - email: '\(email)'")
        print("    - avatarURL: '\(currentUser.avatarURL ?? "nil")'")
        
        // Set avatar
        originalAvatarURL = currentUser.avatarURL
        isAvatarDirty = false

        if let avatarURL = currentUser.avatarURL {
            if avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                selectedAvatar = ""
                isHydratingExistingAvatar = true
                Task {
                    await loadCustomAvatar(from: avatarURL)
                    await MainActor.run {
                        isHydratingExistingAvatar = false
                        isInitialLoad = false
                        print("  ✅ Initial load complete, isInitialLoad set to false")
                    }
                }
            } else {
                selectedAvatar = avatarURL
                selectedAvatarImage = nil
                selectedPhotoItem = nil
                isInitialLoad = false
                print("  ✅ Initial load complete, isInitialLoad set to false")
            }
        } else {
            isInitialLoad = false
            print("  ✅ Initial load complete (no avatar), isInitialLoad set to false")
        }
    }

    private func loadCustomAvatar(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    selectedAvatarImage = image
                }
            }
        } catch {
            print("Failed to load custom avatar: \(error.localizedDescription)")
        }
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
    
    private func handleSave() async {
        isSaving = true
        errorMessage = ""
        defer { isSaving = false }

        do {
            var avatarURL = selectedAvatar

            if !isAvatarDirty {
                avatarURL = originalAvatarURL ?? selectedAvatar
            }

            // Upload photo if one was selected
            if isAvatarDirty, let selectedImage = selectedAvatarImage {
                isUploadingAvatar = true
                defer { isUploadingAvatar = false }

                // Resize and compress image
                let resizedImage = selectedImage.resized(toMaxDimension: 512)
                guard let jpegData = resizedImage.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "ImageError", code: -1)
                }

                // Upload to Supabase
                avatarURL = try await authService.uploadAvatar(imageData: jpegData)
            }

            // Update profile
            try await authService.updateProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                email: isGoogleUser ? nil : email.trimmingCharacters(in: .whitespacesAndNewlines),
                avatarURL: avatarURL
            )

            originalAvatarURL = avatarURL
            isAvatarDirty = false
            
            // Update original values after successful save
            originalDisplayName = displayName
            originalNickname = nickname
            originalEmail = email
            
            showSuccessAlert = true
        } catch {
            errorMessage = "Failed to update profile. Please try again."
        }
    }
}

// MARK: - Preview
#Preview("Email User - With AI (iOS 18.1+)") {
    NavigationStack {
        EditProfileV2View()
            .environmentObject(AuthService.mockEmailUser)
    }
}

#Preview("Email User - Without AI (Older)") {
    NavigationStack {
        EditProfileV2View()
            .environmentObject(AuthService.mockEmailUser)
    }
}

#Preview("Google User - With AI (iOS 18.1+)") {
    NavigationStack {
        EditProfileV2View()
            .environmentObject(AuthService.mockGoogleUser)
    }
}

#Preview("Google User - Without AI (Older)") {
    NavigationStack {
        EditProfileV2View()
            .environmentObject(AuthService.mockGoogleUser)
    }
}
