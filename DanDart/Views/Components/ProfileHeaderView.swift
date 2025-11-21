//
//  ProfileHeaderView.swift
//  DanDart
//
//  Reusable profile header component for user and friend profiles
//

import SwiftUI
import PhotosUI

struct ProfileHeaderView: View {
    let player: Player
    
    init(player: Player) {
        self.player = player
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            avatarView
            
            // Name and Handle
            VStack(spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.brandPrimary)
                } else {
                    Text("Guest Player")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            
            // Stats Cards
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                // Games Played
                StatCard(
                    title: "Games",
                    value: "\(player.totalGames)",
                    icon: "target"
                )
                
                // Wins
                StatCard(
                    title: "Wins",
                    value: "\(player.totalWins)",
                    icon: "trophy.fill"
                )
                
                // Win Rate
                StatCard(
                    title: "Win Rate",
                    value: player.winRatePercentage,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
    }
    
    // MARK: - Avatar View
    
    private var avatarView: some View {
        AsyncAvatarImage(
            avatarURL: player.avatarURL,
            size: 120,
            placeholderIcon: "person.circle.fill"
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ProfileHeaderView(player: Player.mockConnected1)
        
        Spacer()
        
        ProfileHeaderView(player: Player.mockGuest1)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
