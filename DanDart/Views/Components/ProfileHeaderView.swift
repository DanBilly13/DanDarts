//
//  ProfileHeaderView.swift
//  DanDart
//
//  Reusable profile header component for user and friend profiles
//

import SwiftUI

struct ProfileHeaderView: View {
    let player: Player
    let showEditButton: Bool
    let onEditTapped: (() -> Void)?
    
    init(player: Player, showEditButton: Bool = false, onEditTapped: (() -> Void)? = nil) {
        self.player = player
        self.showEditButton = showEditButton
        self.onEditTapped = onEditTapped
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color("InputBackground"))
                    .frame(width: 120, height: 120)
                
                if let avatarURL = player.avatarURL {
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                }
                
                // Edit button overlay (for user profile)
                if showEditButton {
                    Button(action: {
                        onEditTapped?()
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(Color("AccentPrimary"))
                            .background(
                                Circle()
                                    .fill(Color("BackgroundPrimary"))
                                    .frame(width: 28, height: 28)
                            )
                    }
                    .offset(x: 42, y: 42)
                }
            }
            .overlay(
                Circle()
                    .stroke(Color("AccentPrimary").opacity(0.3), lineWidth: 2)
            )
            
            // Name and Handle
            VStack(spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                } else {
                    Text("Guest Player")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            
            // Stats Cards
            HStack(spacing: 12) {
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
}

// MARK: - Preview

#Preview {
    VStack {
        ProfileHeaderView(player: Player.mockConnected1)
        
        Spacer()
        
        ProfileHeaderView(player: Player.mockConnected1, showEditButton: true) {
            print("Edit tapped")
        }
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
