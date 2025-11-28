//
//  AsyncAvatarImage.swift
//  DanDart
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
                    // Local asset or file path - use UIImage to avoid URL parsing
                    if let uiImage = UIImage(named: avatarURL) ?? (avatarURL.hasPrefix("/") ? UIImage(contentsOfFile: avatarURL) : nil) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
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
