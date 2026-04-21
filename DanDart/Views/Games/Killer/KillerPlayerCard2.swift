//
//  KillerPlayerCard2.swift
//  Dart Freak
//
//  New design for Killer player card:
//  - Split badge: left (icon) + right (number)
//  - Not Killer: Gun (20% white) + X icon on white 20% background
//  - Killer: Gun (white) on player color background, no X
//  - Avatar with current player ring
//  - Player name (player color)
//  - Lives display (hearts only, no numbers)
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
    let animatingGunSpin: Bool
    let playerIndex: Int
    let cardWidth: CGFloat
    
    private var firstName: String {
        player.displayName.split(separator: " ").first.map(String.init) ?? player.displayName
    }
    
    // Get player color based on index
    private var playerColor: Color {
        switch playerIndex {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            VStack (spacing: 4) {
                // Avatar (with double ring for current player)
                PlayerAvatarWithRing(
                    avatarURL: player.avatarURL,
                    isCurrentPlayer: isCurrentPlayer,
                    ringColor: playerColor,
                    size: 64
                )
                
                // Name
                Text(firstName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(playerColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: cardWidth)
            }
            
            
            // Target badge: split into left (icon) and right (number) containers
            HStack(spacing: 0) {
                // Left container: Gun + X icon
                ZStack {
                    // Gun icon (behind X when not killer)
                    Image("Gun")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17)
                        .foregroundColor(AppColor.justWhite)
                        .opacity(isKiller ? 1.0 : 0.2)
                        .rotationEffect(.degrees(animatingGunSpin ? 1125 : 0))
                        .animation(.easeInOut(duration: 0.6), value: animatingGunSpin)
                    
                    // X icon (only when not killer)
                    if !isKiller {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColor.backgroundPrimary)
                    }
                }
                .frame(width: 32, height: 32)
                .background(isKiller ? playerColor : AppColor.justWhite.opacity(0.2))
                
                // Right container: Number
                Text("\(assignedNumber)")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(isKiller ? playerColor : AppColor.backgroundPrimary)
                    .frame(width: 44, height: 32)
                    .background(AppColor.justWhite)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            
            // Lives display (hearts only, no numbers)
            if startingLives > 1 {
                HStack(spacing: -1) {
                    ForEach(0..<lives, id: \.self) { _ in
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.justWhite)
                    }
                }
                .scaleEffect(animatingLifeLoss ? 1.3 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.4), value: animatingLifeLoss)
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
            assignedNumber: 20,
            isKiller: false,
            lives: 5,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 0,
            cardWidth: 64
        )
        
        // Not Killer, current player, 2 lives
        KillerPlayerCard2(
            player: Player.mockGuest2,
            assignedNumber: 17,
            isKiller: false,
            lives: 2,
            startingLives: 3,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 1,
            cardWidth: 64
        )
        
        // Killer, 3 lives
        KillerPlayerCard2(
            player: Player(id: UUID(), displayName: "Arthur", nickname: "Arthur", avatarURL: nil),
            assignedNumber: 5,
            isKiller: true,
            lives: 3,
            startingLives: 3,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 2,
            cardWidth: 64
        )
        
        // Killer, current player, 1 life
        KillerPlayerCard2(
            player: Player(id: UUID(), displayName: "Tony", nickname: "Tony", avatarURL: nil),
            assignedNumber: 12,
            isKiller: true,
            lives: 1,
            startingLives: 3,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 3,
            cardWidth: 64
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
