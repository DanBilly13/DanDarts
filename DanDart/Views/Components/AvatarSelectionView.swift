//
//  AvatarSelectionView.swift
//  Dart Freak
//
//  Reusable avatar selection component with photo picker and predefined avatars
//

import SwiftUI
import PhotosUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#else
struct UIImage { }
#endif

#if canImport(ImagePlayground)
import ImagePlayground
#endif

struct AvatarSelectionView: View {
    @Binding var selectedAvatar: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedAvatarImage: UIImage?
    
    @State private var scrollPosition: String?
    @State private var showAIGenerationSheet: Bool = false
    @State private var showImagePlaygroundSheet: Bool = false
    @State private var showAINotAvailableAlert: Bool = false
    
    private var isAppleIntelligenceAvailable: Bool {
        if #available(iOS 18.1, *) {
            #if canImport(ImagePlayground)
            return ImagePlaygroundViewController.isAvailable
            #else
            return false
            #endif
        } else {
            return false
        }
    }
    
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

    private var content: some View {
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

                        Button(action: {
                            scrollPosition = "ai"
                            if isAppleIntelligenceAvailable {
                                showImagePlaygroundSheet = true
                            } else {
                                showAIGenerationSheet = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(AppColor.inputBackground)
                                    .frame(width: itemSize, height: itemSize)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(isAppleIntelligenceAvailable ? AppColor.interactivePrimaryBackground : AppColor.textSecondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .scaleEffect(scrollPosition == "ai" ? 1.25 : 0.8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scrollPosition)
                        .id("ai")
                    
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
        .sheet(isPresented: $showAIGenerationSheet) {
            AIGeneratedAvatarSheetView(
                selectedAvatar: $selectedAvatar,
                selectedPhotoItem: $selectedPhotoItem,
                selectedAvatarImage: $selectedAvatarImage
            )
        }
        .alert("Not available on this device", isPresented: $showAINotAvailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Apple Intelligence avatar generation requires a supported device and iOS 18 or later.")
        }
    }

    var body: some View {
        #if canImport(ImagePlayground)
        if #available(iOS 18.1, *) {
            if ImagePlaygroundViewController.isAvailable {
                content
                    .imagePlaygroundSheet(
                        isPresented: $showImagePlaygroundSheet,
                        concepts: [],
                        sourceImage: nil,
                        onCompletion: { url in
                            Task {
                                guard let data = try? Data(contentsOf: url),
                                      let image = UIImage(data: data) else {
                                    await MainActor.run {
                                        showImagePlaygroundSheet = false
                                    }
                                    return
                                }

                                await MainActor.run {
                                    showImagePlaygroundSheet = false
                                    selectedAvatarImage = image
                                    selectedPhotoItem = nil
                                    selectedAvatar = ""
                                }
                            }
                        },
                        onCancellation: {
                            showImagePlaygroundSheet = false
                        }
                    )
            } else {
                content
            }
        } else {
            content
        }
        #else
        content
        #endif
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
