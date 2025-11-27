//
//  PlayerAvatarWithRing.swift
//  DanDart
//
//  Reusable avatar component with current player ring indicator
//  Used in: Sudden Death, Knockout, Killer
//

import SwiftUI

struct PlayerAvatarWithRing: View {
    let avatarURL: String?
    let isCurrentPlayer: Bool
    let size: CGFloat
    
    init(avatarURL: String?, isCurrentPlayer: Bool, size: CGFloat = 64) {
        self.avatarURL = avatarURL
        self.isCurrentPlayer = isCurrentPlayer
        self.size = size
    }
    
    var body: some View {
        ZStack {
            if isCurrentPlayer {
                // Outer accent ring
                Circle()
                    .stroke(AppColor.interactiveSecondaryBackground, lineWidth: 2)
                    .frame(width: size, height: size)
                
                // Inner black ring
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .frame(width: size - 4, height: size - 4)
                
                // Avatar inside
                AsyncAvatarImage(
                    avatarURL: avatarURL,
                    size: size - 8
                )
            } else {
                // No ring, just avatar
                AsyncAvatarImage(
                    avatarURL: avatarURL,
                    size: size
                )
            }
        }
    }
}

#Preview("Current Player") {
    VStack(spacing: 24) {
        PlayerAvatarWithRing(
            avatarURL: "avatar1",
            isCurrentPlayer: true,
            size: 64
        )
        
        PlayerAvatarWithRing(
            avatarURL: "avatar2",
            isCurrentPlayer: false,
            size: 64
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
