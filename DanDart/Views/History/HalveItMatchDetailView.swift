//
//  HalveItMatchDetailView.swift
//  DanDart
//
//  Match detail view for Halve It games
//  Uses same layout as 301/501 matches
//

import SwiftUI

struct HalveItMatchDetailView: View {
    let match: MatchResult
    var isSheet: Bool = false  // Set to true when presented as sheet
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if isSheet {
            // Sheet presentation - use StandardSheetView
            StandardSheetView(
                title: "\(match.gameName) - Level \(halveItLevel)",
                dismissButtonTitle: "Done",
                onDismiss: { dismiss() }
            ) {
                contentView
            }
        } else {
            // Navigation push - use standard ScrollView
            ScrollView {
                contentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("\(match.gameName) - Level \(halveItLevel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
        }
    }
    
    // Shared content for both contexts
    private var contentView: some View {
        VStack(spacing: 24) {
            // Date and Time
            dateHeader
            
            // Players and Scores
            playersSection
            
            // Stats Section
            if !match.players.isEmpty {
                statsComparisonSection
            }
            
            // Round-by-Round Breakdown
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                roundBreakdownSection
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var dateHeader: some View {
        Text(match.formattedDate)
            .font(.subheadline.weight(.medium))
            .foregroundColor(Color("TextSecondary"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var playersSection: some View {
        VStack(spacing: 16) {
            // Sort players: winner first, then by final score (highest for Halve-It)
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
    }
    
    // Sorted players: winner first, then by final score (higher is better for Halve-It)
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            // Winner always comes first
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            
            // Then sort by final score (higher is better for Halve-It)
            return player1.finalScore > player2.finalScore
        }
    }
    
    // Get original player index for color assignment
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    private var statsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats title
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
                // Game accuracy (only stat bar for Halve-It)
                StatCategorySection(
                    label: "Target hit rate (%)",
                    players: match.players,
                    getValue: { Int(calculateTargetHitRate(for: $0) * 100) }
                )
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Stats Helpers
    
    // Calculate target hit rate - % of individual darts that hit the target
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
    
    private func highestRound(for player: MatchPlayer) -> Int {
        player.turns.map { $0.scoreAfter - $0.scoreBefore }.max() ?? 0
    }
    
    private func timesHalved(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.scoreAfter < $0.scoreBefore }.count
    }
    
    private var roundBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Round-by-Round Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            // Show rounds (assuming 6 rounds for Halve-It)
            let maxRounds = match.players.map { $0.turns.count }.max() ?? 0
            
            ForEach(0..<maxRounds, id: \.self) { roundIndex in
                // Get target display from first player's turn (all players have same target per round)
                let targetDisplay = match.players.first?.turns[safe: roundIndex]?.targetDisplay ?? "?"
                
                let playerData = match.players.enumerated().map { playerIndex, player in
                    let turn = roundIndex < player.turns.count ? player.turns[roundIndex] : nil
                    
                    // Create hit sequence showing which specific darts hit (true) or missed (false)
                    let hitSequence: [Bool] = turn?.darts.map { $0.value > 0 } ?? []
                    
                    // Count only darts that actually hit the target (scored points)
                    let hits = hitSequence.filter { $0 }.count
                    
                    // Show cumulative score (total score after this round)
                    // Halve-It is about building up points, so we show the running total
                    let score = turn?.scoreAfter ?? 0
                    
                    return HalveItRoundCard.PlayerRoundData(
                        hits: hits,
                        score: score,
                        color: playerColor(for: playerIndex),
                        hitSequence: hitSequence
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
    
    // Get player color based on index
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return Color("AccentSecondary")
        case 1: return Color("AccentPrimary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
}

// MARK: - Preview

#Preview("2 Players") {
    let bobId = UUID()
    let aliceId = UUID()
    
    NavigationView {
        HalveItMatchDetailView(
            match: MatchResult(
                gameType: "Halve It",
                gameName: "Halve It",
                players: [
                    MatchPlayer(
                        id: bobId,
                        displayName: "Bob",
                        nickname: "bob",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 174,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 80, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 80, scoreAfter: 95, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 95, scoreAfter: 107, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 107, scoreAfter: 121, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [], scoreBefore: 121, scoreAfter: 61, isBust: false), // Halved
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 61, scoreAfter: 186, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: aliceId,
                        displayName: "Alice",
                        nickname: "alice",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 187,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 40, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 40, scoreAfter: 50, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 50, scoreAfter: 86, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [], scoreBefore: 86, scoreAfter: 43, isBust: false), // Halved
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 43, scoreAfter: 71, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 71, scoreAfter: 96, isBust: false)
                        ],
                        legsWon: 0
                    )
                ],
                winnerId: bobId,
                timestamp: Date(),
                duration: 420
            )
        )
    }
}

#Preview("3 Players") {
    let player1Id = UUID()
    let player2Id = UUID()
    let player3Id = UUID()
    
    NavigationView {
        HalveItMatchDetailView(
            match: MatchResult(
                gameType: "Halve It",
                gameName: "Halve It",
                players: [
                    MatchPlayer(
                        id: player1Id,
                        displayName: "Dan",
                        nickname: "dan",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 210,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 80, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 80, scoreAfter: 95, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 95, scoreAfter: 119, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 119, scoreAfter: 290, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2), MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 290, scoreAfter: 346, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1)], scoreBefore: 346, scoreAfter: 496, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: player2Id,
                        displayName: "Sarah",
                        nickname: "sarah",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 156,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 40, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 40, scoreAfter: 50, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 50, scoreAfter: 86, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 86, scoreAfter: 143, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2), MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 143, scoreAfter: 199, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 25, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 199, scoreAfter: 249, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: player3Id,
                        displayName: "Mike",
                        nickname: "mike",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 98,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 120, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [], scoreBefore: 120, scoreAfter: 60, isBust: false), // Halved
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 60, scoreAfter: 72, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [], scoreBefore: 72, scoreAfter: 36, isBust: false), // Halved
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 36, scoreAfter: 64, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 64, scoreAfter: 139, isBust: false)
                        ],
                        legsWon: 0
                    )
                ],
                winnerId: player1Id,
                timestamp: Date(),
                duration: 540
            )
        )
    }
}

