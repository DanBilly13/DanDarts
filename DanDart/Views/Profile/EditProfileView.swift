//
//  EditProfileView.swift
//  DanDart
//
//  Edit profile view for updating user information
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    
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
    
    // MARK: - UI State
    @State private var isSaving: Bool = false
    @State private var isUploadingAvatar: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    @FocusState private var focusedField: Field?
    
    // MARK: - Field Focus
    enum Field {
        case name, nickname, email
    }
    
    // MARK: - Computed Properties
    private var isGoogleUser: Bool {
        authService.currentUser?.authProvider == .google
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                // Avatar Selection
                VStack(spacing: 16) {
                    Text("Profile Picture")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                Button(action: {
                    Task {
                        await handleSave()
                    }
                }) {
                    Text(isSaving || isUploadingAvatar ? "Saving..." : "Save Changes")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValid && !isSaving && !isUploadingAvatar ? AppColor.interactivePrimaryBackground : AppColor.textSecondary.opacity(0.5))
                        .cornerRadius(12)
                }
                .disabled(!isValid || isSaving || isUploadingAvatar)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            SheetTopBarSub(
                title: "Edit Profile",
                subtitle: nil,
                onClose: {
                    dismiss()
                }
            )
        }
        .background(AppColor.backgroundPrimary)
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: selectedAvatar) { _, newValue in
            if !newValue.isEmpty {
                isAvatarDirty = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            if newItem != nil {
                isAvatarDirty = true
            }
        }
        .onChange(of: selectedAvatarImage) { _, newImage in
            if isHydratingExistingAvatar {
                return
            }
            if newImage != nil && selectedPhotoItem == nil && selectedAvatar.isEmpty {
                isAvatarDirty = true
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await handlePhotoSelection(newItem)
            }
        }
        .alert("Success", isPresented: $showSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your profile has been updated successfully")
        }
    }
}

private struct SheetTopBarSub: View {
    let title: String
    let subtitle: String?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer()

            TopBarCloseButton(action: onClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColor.backgroundPrimary)
    }
}
    
// MARK: - Actions
    
private func loadCurrentProfile() {
    guard let currentUser = authService.currentUser else { return }
    
    displayName = currentUser.displayName
    nickname = currentUser.nickname
    email = currentUser.email ?? ""
    
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
                }
            }
        } else {
            selectedAvatar = avatarURL
            selectedAvatarImage = nil
            selectedPhotoItem = nil
        }
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
        showSuccessAlert = true
    } catch {
        errorMessage = "Failed to update profile. Please try again."
    }
}

}

// MARK: - Preview
#Preview("Email User") {
    EditProfileView()
        .environmentObject(AuthService.mockEmailUser)
}

#Preview("Google User") {
    EditProfileView()
        .environmentObject(AuthService.mockGoogleUser)
}
