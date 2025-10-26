//
//  AvatarSelectionView.swift
//  DanDart
//
//  Reusable avatar selection component with photo picker and predefined avatars
//

import SwiftUI
import PhotosUI

struct AvatarSelectionView: View {
    @Binding var selectedAvatar: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedAvatarImage: UIImage?
    
    // MARK: - Avatar Options
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
        VStack(spacing: 20) {
            // Upload Photo Option
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color("InputBackground"))
                            .frame(width: 100, height: 100)
                        
                        if let selectedImage = selectedAvatarImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(Color("AccentPrimary"))
                                
                                Text("Upload Photo")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(selectedAvatarImage != nil ? Color("AccentPrimary") : Color("TextSecondary").opacity(0.3), lineWidth: 2)
                    )
                    
                    if selectedAvatarImage != nil {
                        Button(action: {
                            selectedAvatarImage = nil
                            selectedPhotoItem = nil
                        }) {
                            Text("Remove Photo")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color("TextSecondary").opacity(0.3))
                    .frame(height: 1)
                
                Text("OR")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
                    .padding(.horizontal, 8)
                
                Rectangle()
                    .fill(Color("TextSecondary").opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 32)
            
            // Predefined Avatar Options
            VStack(spacing: 12) {
                Text("Choose an Avatar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 20) {
                    ForEach(avatarOptions, id: \.id) { option in
                        Button(action: {
                            selectedAvatar = option.id
                            // Clear photo selection when choosing predefined avatar
                            selectedAvatarImage = nil
                            selectedPhotoItem = nil
                        }) {
                            AvatarOptionView(
                                option: option,
                                isSelected: selectedAvatar == option.id && selectedAvatarImage == nil,
                                size: 70
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var selectedAvatar = "avatar1"
        @State private var selectedPhotoItem: PhotosPickerItem?
        @State private var selectedAvatarImage: UIImage?
        
        var body: some View {
            ScrollView {
                AvatarSelectionView(
                    selectedAvatar: $selectedAvatar,
                    selectedPhotoItem: $selectedPhotoItem,
                    selectedAvatarImage: $selectedAvatarImage
                )
                .padding()
            }
            .background(Color("BackgroundPrimary"))
        }
    }
    
    return PreviewWrapper()
}
