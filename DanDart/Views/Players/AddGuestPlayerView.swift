//
//  AddGuestPlayerView.swift
//  Dart Freak
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
        NavigationStack {
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
                        
                      
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(AppColor.surfacePrimary)
            .safeAreaInset(edge: .bottom) {
                BottomActionContainer {
                    AppButton(
                        role: .primary,
                        controlSize: .large,
                        isDisabled: !isSaveEnabled || isLoading,
                        action: savePlayer
                    ) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(AppColor.textOnPrimary)
                                    .frame(width: 16, height: 16)
                            }
                            Text(isLoading ? "Creating..." : "Save Player")
                        }
                    }
                }
            }
            .navigationTitle("Add Guest Player")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
            }
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

            selectedAvatarImage = uiImage.resized(toMaxDimension: 512)
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
