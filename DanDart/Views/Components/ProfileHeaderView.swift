//
//  ProfileHeaderView.swift
//  Dart Freak
//
//  Reusable profile header component for user and friend profiles
//

import SwiftUI
import PhotosUI

struct ProfileHeaderView<Content: View>: View {
    let player: Player
    let customContent: Content?
    
    init(player: Player, @ViewBuilder customContent: () -> Content) {
        self.player = player
        self.customContent = customContent()
    }
    
    init(player: Player) where Content == EmptyView {
        self.player = player
        self.customContent = nil
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            avatarView
            
            // Name and Handle
            VStack(spacing: 4) {
                Text(player.displayName)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.regular)
                    .foregroundColor(AppColor.textPrimary)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.brandPrimary)
                } else {
                    Text("Guest Player")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            
            // Custom content slot (e.g., Edit Profile button)
            if let customContent = customContent {
                customContent
            }
            
            // Stats Cards
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                // Games Played
                StatCard(
                    title: "Games",
                    value: "\(player.totalGames)",
                    icon: "games"
                )
                
                // Wins
                StatCard(
                    title: "Wins",
                    value: "\(player.totalWins)",
                    icon: "wins"
                )
                
                // Win Rate
                StatCard(
                    title: "Win %",
                    value: player.winRateValue,
                    icon: "win-rate"
                )
                
                // Rank (301/501)
                StatCard(
                    title: "Rank",
                    value: player.rankDisplayName,
                    icon: player.rankIconName
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
