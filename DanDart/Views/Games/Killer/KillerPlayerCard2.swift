//
//  KillerPlayerCard2.swift
//  DanDart
//
//  New design for Killer player card:
//  - Target number in rounded container above avatar
//  - Avatar with current player ring
//  - Player name
//  - Larger lives display (14px heart, headline font)
//

import SwiftUI

struct KillerPlayerCard2: View {
    let player: Player
    let assignedNumber: Int
    let isKiller: Bool
    let lives: Int
    let startingLives: Int
    let isCurrentPlayer: Bool
    let animatingKillerActivation: Bool
    let animatingLifeLoss: Bool
    let cardWidth: CGFloat
    
    private var firstName: String {
        player.displayName.split(separator: " ").first.map(String.init) ?? player.displayName
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Target number in rounded container
            Text("#\(assignedNumber)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 44, height: 28)
                .padding(.bottom, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        
                        .fill(isKiller ? AppColor.interactivePrimaryBackground : AppColor.inputBackground)
                )
                .scaleEffect(animatingKillerActivation ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animatingKillerActivation)
            
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
                    .frame(maxWidth: cardWidth)
                
                // Lives display (larger)
                if startingLives > 1 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.justWhite)
                            .scaleEffect(animatingLifeLoss ? 2.0 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.4), value: animatingLifeLoss)
                        Text("\(lives)")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
        }
        .frame(width: cardWidth)
        .padding(.vertical, 0)
        .opacity(lives == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.5), value: lives)
    }
}

#Preview("Killer Player Cards 2") {
    HStack(spacing: 32) {
        // Not Killer, 3 lives
        KillerPlayerCard2(
            player: Player.mockGuest1,
            assignedNumber: 12,
            isKiller: false,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            cardWidth: 64
        )
        
        // Killer, 3 lives, current player
        KillerPlayerCard2(
            player: Player.mockGuest2,
            assignedNumber: 19,
            isKiller: true,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            cardWidth: 64
        )
        
        // Not Killer, 3 lives
        KillerPlayerCard2(
            player: Player(id: UUID(), displayName: "Arthur", nickname: "Arthur", avatarURL: nil),
            assignedNumber: 7,
            isKiller: false,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            cardWidth: 64
        )
        
        // Not Killer, 3 lives
        KillerPlayerCard2(
            player: Player(id: UUID(), displayName: "Tony", nickname: "Tony", avatarURL: nil),
            assignedNumber: 1,
            isKiller: false,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            cardWidth: 64
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
