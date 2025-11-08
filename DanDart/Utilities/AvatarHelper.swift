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
                // Check if it's a URL, file path, or local asset
                if avatarURL.hasPrefix("http://") || avatarURL.hasPrefix("https://") {
                    // Remote URL - use CachedAsyncImage for better performance
                    if let url = URL(string: avatarURL) {
                        CachedAsyncImage(url: url) {
                            ProgressView()
                                .frame(width: size, height: size)
                        }
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .onAppear {
                            print("🌐 Loading remote URL: \(avatarURL)")
                        }
                    } else {
                        // Invalid URL - show placeholder
                        Image(systemName: placeholder)
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                } else if avatarURL.hasPrefix("/") || avatarURL.contains("/Documents/") {
                    // File path - load from local storage
                    let fileURL = URL(fileURLWithPath: avatarURL)
                    if let imageData = try? Data(contentsOf: fileURL),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .onAppear {
                                print("✅ Loaded avatar from file: \(avatarURL)")
                            }
                    } else {
                        // Failed to load file - show placeholder
                        Image(systemName: placeholder)
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .onAppear {
                                print("⚠️ Failed to load avatar from file: \(avatarURL)")
                                print("   File exists: \(FileManager.default.fileExists(atPath: avatarURL))")
                            }
                    }
                } else {
                    // Local asset - use Image
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .onAppear {
                            print("🎨 Loading from asset: \(avatarURL)")
                        }
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
