//
//  AsyncAvatarImage.swift
//  Dart Freak
//
//  Async image loader for avatars - supports both local assets and remote URLs
//

import SwiftUI

struct AsyncAvatarImage: View {
    let avatarURL: String?
    let size: CGFloat
    let placeholderIcon: String
    
    init(
        avatarURL: String?,
        size: CGFloat = 48,
        placeholderIcon: String = "person.circle.fill"
    ) {
        self.avatarURL = avatarURL
        self.size = size
        self.placeholderIcon = placeholderIcon
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.inputBackground)
                .frame(width: size, height: size)
            
            if let avatarURL = avatarURL, !avatarURL.isEmpty {
                // Check if it's a URL or local asset
                if avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                    // Remote URL - use AsyncImage
                    AsyncImage(url: URL(string: avatarURL)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: size, height: size)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipShape(Circle())
                        case .failure:
                            // Failed to load - show placeholder
                            Image(systemName: placeholderIcon)
                                .font(.system(size: size * 0.5, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Check if this is a file path (starts with "/" or contains "/Documents/" or "/tmp/")
                    let isFilePath = avatarURL.hasPrefix("/") || avatarURL.contains("/Documents/") || avatarURL.contains("/tmp/")
                    
                    // Check if this is an SF Symbol (contains "." like "person.circle.fill" but not a file path)
                    let isSFSymbol = avatarURL.contains(".") && !isFilePath
                    
                    if isSFSymbol {
                        // SF Symbol avatar - use consistent 55% sizing
                        Image(systemName: avatarURL)
                            .font(.system(size: size * 0.55, weight: .regular))
                            .foregroundColor(AppColor.textSecondary)
                            .frame(width: size, height: size)
                    } else if isFilePath {
                        // File path - load from local storage using Data for reliability
                        FilePathAvatarView(
                            avatarURL: avatarURL,
                            size: size,
                            placeholderIcon: placeholderIcon
                        )
                    } else if let uiImage = UIImage(named: avatarURL) {
                        // Local asset (avatar1, avatar2, etc.)
                        let isPredefinedAsset = avatarURL.hasPrefix("avatar")
                        
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: isPredefinedAsset ? .fit : .fill)
                            .frame(width: size, height: size)
                            .scaleEffect(isPredefinedAsset ? 1.1 : 1.0) // Scale up predefined assets slightly to fill circle
                            .clipShape(Circle())
                    } else {
                        // Asset/file not found - show placeholder
                        Image(systemName: placeholderIcon)
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            } else {
                // No avatar - show placeholder
                Image(systemName: placeholderIcon)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
    }
}

// MARK: - File Path Avatar View

private struct FilePathAvatarView: View {
    let avatarURL: String
    let size: CGFloat
    let placeholderIcon: String
    
    @State private var loadedImage: UIImage?
    @State private var didAttemptLoad = false
    
    var body: some View {
        Group {
            if let loadedImage = loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: placeholderIcon)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .onAppear {
            if !didAttemptLoad {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        didAttemptLoad = true
        
        // Try original path first
        var fileURL = URL(fileURLWithPath: avatarURL)
        var imageData: Data?
        
        // If file doesn't exist at original path, try reconstructing with current Documents directory
        if !FileManager.default.fileExists(atPath: avatarURL) {
            // Extract filename from path
            let filename = (avatarURL as NSString).lastPathComponent
            
            // Get current Documents directory
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let avatarsDirectory = documentsDirectory.appendingPathComponent("guest_avatars")
                let reconstructedURL = avatarsDirectory.appendingPathComponent(filename)
                
                if FileManager.default.fileExists(atPath: reconstructedURL.path) {
                    fileURL = reconstructedURL
                    imageData = try? Data(contentsOf: fileURL)
                }
            }
        } else {
            imageData = try? Data(contentsOf: fileURL)
        }
        
        if let imageData = imageData,
           let uiImage = UIImage(data: imageData) {
            loadedImage = uiImage
        }
    }
}

// MARK: - Preview
#Preview("Local Asset Avatar") {
    VStack(spacing: 20) {
        AsyncAvatarImage(avatarURL: "avatar1", size: 48)
        AsyncAvatarImage(avatarURL: "avatar2", size: 64)
        AsyncAvatarImage(avatarURL: "avatar3", size: 80)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Remote URL Avatar") {
    VStack(spacing: 20) {
        AsyncAvatarImage(
            avatarURL: "https://lh3.googleusercontent.com/a/default-user",
            size: 48
        )
        AsyncAvatarImage(
            avatarURL: "https://lh3.googleusercontent.com/a/default-user",
            size: 64
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("No Avatar") {
    VStack(spacing: 20) {
        AsyncAvatarImage(avatarURL: nil, size: 48)
        AsyncAvatarImage(avatarURL: nil, size: 64)
        AsyncAvatarImage(avatarURL: nil, size: 80)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
