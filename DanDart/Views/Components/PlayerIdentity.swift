//
//  PlayerIdentity.swift
//  Dart Freak
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
    let showBadge: Bool
    let badgeIcon: String
    let badgeColor: Color
    let badgeSize: CGFloat?
    let badgeForegroundColor: Color
    let badgeText: String?
    
    init(
        avatarURL: String?,
        displayName: String,
        nickname: String? = nil,
        isGuest: Bool = false,
        avatarSize: CGFloat = 48,
        nameFont: Font = .system(.title3, design: .rounded).weight(.semibold),
        nicknameFont: Font = .subheadline.weight(.medium),
        nicknameColor: Color = AppColor.textSecondary,
        spacing: CGFloat = 4,
        alignment: HorizontalAlignment = .leading,
        borderColor: Color? = nil,
        showBadge: Bool = false,
        badgeIcon: String = "checkmark",
        badgeColor: Color = AppColor.interactivePrimaryBackground,
        badgeSize: CGFloat? = nil,
        badgeForegroundColor: Color = .white,
        badgeText: String? = nil
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
        self.showBadge = showBadge
        self.badgeIcon = badgeIcon
        self.badgeColor = badgeColor
        self.badgeSize = badgeSize
        self.badgeForegroundColor = badgeForegroundColor
        self.badgeText = badgeText
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            PlayerAvatarView(
                avatarURL: avatarURL,
                size: avatarSize,
                borderColor: borderColor,
                showBadge: showBadge,
                badgeIcon: badgeIcon,
                badgeColor: badgeColor,
                badgeSize: badgeSize,
                badgeForegroundColor: badgeForegroundColor,
                badgeText: badgeText
            )
            
            // Name and nickname
            VStack(alignment: alignment, spacing: spacing) {
                // Display name
                Text(displayName)
                    .font(nameFont)
                    .foregroundColor(AppColor.textPrimary)
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
        nameFont: Font = .system(.callout, design: .rounded).weight(.semibold),
        nicknameFont: Font = .footnote.weight(.medium),
        nicknameColor: Color = AppColor.textSecondary,
        spacing: CGFloat = 4,
        alignment: HorizontalAlignment = .leading,
        borderColor: Color? = nil,
        showBadge: Bool = false,
        badgeIcon: String = "checkmark.circle.fill",
        badgeColor: Color = AppColor.interactivePrimaryBackground,
        badgeSize: CGFloat? = nil,
        badgeForegroundColor: Color = .white,
        badgeText: String? = nil
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
            borderColor: borderColor,
            showBadge: showBadge,
            badgeIcon: badgeIcon,
            badgeColor: badgeColor,
            badgeSize: badgeSize,
            badgeForegroundColor: badgeForegroundColor,
            badgeText: badgeText
        )
    }
    
    /// Initialize from MatchPlayer model
    init(
        matchPlayer: MatchPlayer,
        avatarSize: CGFloat = 48,
        nameFont: Font = .system(.headline, design: .rounded).weight(.semibold),
        nicknameFont: Font = .footnote.weight(.medium),
        nicknameColor: Color = AppColor.textSecondary,
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
            isGuest: false,
            showBadge: true,
            badgeSize: 20,
            badgeForegroundColor: AppColor.justBlack
            
        )
        
        PlayerIdentity(
            avatarURL: "avatar2",
            displayName: "Alice Johnson",
            nickname: "alice",
            isGuest: false,
            borderColor: AppColor.player2
        )
        
        PlayerIdentity(
            avatarURL: nil,
            displayName: "Guest Player",
            nickname: nil,
            isGuest: true
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
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
    .background(AppColor.backgroundPrimary)
}

#Preview("With Border Colors") {
    VStack(spacing: 20) {
        PlayerIdentity(
            avatarURL: "avatar1",
            displayName: "Player 1",
            nickname: "player1",
            borderColor: AppColor.player1
        )
        
        PlayerIdentity(
            avatarURL: "avatar2",
            displayName: "Player 2",
            nickname: "player2",
            borderColor: AppColor.player2
        )
        
        PlayerIdentity(
            avatarURL: "avatar3",
            displayName: "Player 3",
            nickname: "player3",
            borderColor: AppColor.brandPrimary
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
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
    .background(AppColor.backgroundPrimary)
}
