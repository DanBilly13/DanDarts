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
        StandardSheetView(
            title: "Edit Profile",
            dismissButtonTitle: "Cancel",
            primaryActionTitle: isSaving || isUploadingAvatar ? "Saving..." : "Save Changes",
            primaryActionEnabled: isValid && !isSaving && !isUploadingAvatar,
            onDismiss: { dismiss() },
            onPrimaryAction: {
                Task {
                    await handleSave()
                }
            }
        ) {
            VStack(spacing: 24) {
                // Avatar Selection
                VStack(spacing: 16) {
                    Text("Profile Picture")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AvatarSelectionView(
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
                                .foregroundColor(displayName.count > 50 || displayName.count < 2 ? .red : Color("TextSecondary"))
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
                            .foregroundColor(nickname.count > 20 || nickname.count < 2 ? .red : Color("TextSecondary"))
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
                        .foregroundColor(Color("TextPrimary"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("TextSecondary").opacity(0.2), lineWidth: 1)
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
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("AccentPrimary")))
                            .scaleEffect(0.8)
                        Text(isUploadingAvatar ? "Uploading photo..." : "Saving changes...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
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
    
    // MARK: - Actions
    
    private func loadCurrentProfile() {
        guard let currentUser = authService.currentUser else { return }
        
        displayName = currentUser.displayName
        nickname = currentUser.nickname
        email = currentUser.email ?? ""
        
        // Set avatar
        if let avatarURL = currentUser.avatarURL {
            if avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                // It's a custom uploaded image - download it
                Task {
                    await loadCustomAvatar(from: avatarURL)
                }
            } else {
                // It's a predefined avatar
                selectedAvatar = avatarURL
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
            
            selectedAvatarImage = uiImage
        } catch {
            print("Failed to load photo")
            errorMessage = "Failed to load photo. Please try again."
        }
    }
    
    private func handleSave() async {
        guard let currentUser = authService.currentUser else { return }
        
        isSaving = true
        errorMessage = ""
        
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
            
            // Update profile
            try await authService.updateProfile(
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                nickname: nickname.trimmingCharacters(in: .whitespaces),
                email: isGoogleUser ? nil : email.trimmingCharacters(in: .whitespaces),
                avatarURL: avatarURL
            )
            
            showSuccessAlert = true
            
        } catch {
            errorMessage = "Failed to update profile. Please try again."
            isSaving = false
            isUploadingAvatar = false
        }
        
        isSaving = false
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
