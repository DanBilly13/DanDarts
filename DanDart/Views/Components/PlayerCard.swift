//
//  PlayerCard.swift
//  DanDart
//
//  Player card component for displaying player info in game setup and selection
//

import SwiftUI

struct PlayerCard: View {
    let player: Player
    let showCheckmark: Bool
    let playerNumber: Int?
    
    init(player: Player, showCheckmark: Bool = false, playerNumber: Int? = nil) {
        self.player = player
        self.showCheckmark = showCheckmark
        self.playerNumber = playerNumber
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Player number (if provided)
            if let _ = playerNumber {
                // Number now shown as a badge on the avatar instead of a leading label
            }

            // Player identity (avatar + name + nickname)
            PlayerIdentity(
                player: player,
                avatarSize: 48,
                spacing: 4,
                showBadge: showCheckmark || playerNumber != nil,
                badgeIcon: "checkmark", // used when showCheckmark is true and no number
                badgeColor: playerNumber != nil ? Color.white : AppColor.interactivePrimaryBackground,
                badgeSize: 16,
                badgeForegroundColor: playerNumber != nil ? Color.black : Color.white,
                badgeText: playerNumber != nil ? String(playerNumber!) : nil
            )
            
            Spacer()
            
            // Right side - Guest badge OR W/L stats
            VStack(alignment: .trailing, spacing: 8) {
                if player.isGuest {
                    // Show "Guest" for guest players
                    Text("Guest")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                } else {
                    // Show stats for connected players
                    if player.totalWins > 0 || player.totalLosses > 0 {
                        // Colored W/L stats: 28W15L (green W, red L)
                        HStack(spacing: 0) {
                            Text("\(player.totalWins)W")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColor.textPrimary)
                            
                            Text("\(player.totalLosses)L")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        
                        Text(player.winRatePercentage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    } else {
                        Text("No games")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        
                        Text("yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
            .padding(.top, 5)
            
        }
        .padding(.leading, 16)
        .padding(.trailing, 32)
        .padding(.vertical, 16)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.inputBackground)
        .clipShape(Capsule())
    }
}

// MARK: - PlayerCard Variants

struct PlayerCardCompact: View {
    let player: Player
    
    var body: some View {
        HStack(spacing: 12) {
            // Player identity (avatar + name + nickname) - compact size
            PlayerIdentity(
                player: player,
                avatarSize: 32,
                nameFont: .system(size: 14, weight: .semibold),
                nicknameFont: .system(size: 12, weight: .medium),
                nicknameColor: AppColor.textSecondary,
                spacing: 2
            )
            
            Spacer()
            
            // Win rate only
            if player.totalGames > 0 {
                Text(player.winRatePercentage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 48)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview
#Preview("Player Card - Guest") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockGuest1)
        PlayerCard(player: Player.mockGuest2)
        PlayerCard(player: Player.mockGuest3)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Player Card - Connected") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1)
        PlayerCard(player: Player.mockConnected2)
        PlayerCard(player: Player.mockConnected3)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Player Card - With Player Numbers") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1, playerNumber: 1)
        PlayerCard(player: Player.mockGuest1, playerNumber: 2)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Player Card - Compact") {
    VStack(spacing: 12) {
        PlayerCardCompact(player: Player.mockConnected1)
        PlayerCardCompact(player: Player.mockConnected2)
        PlayerCardCompact(player: Player.mockGuest1)
        PlayerCardCompact(player: Player.mockGuest3)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Player Card - Dark Mode") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1)
        PlayerCard(player: Player.mockGuest1, playerNumber: 1)
        PlayerCardCompact(player: Player.mockConnected2)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
    .preferredColorScheme(.dark)
}
