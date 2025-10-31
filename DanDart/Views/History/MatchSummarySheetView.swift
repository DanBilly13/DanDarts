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
            title: match.gameName,
            dismissButtonTitle: "Done",
            onDismiss: { dismiss() }
        ) {
            // Route to the appropriate content based on game type
            if match.gameName == "Halve It" {
                HalveItMatchContent(match: match)
            } else {
                CountdownMatchContent(match: match)
            }
        }
    }
}

// MARK: - Halve-It Match Content

private struct HalveItMatchContent: View {
    let match: MatchResult
    
    var body: some View {
        VStack(spacing: 24) {
            // Date
            Text(match.formattedDate)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color("TextSecondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Players
            VStack(spacing: 16) {
                ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                    MatchPlayerCard(
                        player: player,
                        isWinner: player.id == match.winnerId,
                        playerIndex: originalPlayerIndex(for: player),
                        placement: index + 1,
                        matchFormat: match.matchFormat
                    )
                }
            }
            
            // Stats (reuse from HalveItMatchDetailView)
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
                    
                    // Game accuracy
                    StatCategorySection(
                        label: "Game accuracy (%)",
                        players: match.players,
                        getValue: { Int(calculateAccuracy(for: $0) * 100) }
                    )
                }
                .padding(.vertical, 16)
            }
            
            // Round-by-Round Breakdown
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
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
                }
            }
        }
    }
    
    // Helpers from HalveItMatchDetailView
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            return player1.finalScore > player2.finalScore
        }
    }
    
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return Color("AccentSecondary")
        case 1: return Color("AccentPrimary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    private func calculateAccuracy(for player: MatchPlayer) -> Double {
        let totalDarts = player.totalDartsThrown
        guard totalDarts > 0 else { return 0 }
        let totalHits = player.turns.filter { $0.scoreAfter > $0.scoreBefore }.count * 2
        return Double(totalHits) / Double(totalDarts)
    }
}

// MARK: - Countdown Match Content (301/501)

private struct CountdownMatchContent: View {
    let match: MatchResult
    
    var body: some View {
        VStack(spacing: 24) {
            // Date
            Text(match.formattedDate)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color("TextSecondary"))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Players
            VStack(spacing: 16) {
                ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                    MatchPlayerCard(
                        player: player,
                        isWinner: player.id == match.winnerId,
                        playerIndex: originalPlayerIndex(for: player),
                        placement: index + 1,
                        matchFormat: match.matchFormat
                    )
                }
            }
            
            // Stats (reuse from MatchDetailView)
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
                    
                    VStack(spacing: 20) {
                        // Number of turns
                        StatCategorySection(
                            label: "Number of turns",
                            players: match.players,
                            getValue: { $0.turns.count }
                        )
                        
                        // Average visit
                        StatCategorySection(
                            label: "Average visit",
                            players: match.players,
                            getValue: { Int($0.averageScore) },
                            isDecimal: true,
                            getDecimalValue: { $0.averageScore }
                        )
                        
                        // Highest visit
                        StatCategorySection(
                            label: "Highest visit",
                            players: match.players,
                            getValue: { highestVisit(for: $0) }
                        )
                        
                        // 100+ thrown
                        StatCategorySection(
                            label: "100+ thrown",
                            players: match.players,
                            getValue: { count100Plus(for: $0) }
                        )
                    }
                }
                .padding(.vertical, 16)
            }
            
            // Turn-by-Turn Breakdown
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
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
    
    // Helpers from MatchDetailView
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            return player1.finalScore < player2.finalScore
        }
    }
    
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    private func highestVisit(for player: MatchPlayer) -> Int {
        player.turns.map { $0.turnTotal }.max() ?? 0
    }
    
    private func count100Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 100 }.count
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