#Preview("4 Players") {
    let player1Id = UUID()
    let player2Id = UUID()
    let player3Id = UUID()
    let player4Id = UUID()
    
    NavigationView {
        HalveItMatchDetailView(
            match: MatchResult(
                gameType: "Halve It",
                gameName: "Halve It",
                players: [
                    MatchPlayer(
                        id: player1Id,
                        displayName: "Dan",
                        nickname: "dan",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 245,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 80, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 80, scoreAfter: 95, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 95, scoreAfter: 131, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 131, scoreAfter: 245, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2), MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 245, scoreAfter: 301, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1)], scoreBefore: 301, scoreAfter: 451, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: player2Id,
                        displayName: "Sarah",
                        nickname: "sarah",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 189,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 40, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 40, scoreAfter: 50, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 50, scoreAfter: 74, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 74, scoreAfter: 188, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 188, scoreAfter: 216, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 216, scoreAfter: 291, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: player3Id,
                        displayName: "Mike",
                        nickname: "mike",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 134,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 120, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 120, scoreAfter: 125, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [], scoreBefore: 125, scoreAfter: 63, isBust: false), // Halved
                            MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 63, scoreAfter: 120, isBust: false),
                            MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2), MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 120, scoreAfter: 176, isBust: false),
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 176, scoreAfter: 201, isBust: false)
                        ],
                        legsWon: 0
                    ),
                    MatchPlayer(
                        id: player4Id,
                        displayName: "Emma",
                        nickname: "emma",
                        avatarURL: nil,
                        isGuest: true,
                        finalScore: 112,
                        startingScore: 0,
                        totalDartsThrown: 18,
                        turns: [
                            MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 80, isBust: false),
                            MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 80, scoreAfter: 90, isBust: false),
                            MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 90, scoreAfter: 114, isBust: false),
                            MatchTurn(turnNumber: 4, darts: [], scoreBefore: 114, scoreAfter: 57, isBust: false), // Halved
                            MatchTurn(turnNumber: 5, darts: [], scoreBefore: 57, scoreAfter: 29, isBust: false), // Halved
                            MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 29, scoreAfter: 154, isBust: false)
                        ],
                        legsWon: 0
                    )
                ],
                winnerId: player1Id,
                timestamp: Date(),
                duration: 720
            )
        )
    }
}

#Preview("Sheet Mode") {
    let bobId = UUID()
    let aliceId = UUID()
    
    HalveItMatchDetailView(
        match: MatchResult(
            gameType: "Halve It",
            gameName: "Halve It",
            players: [
                MatchPlayer(
                    id: bobId,
                    displayName: "Bob",
                    nickname: "bob",
                    avatarURL: nil,
                    isGuest: true,
                    finalScore: 174,
                    startingScore: 0,
                    totalDartsThrown: 18,
                    turns: [
                        MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2), MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 80, isBust: false),
                        MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 80, scoreAfter: 95, isBust: false),
                        MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 95, scoreAfter: 107, isBust: false),
                        MatchTurn(turnNumber: 4, darts: [MatchDart(baseValue: 19, multiplier: 3), MatchDart(baseValue: 19, multiplier: 3)], scoreBefore: 107, scoreAfter: 221, isBust: false),
                        MatchTurn(turnNumber: 5, darts: [], scoreBefore: 221, scoreAfter: 111, isBust: false),
                        MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 50, multiplier: 1), MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 111, scoreAfter: 236, isBust: false)
                    ],
                    legsWon: 0
                ),
                MatchPlayer(
                    id: aliceId,
                    displayName: "Alice",
                    nickname: "alice",
                    avatarURL: nil,
                    isGuest: true,
                    finalScore: 87,
                    startingScore: 0,
                    totalDartsThrown: 18,
                    turns: [
                        MatchTurn(turnNumber: 1, darts: [MatchDart(baseValue: 20, multiplier: 2)], scoreBefore: 0, scoreAfter: 40, isBust: false),
                        MatchTurn(turnNumber: 2, darts: [MatchDart(baseValue: 5, multiplier: 1), MatchDart(baseValue: 5, multiplier: 1)], scoreBefore: 40, scoreAfter: 50, isBust: false),
                        MatchTurn(turnNumber: 3, darts: [MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1), MatchDart(baseValue: 12, multiplier: 1)], scoreBefore: 50, scoreAfter: 86, isBust: false),
                        MatchTurn(turnNumber: 4, darts: [], scoreBefore: 86, scoreAfter: 43, isBust: false),
                        MatchTurn(turnNumber: 5, darts: [MatchDart(baseValue: 14, multiplier: 2)], scoreBefore: 43, scoreAfter: 71, isBust: false),
                        MatchTurn(turnNumber: 6, darts: [MatchDart(baseValue: 25, multiplier: 1)], scoreBefore: 71, scoreAfter: 96, isBust: false)
                    ],
                    legsWon: 0
                )
            ],
            winnerId: bobId,
            timestamp: Date(),
            duration: 420
        ),
        isSheet: true
    )
}
