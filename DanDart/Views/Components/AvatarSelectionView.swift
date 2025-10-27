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
    
    @State private var scrollPosition: String? = "camera"
    
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
        AvatarOption(id: "figure.wave.circle.fill", type: .symbol)
    ]
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Horizontal Scrolling Row (Behind)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    // Camera Upload Option (First in scroll)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Color("InputBackground"))
                                .frame(width: 64, height: 64)
                            
                            if let selectedImage = selectedAvatarImage {
                                // Show uploaded image
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 64, height: 64)
                                    .clipShape(Circle())
                            } else {
                                // Show camera icon
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .scaleEffect(scrollPosition == "camera" ? 1.25 : 0.8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollPosition)
                    .id("camera")
                    
                    // Predefined Avatar Options
                    ForEach(avatarOptions, id: \.id) { option in
                        Button(action: {
                            selectedAvatar = option.id
                            // Clear photo selection when choosing predefined avatar
                            selectedAvatarImage = nil
                            selectedPhotoItem = nil
                        }) {
                            AvatarOptionView(
                                option: option,
                                isSelected: false,
                                size: 64
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(scrollPosition == option.id ? 1.25 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollPosition)
                        .id(option.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.leading, 8)
                .padding(.trailing, UIScreen.main.bounds.width - 96) // Leave space for last items to scroll into circle
            }
            .scrollPosition(id: $scrollPosition)
            .scrollTargetBehavior(.viewAligned)
            
            // Fixed Selection Circle Overlay (On Top)
            Circle()
                .stroke(Color("AccentPrimary"), lineWidth: 3)
                .frame(width: 80, height: 80)
                .allowsHitTesting(false) // Let touches pass through to avatars below
        }
        .frame(height: 100)
        .onChange(of: selectedAvatarImage) { _, newImage in
            // When custom image is selected, scroll to camera position
            if newImage != nil {
                scrollPosition = "camera"
            }
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
