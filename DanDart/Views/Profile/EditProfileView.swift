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
    @State private var selectedAvatar: String = "avatar1"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    
    // MARK: - UI State
    @State private var isSaving: Bool = false
    @State private var isUploadingAvatar: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessAlert: Bool = false
    
    // MARK: - Validation
    private var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        displayName.count >= 2 &&
        displayName.count <= 50
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
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
                    
                    // Display Name Field
                    VStack(alignment: .leading, spacing: 8) {
                        DartTextField(
                            label: "Display Name",
                            placeholder: "Enter your name",
                            text: $displayName,
                            textContentType: .name,
                            autocapitalization: .words
                        )
                        
                        Text("\(displayName.count)/50 characters")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .padding(.leading, 2)
                    }
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Save Button
                    AppButton(
                        role: .primary,
                        controlSize: .regular,
                        isDisabled: !isValid || isSaving || isUploadingAvatar
                    ) {
                        Task {
                            await handleSave()
                        }
                    } label: {
                        HStack {
                            if isSaving || isUploadingAvatar {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSaving || isUploadingAvatar ? "Saving..." : "Save Changes")
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
            }
            .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    }
    
    // MARK: - Actions
    
    private func loadCurrentProfile() {
        guard let currentUser = authService.currentUser else { return }
        
        displayName = currentUser.displayName
        
        // Set avatar if it's a predefined one
        if let avatarURL = currentUser.avatarURL,
           !avatarURL.hasPrefix("http://") && !avatarURL.hasPrefix("https://") {
            selectedAvatar = avatarURL
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
#Preview {
    EditProfileView()
        .environmentObject(AuthService.mockAuthenticated)
}
