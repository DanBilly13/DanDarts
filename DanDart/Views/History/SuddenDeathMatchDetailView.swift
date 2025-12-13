//
//  SuddenDeathMatchDetailView.swift
//  DanDart
//
//  Detailed view of a completed Sudden Death match
//

import SwiftUI

struct SuddenDeathMatchDetailView: View {
    let match: MatchResult
    var isSheet: Bool = false  // Set to true when presented as sheet
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if isSheet {
            // Sheet presentation
            NavigationStack {
                ScrollView {
                    contentView
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                }
                .background(AppColor.backgroundPrimary)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbarRole(.editor)
                .toolbar {
                    TopBarSub(
                        title: match.gameName,
                        subtitle: match.formattedDate
                    ) {
                        TopBarCloseButton {
                            dismiss()
                        }
                    }
                }
            }
        } else {
            // Navigation push - use standard ScrollView
            ScrollView {
                contentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            }
            .background(AppColor.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarRole(.editor)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                TopBarSub(
                    title: match.gameName,
                    subtitle: match.formattedDate
                ) {
                    TopBarCloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Shared content for both contexts
    private var contentView: some View {
        VStack(spacing: 24) {
            // Players and Rankings (no scores shown)
            playersSection
            
            // Round-by-Round Stats Section
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                statsComparisonSection
            }
            
            // Turn-by-Turn Breakdown
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                turnBreakdownSection
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var playersSection: some View {
        VStack(spacing: 16) {
            // Sort players: winner first, then by final score (highest for Sudden Death)
            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                SuddenDeathMatchPlayerCard(
                    player: player,
                    isWinner: player.id == match.winnerId,
                    playerIndex: originalPlayerIndex(for: player),
                    placement: index + 1
                )
            }
        }
    }
    
    // Sorted players: winner first, then by final score (higher is better for Sudden Death)
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            // Winner always comes first
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            
            // Then sort by final score (higher is better for Sudden Death)
            return player1.finalScore > player2.finalScore
        }
    }
    
    // Get original player index for color assignment
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    // Get player color based on index
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    private var statsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Color key legend (wraps to 2 rows if needed)
            FlexibleLayout(spacing: 12) {
                ForEach(0..<match.players.count, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(playerColor(for: index))
                            .frame(width: 12, height: 12)
                        
                        Text(match.players[index].displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
            
            // Round-by-Round Breakdown
            roundByRoundSection
        }
        .padding(.vertical, 16)
    }
    
    private var roundByRoundSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Get max rounds across all players
            let maxRounds = match.players.map { $0.turns.count }.max() ?? 0
            
            ForEach(0..<maxRounds, id: \.self) { index in
                let roundNumber = index + 1
                roundSection(roundNumber: roundNumber, totalRounds: maxRounds)
            }
        }
    }
    
