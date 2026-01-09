//
//  KillerPlayerCard.swift
//  Dart Freak
//
//  Player card for Killer game showing:
//  - Killer chip (30% or 100% opacity)
//  - Avatar with current player ring
//  - Player name
//  - Assigned number (🎯 D4 format)
//  - Lives (❤️ 3 format)
//

import SwiftUI

struct KillerPlayerCard: View {
    let player: Player
    let assignedNumber: Int
    let isKiller: Bool
    let lives: Int
    let startingLives: Int
    let isCurrentPlayer: Bool
    let animatingKillerActivation: Bool
    let animatingLifeLoss: Bool
    
    private var firstName: String {
        player.displayName.split(separator: " ").first.map(String.init) ?? player.displayName
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Killer chip in fixed-height container
            ZStack {
                Image(systemName: "light.beacon.max.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.interactiveTertiaryBackground)
                /*Chip(
                    title: "KLR",
                    foregroundColor: AppColor.textOnPrimary,
                    backgroundColor: .red
                )*/
                .opacity(isKiller ? 1.0 : 0.3)
                .scaleEffect(animatingKillerActivation ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animatingKillerActivation)
            }
            .frame(height: 32)
            
            // Avatar (with double ring for current player)
            PlayerAvatarWithRing(
                avatarURL: player.avatarURL,
                isCurrentPlayer: isCurrentPlayer,
                size: 64
            )
            VStack(spacing: 2) {
                // Name
                Text(firstName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 56)
                
                // Assigned number with dart icon
                HStack(spacing: 0) {
                    Image(systemName: "dot.scope")
                        .font(.system(size: 14, weight:
                                .bold))
                        .foregroundStyle(AppColor.justWhite)
                   // Text("D\(assignedNumber)")
                    Text("\(assignedNumber)")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.justWhite)
                }
                
                // Lives display
                LivesDisplay(lives: lives, startingLives: startingLives, animatingLifeLoss: animatingLifeLoss)
            }
           
        }
        .padding(.vertical, 0)
        .opacity(lives == 0 ? 0 : 1) // Fade out when eliminated
        .animation(.easeOut(duration: 0.5), value: lives)
    }
}

#Preview("Killer Player Cards") {
    HStack(spacing: 32) {
        // Not Killer, 3 lives
        KillerPlayerCard(
            player: Player.mockGuest1,
            assignedNumber: 4,
            isKiller: false,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false
        )
        
        // Killer, 2 lives, current player
        KillerPlayerCard(
            player: Player.mockGuest2,
            assignedNumber: 17,
            isKiller: true,
            lives: 2,
            startingLives: 3,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false
        )
        
        // Killer, 1 life
        KillerPlayerCard(
            player: Player(id: UUID(), displayName: "Alice", nickname: "Alice", avatarURL: nil),
            assignedNumber: 20,
            isKiller: true,
            lives: 1,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
