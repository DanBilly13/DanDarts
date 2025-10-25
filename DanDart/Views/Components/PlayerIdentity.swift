//
//  PlayerIdentity.swift
//  DanDart
//
//  Reusable player identity component (avatar + name + nickname)
//

import SwiftUI

/// Displays player avatar, display name, and optional nickname
struct PlayerIdentity: View {
    let avatarURL: String?
    let displayName: String
    let nickname: String?
    let isGuest: Bool
    let avatarSize: CGFloat
    let nameFont: Font
    let nicknameFont: Font
    let nicknameColor: Color
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let borderColor: Color?
    
    init(
        avatarURL: String?,
        displayName: String,
        nickname: String? = nil,
        isGuest: Bool = false,
        avatarSize: CGFloat = 48,
        nameFont: Font = .system(.title3, design: .rounded).weight(.semibold),
        nicknameFont: Font = .subheadline.weight(.medium),
        nicknameColor: Color = Color("TextSecondary"),
        spacing: CGFloat = 4,
        alignment: HorizontalAlignment = .leading,
        borderColor: Color? = nil
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.nickname = nickname
        self.isGuest = isGuest
        self.avatarSize = avatarSize
        self.nameFont = nameFont
        self.nicknameFont = nicknameFont
        self.nicknameColor = nicknameColor
        self.spacing = spacing
        self.alignment = alignment
        self.borderColor = borderColor
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            PlayerAvatarView(
                avatarURL: avatarURL,
                size: avatarSize,
                borderColor: borderColor
            )
            
            // Name and nickname
            VStack(alignment: alignment, spacing: spacing) {
                // Display name
                Text(displayName)
                    .font(nameFont)
                    .foregroundColor(Color("TextPrimary"))
                    .lineLimit(1)
                
                // Nickname (if provided)
                if let nickname = nickname {
                    Text("@\(nickname)")
                        .font(nicknameFont)
                        .foregroundColor(nicknameColor)
                        .lineLimit(1)
                }
            }
        }
    }
}

// MARK: - Convenience Initializers

extension PlayerIdentity {
    /// Initialize from Player model
    init(
        player: Player,
        avatarSize: CGFloat = 48,
        nameFont: Font = .system(.title3, design: .rounded).weight(.semibold),
        nicknameFont: Font = .subheadline.weight(.medium),
        nicknameColor: Color = Color("TextSecondary"),
        spacing: CGFloat = 4,
        alignment: HorizontalAlignment = .leading,
        borderColor: Color? = nil
    ) {
        self.init(
            avatarURL: player.avatarURL,
            displayName: player.displayName,
            nickname: player.nickname,
            isGuest: player.isGuest,
            avatarSize: avatarSize,
            nameFont: nameFont,
            nicknameFont: nicknameFont,
            nicknameColor: nicknameColor,
            spacing: spacing,
            alignment: alignment,
            borderColor: borderColor
        )
    }
    
    /// Initialize from MatchPlayer model
    init(
        matchPlayer: MatchPlayer,
        avatarSize: CGFloat = 48,
        nameFont: Font = .system(.title3, design: .rounded).weight(.semibold),
        nicknameFont: Font = .subheadline.weight(.medium),
        nicknameColor: Color = Color("TextSecondary"),
        spacing: CGFloat = 4,
        alignment: HorizontalAlignment = .leading,
        borderColor: Color? = nil
    ) {
        self.init(
            avatarURL: matchPlayer.avatarURL,
            displayName: matchPlayer.displayName,
            nickname: matchPlayer.nickname,
            isGuest: matchPlayer.isGuest,
            avatarSize: avatarSize,
            nameFont: nameFont,
            nicknameFont: nicknameFont,
            nicknameColor: nicknameColor,
            spacing: spacing,
            alignment: alignment,
            borderColor: borderColor
        )
    }
}

// MARK: - Preview

#Preview("Standard Size") {
    VStack(spacing: 20) {
        PlayerIdentity(
            avatarURL: "avatar1",
            displayName: "Dan Billingham",
            nickname: "danbilly",
            isGuest: false
        )
        
        PlayerIdentity(
            avatarURL: "avatar2",
            displayName: "Alice Johnson",
            nickname: "alice",
            isGuest: false,
            borderColor: Color("AccentSecondary")
        )
        
        PlayerIdentity(
            avatarURL: nil,
            displayName: "Guest Player",
            nickname: nil,
            isGuest: true
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Different Sizes") {
    VStack(spacing: 20) {
        PlayerIdentity(
            avatarURL: "avatar1",
            displayName: "Dan Billingham",
            nickname: "danbilly",
            avatarSize: 32,
            nameFont: .system(size: 14, weight: .semibold),
            nicknameFont: .system(size: 12, weight: .medium)
        )
        
        PlayerIdentity(
            avatarURL: "avatar2",
            displayName: "Alice Johnson",
            nickname: "alice",
            avatarSize: 48
        )
        
        PlayerIdentity(
            avatarURL: "avatar3",
            displayName: "Bob Smith",
            nickname: "bobby",
            avatarSize: 68,
            nameFont: .system(size: 20, weight: .bold),
            nicknameFont: .system(size: 16, weight: .medium)
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("With Border Colors") {
    VStack(spacing: 20) {
        PlayerIdentity(
            avatarURL: "avatar1",
            displayName: "Player 1",
            nickname: "player1",
            borderColor: Color("AccentPrimary")
        )
        
        PlayerIdentity(
            avatarURL: "avatar2",
            displayName: "Player 2",
            nickname: "player2",
            borderColor: Color("AccentSecondary")
        )
        
        PlayerIdentity(
            avatarURL: "avatar3",
            displayName: "Player 3",
            nickname: "player3",
            borderColor: Color("AccentTertiary")
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Center Aligned") {
    VStack(spacing: 20) {
        PlayerIdentity(
            avatarURL: "avatar1",
            displayName: "Dan Billingham",
            nickname: "danbilly",
            alignment: .center
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
