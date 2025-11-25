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
    
    @State private var scrollPosition: String?
    
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
        ZStack(alignment: .center) {
            GeometryReader { proxy in
                let itemSize: CGFloat = 64                // avatar diameter
                let selectorInner: CGFloat = itemSize     // the avatar we want centered under the ring
                let sideInset: CGFloat = max((proxy.size.width - selectorInner) / 2, 0)
            
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        // Camera Upload Option (First in scroll)
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(AppColor.inputBackground)
                                    .frame(width: itemSize, height: itemSize)
                            
                                if let selectedImage = selectedAvatarImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: itemSize, height: itemSize)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(AppColor.interactivePrimaryBackground)
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
                                selectedAvatarImage = nil
                                selectedPhotoItem = nil
                            }) {
                                AvatarOptionView(
                                    option: option,
                                    isSelected: false,
                                    size: itemSize
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .scaleEffect(scrollPosition == option.id ? 1.25 : 0.8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollPosition)
                            .id(option.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollPosition(id: $scrollPosition)
                .scrollTargetBehavior(.viewAligned)
            }
            
            // Fixed Selection Circle Overlay (On Top)
            Circle()
                .stroke(AppColor.interactivePrimaryBackground, lineWidth: 3)
                .frame(width: 80, height: 80)
                .allowsHitTesting(false) // Let touches pass through to avatars below
        }
        .frame(height: 100)
        .onAppear {
            // Set initial scroll position based on current selection
            if selectedAvatarImage != nil {
                scrollPosition = "camera"
            } else {
                scrollPosition = selectedAvatar
            }
        }
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
            .background(AppColor.backgroundPrimary)
        }
    }
    
    return PreviewWrapper()
}
