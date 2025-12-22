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
        VStack(spacing: 4) {
            
            VStack (spacing: -4){
                // Avatar (with double ring for current player)
                PlayerAvatarWithRing(
                    avatarURL: player.avatarURL,
                    isCurrentPlayer: isCurrentPlayer,
                    ringColor: playerColor,
                    size: 64
                )
                
                // Target number in rounded container with gun icon
                HStack(spacing: 2) {
                    // Gun icon in fixed-size container to prevent rotation affecting layout
                    ZStack {
                        Color.clear
                            .frame(width: 17, height: 17)
                        
                        Image("Gun")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 17)
                            .foregroundColor(isKiller ? AppColor.justBlack : AppColor.justWhite)
                            //.foregroundColor(AppColor.justWhite)
                            .opacity(isKiller ? 1.0 : 0.3)
                            .rotationEffect(.degrees(animatingGunSpin ? 1125 : -25)) // 45° default, +1080° (3 spins) when animating
                            .animation(.easeInOut(duration: 0.6), value: animatingGunSpin)
                    }
                    
                    Text("\(assignedNumber)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.black)
                        .foregroundColor(isKiller ? AppColor.justBlack : AppColor.justWhite)
                        //.foregroundColor(AppColor.justBlack)
                }
                .frame(height: 32)
                .frame(width: 48)
                .padding(.horizontal, 8)
                .padding(.bottom, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isKiller ? playerColor : AppColor.inputBackground)
                )
                //.scaleEffect(animatingKillerActivation ? 1.3 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: animatingKillerActivation)
                
            }
            
            
           
            
            VStack(spacing: 2) {
                // Name
                Text(firstName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(playerColor)
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
            animatingGunSpin: false,
            playerIndex: 0,
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
            animatingGunSpin: false,
            playerIndex: 1,
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
            animatingGunSpin: false,
            playerIndex: 2,
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
            animatingGunSpin: false,
            playerIndex: 3,
            cardWidth: 64
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
