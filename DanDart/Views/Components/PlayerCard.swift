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
            if let number = playerNumber {
                Text("\(number)")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextPrimary"))
                    .frame(width: 16)
                    
            }
            
            // Player identity (avatar + name + nickname)
            PlayerIdentity(
                player: player,
                avatarSize: 48,
                spacing: 4
            )
            
            Spacer()
            
            // Right side - Guest badge OR W/L stats
            VStack(alignment: .trailing, spacing: 8) {
                if player.isGuest {
                    // Show "Guest" for guest players
                    Text("Guest")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                } else {
                    // Show stats for connected players
                    if player.totalWins > 0 || player.totalLosses > 0 {
                        // Colored W/L stats: 28W15L (green W, red L)
                        HStack(spacing: 0) {
                            Text("\(player.totalWins)W")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color("AccentSecondary"))
                            
                            Text("\(player.totalLosses)L")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color("AccentPrimary"))
                        }
                        
                        Text(player.winRatePercentage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    } else {
                        Text("No games")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                        
                        Text("yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
            }
            .padding(.top, 5)
            
            // Checkmark (if player is already selected)
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("InputBackground"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("TextSecondary").opacity(0.3), lineWidth: 1)
        )
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
                nicknameColor: Color("AccentSecondary"),
                spacing: 2
            )
            
            Spacer()
            
            // Win rate only
            if player.totalGames > 0 {
                Text(player.winRatePercentage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 48)
        .background(Color("InputBackground"))
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
    .background(Color("BackgroundPrimary"))
}

#Preview("Player Card - Connected") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1)
        PlayerCard(player: Player.mockConnected2)
        PlayerCard(player: Player.mockConnected3)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Player Card - With Player Numbers") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1, playerNumber: 1)
        PlayerCard(player: Player.mockGuest1, playerNumber: 2)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Player Card - Compact") {
    VStack(spacing: 12) {
        PlayerCardCompact(player: Player.mockConnected1)
        PlayerCardCompact(player: Player.mockConnected2)
        PlayerCardCompact(player: Player.mockGuest1)
        PlayerCardCompact(player: Player.mockGuest3)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Player Card - Dark Mode") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1)
        PlayerCard(player: Player.mockGuest1, playerNumber: 1)
        PlayerCardCompact(player: Player.mockConnected2)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
    .preferredColorScheme(.dark)
}
