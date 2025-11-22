//
//  AddGuestPlayerView.swift
//  DanDart
//
//  Sheet for adding new guest players with display name and nickname validation
//

import SwiftUI
import Foundation
import PhotosUI

struct AddGuestPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Form state
    @State private var displayName: String = ""
    @State private var nickname: String = ""
    @State private var selectedAvatar: String = "avatar1" // Default to first avatar
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarImage: UIImage?
    
    // Validation state
    @State private var displayNameError: String = ""
    @State private var nicknameError: String = ""
    @State private var isLoading: Bool = false
    
    // Callback for when player is created
    let onPlayerCreated: (Player) -> Void
    
    init(onPlayerCreated: @escaping (Player) -> Void) {
        self.onPlayerCreated = onPlayerCreated
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Add Guest Player")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("Create a local player profile")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                
                // Form
                VStack(spacing: 24) {
                    // Avatar Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Profile Picture")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                        
                        AvatarSelectionView(
                            selectedAvatar: $selectedAvatar,
                            selectedPhotoItem: $selectedPhotoItem,
                            selectedAvatarImage: $selectedAvatarImage
                        )
                    }
                    // Display Name Field
                    DartTextField(
                        label: "Display Name",
                        placeholder: "Enter full name",
                        text: $displayName,
                        errorMessage: displayNameError.isEmpty ? nil : displayNameError,
                        textContentType: .name,
                        autocapitalization: .words,
                        autocorrectionDisabled: true
                    )
                    .onChange(of: displayName) { _, newValue in
                        validateDisplayName(newValue)
                    }
                    
                    // Nickname Field
                    VStack(alignment: .leading, spacing: 8) {
                        DartTextField(
                            label: "Nickname",
                            placeholder: "Enter nickname",
                            text: $nickname,
                            errorMessage: nicknameError.isEmpty ? nil : nicknameError,
                            textContentType: .nickname,
                            autocapitalization: .never,
                            autocorrectionDisabled: true
                        )
                        .onChange(of: nickname) { _, newValue in
                            validateNickname(newValue)
                        }
                        
                        Text("Used for quick identification during games")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.leading, 2)
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    AppButton(
                        role: .primary,
                        isDisabled: !isSaveEnabled || isLoading,
                        action: savePlayer
                    ) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Creating..." : "Save Player")
                        }
                    }

                    AppButton(
                        role: .tertiary,
                        isDisabled: isLoading,
                        action: { dismiss() }
                    ) {
                        Text("Cancel")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .background(AppColor.backgroundPrimary)
            .navigationBarBackButtonHidden(true)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await handlePhotoSelection(newItem)
                }
            }
        }
    }
    
    // MARK: - Validation Logic
    
    private func validateDisplayName(_ name: String) {
        displayNameError = ""
        
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayNameError = "Display name is required"
        } else if name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            displayNameError = "Display name must be at least 2 characters"
        } else if name.count > 50 {
            displayNameError = "Display name must be less than 50 characters"
        }
    }
    
    private func validateNickname(_ nick: String) {
        nicknameError = ""
        
        if nick.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nicknameError = "Nickname is required"
        } else if nick.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            nicknameError = "Nickname must be at least 2 characters"
        } else if nick.count > 20 {
            nicknameError = "Nickname must be less than 20 characters"
        } else if !nick.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) {
            nicknameError = "Nickname can only contain letters, numbers, and underscores"
        }
    }
    
    private var isSaveEnabled: Bool {
        return displayNameError.isEmpty &&
               nicknameError.isEmpty &&
               !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                return
            }
            
            selectedAvatarImage = uiImage
        } catch {
            print("Failed to load photo: \(error.localizedDescription)")
        }
    }
    
    private func savePlayer() {
        guard isSaveEnabled else { return }
        
        isLoading = true
        
        // Simulate a brief loading state for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Determine avatar URL
            var avatarURL = selectedAvatar
            
            // If custom image was selected, save it to local storage
            if let customImage = selectedAvatarImage {
                let playerId = UUID()
                if let savedPath = GuestPlayerStorageManager.shared.saveCustomAvatar(image: customImage, for: playerId) {
                    avatarURL = savedPath
                    print("✅ Saved custom avatar for guest player")
                } else {
                    print("⚠️ Failed to save custom avatar, using default")
                }
                
                // Create player with the saved avatar path
                let newPlayer = Player(
                    id: playerId,
                    displayName: trimmedDisplayName,
                    nickname: trimmedNickname,
                    avatarURL: avatarURL,
                    isGuest: true
                )
                
                // Save guest player to local storage
                GuestPlayerStorageManager.shared.saveGuestPlayer(newPlayer)
                
                onPlayerCreated(newPlayer)
            } else {
                // No custom image, use predefined avatar
                let newPlayer = Player.createGuestWithAvatar(
                    displayName: trimmedDisplayName,
                    nickname: trimmedNickname,
                    avatarURL: avatarURL
                )
                
                // Save guest player to local storage
                GuestPlayerStorageManager.shared.saveGuestPlayer(newPlayer)
                
                onPlayerCreated(newPlayer)
            }
            
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("Add Guest Player") {
    AddGuestPlayerView { player in
        print("Created player: \(player.displayName) (@\(player.nickname))")
    }
}

#Preview("Avatar Options Grid") {
    VStack {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            ForEach(0..<8) { index in
                let isAsset = index < 4
                let avatarId = isAsset ? "avatar\(index + 1)" : ["person.circle.fill", "person.crop.circle.fill", "figure.wave.circle.fill", "person.2.circle.fill"][index - 4]
                let option = AvatarOption(id: avatarId, type: isAsset ? .asset : .symbol)
                
                AvatarOptionView(
                    option: option,
                    isSelected: index == 0,
                    size: 60
                )
            }
        }
        .padding()
    }
    .background(Color.black)
}
