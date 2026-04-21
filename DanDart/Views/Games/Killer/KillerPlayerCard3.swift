//
//  KillerPlayerCard3.swift
//  Dart Freak
//
//  Alternative design for Killer player card:
//  - Number badge at top
//  - Avatar with optional ring (current player)
//  - Gun badge overlay (bottom-right, only when killer)
//  - Player name below avatar
//  - Lives in rows (hearts only)
//

import SwiftUI

struct KillerPlayerCard3: View {
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
            // Number badge at top
            Text("\(assignedNumber)")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(isKiller ? AppColor.backgroundPrimary : AppColor.justWhite)
                .frame(width: 56, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isKiller ? playerColor : AppColor.justWhite.opacity(0.0))
                )
            
            // Avatar with optional gun badge overlay
            ZStack(alignment: .bottomTrailing) {
                PlayerAvatarWithRing(
                    avatarURL: player.avatarURL,
                    isCurrentPlayer: isCurrentPlayer,
                    ringColor: playerColor,
                    size: 64
                )
                
                // Gun badge (only when killer)
                if isKiller {
                    ZStack {
                        Circle()
                            .fill(playerColor)
                            .frame(width: 28, height: 28)
                        
                        Image("Gun")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18)
                            .foregroundColor(AppColor.justBlack)
                            .rotationEffect(.degrees(animatingGunSpin ? 1125 : 0))
                            .animation(.easeInOut(duration: 0.6), value: animatingGunSpin)
                    }
                    .offset(x: 4, y: 4)
                }
            }
            
            // Name
            Text(firstName)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(playerColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: cardWidth)
            
            // Lives display (hearts in rows)
            if startingLives > 1 {
                livesView
            }
        }
        .frame(width: cardWidth)
        .padding(.vertical, 0)
        .opacity(lives == 0 ? 0 : 1)
        .animation(.easeOut(duration: 0.5), value: lives)
    }
    
    // Lives arranged in rows (max 3 per row)
    // Shows all hearts: filled (white) for remaining lives, InputBackground for lost lives
    @ViewBuilder
    private var livesView: some View {
        let heartsPerRow = 3
        let allHearts = Array(0..<startingLives)
        
        VStack(spacing: 2) {
            ForEach(0..<((startingLives + heartsPerRow - 1) / heartsPerRow), id: \.self) { rowIndex in
                HStack(spacing: -1) {
                    ForEach(allHearts.filter { $0 / heartsPerRow == rowIndex }, id: \.self) { heartIndex in
                        let isAlive = heartIndex < lives
                        let isJustLost = heartIndex == lives && animatingLifeLoss
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isAlive ? AppColor.justWhite : AppColor.inputBackground)
                            .heartPopAnimation(active: isJustLost)
                    }
                }
            }
        }
    }
}

#Preview("Killer Player Cards 3") {
    HStack(spacing: 32) {
        // Not Killer, 5 lives
        KillerPlayerCard3(
            player: Player.mockGuest1,
            assignedNumber: 20,
            isKiller: false,
            lives: 5,
            startingLives: 5,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 0,
            cardWidth: 80
        )
        
        // Not Killer, current player, 3 lives
        KillerPlayerCard3(
            player: Player.mockGuest2,
            assignedNumber: 20,
            isKiller: false,
            lives: 3,
            startingLives: 5,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 1,
            cardWidth: 80
        )
        
        // Killer, 5 lives
        KillerPlayerCard3(
            player: Player(id: UUID(), displayName: "Arthur", nickname: "Arthur", avatarURL: nil),
            assignedNumber: 20,
            isKiller: true,
            lives: 5,
            startingLives: 5,
            isCurrentPlayer: false,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 2,
            cardWidth: 80
        )
        
        // Killer, current player, 2 lives
        KillerPlayerCard3(
            player: Player(id: UUID(), displayName: "Tony", nickname: "Tony", avatarURL: nil),
            assignedNumber: 20,
            isKiller: true,
            lives: 2,
            startingLives: 5,
            isCurrentPlayer: true,
            animatingKillerActivation: false,
            animatingLifeLoss: false,
            animatingGunSpin: false,
            playerIndex: 3,
            cardWidth: 80
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
