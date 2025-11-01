//
//  MatchSummarySheetView.swift
//  DanDart
//
//  Match summary view for sheet presentation
//  Reuses components from MatchDetailView and HalveItMatchDetailView
//

import SwiftUI

struct MatchSummarySheetView: View {
    let match: MatchResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        StandardSheetView(
            title: match.gameName == "Halve It" ? "\(match.gameName) - Level \(halveItLevel)" : match.gameName,
            dismissButtonTitle: "Done",
            onDismiss: { dismiss() }
        ) {
            VStack(spacing: 24) {
                // Date
                Text(match.formattedDate)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color("TextSecondary"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Players with MatchPlayerCard
                VStack(spacing: 16) {
                    ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                        MatchPlayerCard(
                            player: player,
                            isWinner: player.id == match.winnerId,
                            playerIndex: originalPlayerIndex(for: player),
                            placement: index + 1,
                            matchFormat: match.matchFormat,
                            gameType: match.gameName
                        )
                    }
                }
                
                // Stats Section
                if !match.players.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Stats")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        // Color key legend
                        FlexibleLayout(spacing: 12) {
                            ForEach(0..<match.players.count, id: \.self) { index in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(playerColor(for: index))
                                        .frame(width: 12, height: 12)
                                    
                                    Text(match.players[index].displayName)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(Color("TextSecondary"))
                                }
                            }
                        }
                        
                        // Game-specific stats
                        if match.gameName == "Halve It" {
                            // Halve-It stats
                            StatCategorySection(
                                label: "Target hit rate (%)",
                                players: match.players,
                                getValue: { Int(calculateTargetHitRate(for: $0) * 100) }
                            )
                        } else {
                            // Countdown (301/501) stats
                            VStack(spacing: 20) {
                                StatCategorySection(
                                    label: "Number of turns",
                                    players: match.players,
                                    getValue: { $0.turns.count }
                                )
                                
                                StatCategorySection(
                                    label: "Average visit",
                                    players: match.players,
                                    getValue: { Int($0.averageScore) },
                                    isDecimal: true,
                                    getDecimalValue: { $0.averageScore }
                                )
                                
                                StatCategorySection(
                                    label: "Highest visit",
                                    players: match.players,
                                    getValue: { highestVisit(for: $0) }
                                )
                                
                                StatCategorySection(
                                    label: "100+ thrown",
                                    players: match.players,
                                    getValue: { count100Plus(for: $0) }
                                )
                                
                                StatCategorySection(
                                    label: "140+ thrown",
                                    players: match.players,
                                    getValue: { count140Plus(for: $0) }
                                )
                                
                                StatCategorySection(
                                    label: "180s thrown",
                                    players: match.players,
                                    getValue: { count180s(for: $0) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                
                // Turn-by-Turn / Round-by-Round Breakdown
                if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        if match.gameName == "Halve It" {
                            // Halve-It Round-by-Round
                            Text("Round-by-Round Breakdown")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            let maxRounds = match.players.map { $0.turns.count }.max() ?? 0
                            
                            ForEach(0..<maxRounds, id: \.self) { roundIndex in
                                let targetDisplay = match.players.first?.turns[safe: roundIndex]?.targetDisplay ?? "?"
                                
                                let playerData = match.players.enumerated().map { playerIndex, player in
                                    let turn = roundIndex < player.turns.count ? player.turns[roundIndex] : nil
                                    let hits = turn?.darts.count ?? 0
                                    let score = turn?.scoreAfter ?? 0
                                    
                                    return HalveItRoundCard.PlayerRoundData(
                                        hits: hits,
                                        score: score,
                                        color: playerColor(for: playerIndex)
                                    )
                                }
                                
                                HalveItRoundCard(
                                    roundNumber: roundIndex + 1,
                                    targetDisplay: targetDisplay,
                                    playerData: playerData
                                )
                            }
                        } else {
                            // Countdown (301/501) Turn-by-Turn
                            Text("Turn-by-Turn Breakdown")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            let maxTurns = match.players.map { $0.turns.count }.max() ?? 0
                            
                            ForEach(0..<maxTurns, id: \.self) { turnIndex in
                                let playerData = match.players.enumerated().map { playerIndex, player in
                                    let turn = turnIndex < player.turns.count ? player.turns[turnIndex] : nil
                                    let darts = turn?.darts.map { $0.displayText } ?? []
                                    let scoreRemaining = turn?.scoreAfter ?? player.startingScore
                                    let isBust = turn?.isBust ?? false
                                    
                                    return ThrowBreakdownCard.PlayerTurnData(
                                        darts: darts,
                                        scoreRemaining: scoreRemaining,
                                        color: playerColor(for: playerIndex),
                                        isBust: isBust
                                    )
                                }
                                
                                ThrowBreakdownCard(
                                    roundNumber: turnIndex + 1,
                                    playerData: playerData
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Helper methods for player sorting
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            // For countdown games (301/501), lower final score is better
            // For Halve-It, higher final score is better
            if match.gameName == "Halve It" {
                return player1.finalScore > player2.finalScore
            } else {
                return player1.finalScore < player2.finalScore
            }
        }
    }
    
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    // Player color mapping
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    // Countdown (301/501) stat helpers
    private func highestVisit(for player: MatchPlayer) -> Int {
        player.turns.map { $0.turnTotal }.max() ?? 0
    }
    
    private func count100Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 100 }.count
    }
    
    private func count140Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 140 }.count
    }
    
    private func count180s(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal == 180 }.count
    }
    
    // Halve-It stat helper - % of individual darts that hit the target
    private func calculateTargetHitRate(for player: MatchPlayer) -> Double {
        // Count total darts thrown across all turns
        let totalDarts = player.turns.reduce(0) { $0 + $1.darts.count }
        guard totalDarts > 0 else { return 0 }
        
        // Count darts that scored points (hit the target)
        // A dart hit if it contributed to the score increase
        let dartsHit = player.turns.reduce(0) { total, turn in
            // If score increased, count the darts that actually scored
            if turn.scoreAfter > turn.scoreBefore {
                return total + turn.darts.filter { $0.value > 0 }.count
            }
            return total
        }
        
        return Double(dartsHit) / Double(totalDarts)
    }
    
    // Get Halve-It difficulty level from metadata
    private var halveItLevel: String {
        guard let difficulty = match.metadata?["difficulty"] else {
            return "Easy" // Default fallback
        }
        // Capitalize first letter for display
        return difficulty.prefix(1).uppercased() + difficulty.dropFirst()
    }
}

// MARK: - Preview

#Preview {
    let bobId = UUID()
    let aliceId = UUID()
    
    MatchSummarySheetView(
        match: MatchResult(
            gameType: "301",
            gameName: "301",
            players: [
                MatchPlayer(
                    id: bobId,
                    displayName: "Bob",
                    nickname: "bob",
                    avatarURL: nil,
                    isGuest: true,
                    finalScore: 0,
                    startingScore: 301,
                    totalDartsThrown: 24,
                    turns: [],
                    legsWon: 0
                ),
                MatchPlayer(
                    id: aliceId,
                    displayName: "Alice",
                    nickname: "alice",
                    avatarURL: nil,
                    isGuest: true,
                    finalScore: 87,
                    startingScore: 301,
                    totalDartsThrown: 24,
                    turns: [],
                    legsWon: 0
                )
            ],
            winnerId: bobId,
            timestamp: Date(),
            duration: 420
        )
    )
}
