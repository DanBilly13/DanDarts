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

struct AvatarSelectionViewV2: View {
    @Binding var selectedAvatar: String
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var selectedAvatarImage: UIImage?

    @State private var showCameraSheet: Bool = false
    @State private var showImagePlaygroundSheet: Bool = false
    @State private var showAIGenerationSheet: Bool = false

    @State private var isLaunchingImagePlayground: Bool = false
    @State private var imagePlaygroundLoaderRotationDegrees: Double = 0

    private var isImagePlaygroundAvailable: Bool {
        #if os(iOS)
        if #available(iOS 18.1, *) {
            #if canImport(ImagePlayground)
            return ImagePlaygroundViewController.isAvailable
            #else
            return false
            #endif
        }
        #endif
        return false
    }

    private let avatarOptions: [AvatarOption] = [
        AvatarOption(id: "avatar1", type: .asset),
        AvatarOption(id: "avatar2", type: .asset),
        AvatarOption(id: "avatar3", type: .asset),
        AvatarOption(id: "avatar4", type: .asset),
        AvatarOption(id: "avatar5", type: .asset),
        AvatarOption(id: "avatar6", type: .asset),
        AvatarOption(id: "avatar7", type: .asset),
        AvatarOption(id: "avatar8", type: .asset),
        /*AvatarOption(id: "person.circle.fill", type: .symbol),
        AvatarOption(id: "person.crop.circle.fill", type: .symbol),
        AvatarOption(id: "figure.wave.circle.fill", type: .symbol)*/
    ]

    var body: some View {
        VStack(spacing: 16) {
            preview

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    aiButton
                    cameraButton
                    libraryButton

                    ForEach(avatarOptions, id: \.id) { option in
                        Button(action: {
                            selectPresetAvatar(option)
                        }) {
                            AvatarOptionView(
                                option: option,
                                isSelected: false,
                                size: 64
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
        }
        #if os(iOS)
        .sheet(isPresented: $showCameraSheet) {
            CameraImagePicker { image in
                #if canImport(UIKit)
                selectedAvatarImage = image.resized(toMaxDimension: 512)
                #else
                selectedAvatarImage = image
                #endif
                selectedPhotoItem = nil
                selectedAvatar = ""
            }
        }
        .sheet(isPresented: $showAIGenerationSheet) {
            AIGeneratedAvatarSheetView(
                selectedAvatar: $selectedAvatar,
                selectedPhotoItem: $selectedPhotoItem,
                selectedAvatarImage: $selectedAvatarImage
            )
        }
        #endif
        #if canImport(ImagePlayground)
        .applyIfAvailable(isImagePlaygroundAvailable) { view in
            view.imagePlaygroundSheet(
                isPresented: $showImagePlaygroundSheet,
                concepts: [],
                sourceImage: nil,
                onCompletion: { url in
                    Task {
                        guard let data = try? Data(contentsOf: url),
                              let image = UIImage(data: data) else {
                            await MainActor.run {
                                stopImagePlaygroundLaunchFeedback()
                                showImagePlaygroundSheet = false
                            }
                            return
                        }

                        await MainActor.run {
                            stopImagePlaygroundLaunchFeedback()
                            showImagePlaygroundSheet = false
                            #if canImport(UIKit)
                            selectedAvatarImage = image.resized(toMaxDimension: 512)
                            #else
                            selectedAvatarImage = image
                            #endif
                            selectedPhotoItem = nil
                            selectedAvatar = ""
                        }
                    }
                },
                onCancellation: {
                    stopImagePlaygroundLaunchFeedback()
                    showImagePlaygroundSheet = false
                }
            )
        }
        #endif
    }

    private var preview: some View {
        ZStack {
            Circle()
                .fill(AppColor.inputBackground)
                .frame(width: 140, height: 140)

            if let image = selectedAvatarImage {
                #if canImport(UIKit)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                #elseif canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
                #else
                EmptyView()
                #endif
            } else if !selectedAvatar.isEmpty {
                #if canImport(UIKit)
                if let uiImage = UIImage(named: selectedAvatar) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else {
                    Image(systemName: selectedAvatar)
                        .font(.system(size: 64, weight: .regular))
                        .foregroundColor(AppColor.textSecondary)
                }
                #else
                if let nsImage = NSImage(named: NSImage.Name(selectedAvatar)) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else {
                    Image(systemName: selectedAvatar)
                        .font(.system(size: 64, weight: .regular))
                        .foregroundColor(AppColor.textSecondary)
                }
                #endif
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64, weight: .regular))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .overlay(
            Circle()
                .stroke(AppColor.interactivePrimaryBackground, lineWidth: 3)
        )
    }

    private var aiButton: some View {
        Button(action: {
            if isImagePlaygroundAvailable {
                startImagePlaygroundLaunchFeedback()
                showImagePlaygroundSheet = true
            } else {
                showAIGenerationSheet = true
            }
        }) {
            actionIcon(systemName: "sparkles", isEnabled: isImagePlaygroundAvailable)
                .overlay {
                    if isLaunchingImagePlayground {
                        Circle()
                            .trim(from: 0.0, to: 0.7)
                            .stroke(
                                AppColor.interactivePrimaryBackground,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round)
                            )
                            .frame(width: 62, height: 62)
                            .rotationEffect(.degrees(imagePlaygroundLoaderRotationDegrees))
                            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: imagePlaygroundLoaderRotationDegrees)
                            .allowsHitTesting(false)
                            .onAppear {
                                imagePlaygroundLoaderRotationDegrees = 360
                            }
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var cameraButton: some View {
        Button(action: {
            showCameraSheet = true
        }) {
            actionIcon(systemName: "camera.fill", isEnabled: true)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var libraryButton: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
            actionIcon(systemName: "photo.on.rectangle", isEnabled: true)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func actionIcon(systemName: String, isEnabled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(AppColor.inputBackground)
                .frame(width: 64, height: 64)

            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isEnabled ? AppColor.interactivePrimaryBackground : AppColor.textSecondary.opacity(0.6))
        }
    }

    private func selectPresetAvatar(_ option: AvatarOption) {
        selectedAvatar = option.id
        selectedAvatarImage = nil
        selectedPhotoItem = nil
    }

    private func startImagePlaygroundLaunchFeedback() {
        isLaunchingImagePlayground = true
        imagePlaygroundLoaderRotationDegrees = 0
    }

    private func stopImagePlaygroundLaunchFeedback() {
        isLaunchingImagePlayground = false
        imagePlaygroundLoaderRotationDegrees = 0
    }
}

private extension View {
    @ViewBuilder
    func applyIfAvailable<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#if DEBUG
#Preview("AvatarSelectionViewV2") {
    AvatarSelectionViewV2(
        selectedAvatar: .constant("person.circle.fill"),
        selectedPhotoItem: .constant(nil),
        selectedAvatarImage: .constant(nil)
    )
    .padding()
}
#endif
