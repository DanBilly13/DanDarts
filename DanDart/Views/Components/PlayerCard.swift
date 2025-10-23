//
//  PlayerCard.swift
//  DanDart
//
//  Player card component for displaying player info in game setup and selection
//

import SwiftUI

struct PlayerCard: View {
    let player: Player
    let showRemoveButton: Bool
    let onRemove: (() -> Void)?
    
    init(player: Player, showRemoveButton: Bool = false, onRemove: (() -> Void)? = nil) {
        self.player = player
        self.showRemoveButton = showRemoveButton
        self.onRemove = onRemove
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar (48pt, left)
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 48,
                placeholderIcon: player.isGuest ? "person.circle.fill" : "person.circle"
            )
            
            // Display name and nickname (center)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !player.isGuest {
                        Text("@\(player.nickname)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                    } else {
                        Text("Guest")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    
                    if player.isGuest {
                        Image(systemName: "person.badge.minus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                }
                .lineLimit(1)
            }
            
            Spacer()
            
            // W/L stats (right)
            VStack(alignment: .trailing, spacing: 2) {
                if player.totalGames > 0 {
                    Text("\(player.totalWins)W - \(player.totalLosses)L")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color("TextPrimary"))
                    
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
            
            // Remove button (if enabled)
            if showRemoveButton {
                Button(action: {
                    onRemove?()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .moodCard(.red, radius: 48)
        .overlay(
            RoundedRectangle(cornerRadius: 48)
                .stroke(Color("TextSecondary").opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 48))
    }
}

// MARK: - PlayerCard Variants

struct PlayerCardCompact: View {
    let player: Player
    
    var body: some View {
        HStack(spacing: 12) {
            // Smaller avatar (32pt)
            ZStack {
                Circle()
                    .fill(Color("InputBackground"))
                    .frame(width: 32, height: 32)
                
                if let avatarURL = player.avatarURL {
                    // Player with avatar from assets
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    // No avatar - show placeholder
                    Image(systemName: player.isGuest ? "person.circle.fill" : "person.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(player.isGuest ? Color("TextSecondary") : Color("AccentPrimary"))
                }
            }
            
            // Name only
            VStack(alignment: .leading, spacing: 2) {
                Text(player.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                    .lineLimit(1)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("AccentSecondary"))
                        .lineLimit(1)
                }
            }
            
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

#Preview("Player Card - With Remove Button") {
    VStack(spacing: 16) {
        PlayerCard(player: Player.mockConnected1, showRemoveButton: true) {
            print("Remove \(Player.mockConnected1.displayName)")
        }
        PlayerCard(player: Player.mockGuest1, showRemoveButton: true) {
            print("Remove \(Player.mockGuest1.displayName)")
        }
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
        PlayerCard(player: Player.mockGuest1, showRemoveButton: true) {
            print("Remove player")
        }
        PlayerCardCompact(player: Player.mockConnected2)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
    .preferredColorScheme(.dark)
}