    @ViewBuilder
    private func roundSection(roundNumber: Int, totalRounds: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round title
            Text("Round \(roundNumber)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
            
            // Player bars for this round
            VStack(spacing: 8) {
                ForEach(match.players.indices, id: \.self) { playerIndex in
                    let player = match.players[playerIndex]
                    
                    // Check if player is still alive in this round
                    if isPlayerAliveInRound(player: player, roundNumber: roundNumber) {
                        playerRoundBar(
                            player: player,
                            playerIndex: playerIndex,
                            roundNumber: roundNumber,
                            isLastRound: roundNumber == totalRounds
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func playerRoundBar(player: MatchPlayer, playerIndex: Int, roundNumber: Int, isLastRound: Bool) -> some View {
        let turnIndex = roundNumber - 1
        let score = turnIndex < player.turns.count ? player.turns[turnIndex].turnTotal : 0
        let livesLostUpToThisRound = countLivesLost(player: player, upToRound: roundNumber)
        let isWinner = player.id == match.winnerId && isLastRound
        
        HStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar (gray)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.inputBackground)
                        .frame(height: 12)
                    
                    // Filled bar (player's color)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(playerColor(for: playerIndex))
                        .frame(width: geometry.size.width * (CGFloat(score) / 180.0), height: 12)
                }
            }
            .frame(height: 12)
            
            // Skulls and icons section - fixed width based on starting lives
            HStack(spacing: 8) {
                // Skulls for lives lost
                HStack(spacing: 8) {
                    ForEach(0..<livesLostUpToThisRound, id: \.self) { _ in
                        Image("skull")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(AppColor.textSecondary)
                            .frame(width: 16, height: 16)
                    }
                }
                .frame(width: CGFloat(startingLives * 16 + max(0, startingLives - 1) * 8), alignment: .leading)
                
                // Winner crown (if applicable)
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                        .frame(width: 16, height: 18)
                }
            }
            
            // Score value - fixed width container
            Text("\(score)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 27, height: 18, alignment: .trailing)
        }
    }
    
    // MARK: - Helper Methods
    
    private var startingLives: Int {
        guard let livesString = match.metadata?["starting_lives"],
              let lives = Int(livesString) else {
            return 1 // Default to 1 life
        }
        return lives
    }
    
    private func countLivesLost(player: MatchPlayer, upToRound: Int) -> Int {
        let turnsToCheck = min(upToRound, player.turns.count)
        return player.turns.prefix(turnsToCheck).filter { $0.isBust }.count
    }
    
    private func isPlayerAliveInRound(player: MatchPlayer, roundNumber: Int) -> Bool {
        let livesLostBeforeThisRound = countLivesLost(player: player, upToRound: roundNumber - 1)
        return livesLostBeforeThisRound < startingLives
    }
    
    
    private var turnBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turn-by-Turn Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)
            
            // Get max turns across all players
            let maxTurns = match.players.map { $0.turns.count }.max() ?? 0
            
            ForEach(0..<maxTurns, id: \.self) { roundIndex in
                let playerData = match.players.enumerated().map { playerIndex, player in
                    let turn = roundIndex < player.turns.count ? player.turns[roundIndex] : nil
                    let darts = turn?.darts.map { $0.displayText } ?? []
                    // For Sudden Death, scoreAfter represents accumulated points
                    let scoreRemaining: Int
                    if let turn = turn {
                        scoreRemaining = turn.scoreAfter
                    } else if roundIndex > 0, let previousTurn = player.turns.last {
                        scoreRemaining = previousTurn.scoreAfter
                    } else {
                        scoreRemaining = player.startingScore
                    }
                    let isBust = turn?.isBust ?? false
                    
                    return ThrowBreakdownCard.PlayerTurnData(
                        darts: darts,
                        scoreRemaining: scoreRemaining,
                        color: playerColor(for: playerIndex),
                        isBust: isBust
                    )
                }
                
                ThrowBreakdownCard(
                    roundNumber: roundIndex + 1,
                    playerData: playerData
                )
            }
        }
    }
}

// MARK: - Sudden Death Match Player Card (Placement Only)

struct SuddenDeathMatchPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let playerIndex: Int
    let placement: Int
    
    // Get border color based on player index
    var borderColor: Color {
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
        HStack(spacing: 16) {
            // Player identity (avatar + name + nickname)
            PlayerIdentity(
                matchPlayer: player,
                avatarSize: 48
            )
            
            Spacer()
            
            // Right side - Only placement (no score)
            VStack(spacing: 4) {
                // Top row: crown or placement
                Group {
                    if isWinner {
                        // Crown icon for winner
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    } else {
                        // Placement text
                        Text(placementText)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .frame(height: 24, alignment: .bottom)
                
                // Bottom row: "WINNER" text for winner, empty for others
                Group {
                    if isWinner {
                        Text("WINNER")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                            .tracking(0.5)
                    }
                }
                .frame(height: 16, alignment: .center)
            }
            .frame(width: 60)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(AppColor.inputBackground)
        .cornerRadius(12)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    // Calculate placement text (2nd, 3rd, 4th, etc.)
    private var placementText: String {
        switch placement {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(placement)th"
        }
    }
}

// MARK: - Preview

#Preview("Sudden Death Match") {
    NavigationStack {
        SuddenDeathMatchDetailView(match: MatchResult.mockSuddenDeath)
    }
}
