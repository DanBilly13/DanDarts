//
//  AvatarHelper.swift
//  DanDart
//
//  Avatar utility functions for consistent avatar display across the app
//

import SwiftUI

struct AvatarHelper {
    /// Returns a list of available avatar asset names
    static let availableAvatars = ["avatar1", "avatar2", "avatar3", "avatar4"]
    
    /// Returns a random avatar asset name
    static func randomAvatar() -> String {
        return availableAvatars.randomElement() ?? "avatar1"
    }
    
    /// Creates an avatar view with consistent styling
    static func avatarView(for avatarURL: String?, size: CGFloat = 48, placeholder: String = "person.circle.fill") -> some View {
        Group {
            if let avatarURL = avatarURL {
                Image(avatarURL)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: placeholder)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Player Avatar View Component

struct PlayerAvatarView: View {
    let avatarURL: String?
    let size: CGFloat
    let placeholder: String
    let borderColor: Color?
    
    init(avatarURL: String?, size: CGFloat = 48, placeholder: String = "person.circle.fill", borderColor: Color? = nil) {
        self.avatarURL = avatarURL
        self.size = size
        self.placeholder = placeholder
        self.borderColor = borderColor
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color("InputBackground"))
                .frame(width: size, height: size)
            
            if let avatarURL = avatarURL {
                let _ = print("🖼️ PlayerAvatarView - avatarURL: \(avatarURL)")
                // Check if it's a URL or local asset
                if avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                    let _ = print("🌐 Loading remote URL: \(avatarURL)")
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
                            Image(systemName: placeholder)
                                .font(.system(size: size * 0.5, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Local asset - use Image
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }
            } else {
                Image(systemName: placeholder)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .overlay(
            Group {
                if let borderColor = borderColor {
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                }
            }
        )
    }
}

// MARK: - Preview
#Preview("Player Avatar Views") {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            PlayerAvatarView(avatarURL: "avatar1", size: 48)
            PlayerAvatarView(avatarURL: "avatar2", size: 48)
            PlayerAvatarView(avatarURL: "avatar3", size: 48)
            PlayerAvatarView(avatarURL: "avatar4", size: 48)
        }
        
        HStack(spacing: 16) {
            PlayerAvatarView(avatarURL: nil, size: 48)
            PlayerAvatarView(avatarURL: "avatar1", size: 32)
            PlayerAvatarView(avatarURL: "avatar2", size: 80, borderColor: Color("AccentPrimary"))
            PlayerAvatarView(avatarURL: "avatar3", size: 120)
        }
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
