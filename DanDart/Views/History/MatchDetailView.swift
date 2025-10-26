//
//  MatchDetailView.swift
//  DanDart
//
//  Detailed view of a completed match with turn-by-turn breakdown
//

import SwiftUI

struct MatchDetailView: View {
    let match: MatchResult
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Date and Time
                dateHeader
                
                // Players and Scores
                playersSection
                
                // Stats Section (for all matches)
                if !match.players.isEmpty {
                    statsComparisonSection
                }
                
                // Turn-by-Turn Breakdown
                if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                    turnBreakdownSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color("BackgroundPrimary"))
        .navigationTitle(match.gameName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
            // Sort players: winner first, then by final score (lowest remaining)
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
    }
    
    // Sorted players: winner first, then by final score
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            // Winner always comes first
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            
            // Then sort by final score (lower is better - closer to winning)
            return player1.finalScore < player2.finalScore
        }
    }
    
    // Get original player index for color assignment
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    private var statsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.title3.weight(.semibold))
                .foregroundColor(Color("TextPrimary"))
            
            VStack(spacing: 20) {
                // Number of turns
                StatCategorySection(
                    label: "Number of turns",
                    players: match.players,
                    getValue: { $0.turns.count }
                )
                
                // 3-dart average
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
        .padding(.horizontal, 16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
    }
    
    // MARK: - Stats Helpers
    
    private func count180s(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal == 180 }.count
    }
    
    private func count140Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 140 }.count
    }
    
    private func count100Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 100 }.count
    }
    
    private func highestVisit(for player: MatchPlayer) -> Int {
        player.turns.map { $0.turnTotal }.max() ?? 0
    }
    
    private var turnBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turn-by-Turn Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            ForEach(match.players) { player in
                PlayerTurnBreakdown(player: player)
            }
        }
    }
}

// MARK: - Compact Player Card (Side-by-Side)

struct CompactPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let alignment: HorizontalAlignment
    let playerIndex: Int
    
    // Get border color based on player index
    var borderColor: Color {
        switch playerIndex {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // Avatar with crown
            ZStack {
                Circle()
                    .fill(Color("InputBackground"))
                    .frame(width: 100, height: 100)
                
                if let avatarURL = player.avatarURL {
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                }
                
                // Winner crown
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color("AccentTertiary"))
                        .offset(y: -55)
                }
            }
            
            // Player info - centered
            VStack(alignment: .center, spacing: 4) {
                Text(player.displayName)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(isWinner ? Color("TextPrimary") : Color("TextPrimary"))
                    .multilineTextAlignment(.center)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextPrimary").opacity(0.8))
                        .foregroundColor(Color("TextPrimary"))
                }
            }
            
            // Winner badge or remaining points
            if isWinner {
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color("AccentTertiary"))
                    
                    Text("WINNER")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color("TextPrimary"))
                        .tracking(1)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    Text("\(player.finalScore)")
                        .font(.title.weight(.bold))
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("Left on \(player.finalScore)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color("TextPrimary"))
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Match Player Card

struct MatchPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let playerIndex: Int
    let placement: Int
    var matchFormat: Int = 1 // Total legs in match (1, 3, 5, or 7)
    
    // Check if this is a multi-leg match
    private var isMultiLegMatch: Bool {
        matchFormat > 1
    }
    
    // Calculate total legs needed to win
    private var totalLegsInMatch: Int {
        (matchFormat / 2) + 1
    }
    
    // Get border color based on player index
    var borderColor: Color {
        switch playerIndex {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Player identity (avatar + name + nickname)
            PlayerIdentity(
                matchPlayer: player,
                avatarSize: 48,
                borderColor: borderColor
            )
            
            Spacer()
            
            // Right side - Trophy/Position with legs below
            VStack(spacing: 6) {
                // Trophy icon or placement text
                if isWinner {
                    // Trophy icon - 36px (outline style, thinner stroke)
                    Image(systemName: "trophy")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundColor(Color("AccentTertiary"))
                } else {
                    // Placement text - Apple title3 style
                    Text(placementText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("TextSecondary"))
                }
                
                // Show leg indicators for multi-leg matches OR "Left on X" for single-leg non-winners
                if isMultiLegMatch {
                    // Leg indicators using reusable component
                    LegIndicators(
                        legsWon: player.legsWon,
                        totalLegs: matchFormat,
                        color: borderColor,
                        dotSize: 8,
                        spacing: 4
                    )
                } else if !isWinner {
                    // Single-leg game: show "Left on X" for non-winners
                    Text("Left on \(player.finalScore)")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            .frame(width: 44)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
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

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color("AccentPrimary"))
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color("TextSecondary"))
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("TextPrimary"))
        }
    }
}

// MARK: - Stat Category Section

struct StatCategorySection: View {
    let label: String
    let players: [MatchPlayer]
    let getValue: (MatchPlayer) -> Int
    var isDecimal: Bool = false
    var getDecimalValue: ((MatchPlayer) -> Double)?
    
    // Calculate max value for scaling bars
    private var maxValue: Int {
        let values = players.map { getValue($0) }
        return max(values.max() ?? 1, 1) // Minimum 1 to avoid division by zero
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category label
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("TextSecondary"))
            
            // Individual stat bars for each player
            VStack(spacing: 6) {
                ForEach(0..<players.count, id: \.self) { index in
                    PlayerStatBar(
                        player: players[index],
                        playerIndex: index,
                        value: getValue(players[index]),
                        maxValue: maxValue,
                        isDecimal: isDecimal,
                        decimalValue: getDecimalValue?(players[index])
                    )
                }
            }
        }
    }
}

// MARK: - Player Stat Bar

struct PlayerStatBar: View {
    let player: MatchPlayer
    let playerIndex: Int
    let value: Int
    let maxValue: Int
    var isDecimal: Bool = false
    var decimalValue: Double?
    
    // Get player color based on index
    private var playerColor: Color {
        switch playerIndex {
        case 0: return Color("AccentPrimary")
        case 1: return Color("AccentSecondary")
        case 2: return Color("AccentTertiary")
        case 3: return Color("AccentQuaternary")
        default: return Color("AccentPrimary")
        }
    }
    
    // Calculate percentage for bar width
    private var percentage: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress bar with avatar overlay
            ZStack(alignment: .leading) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar (gray)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color("BackgroundPrimary"))
                            .frame(height: 20)
                        
                        // Filled bar (player's color)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(playerColor)
                            .frame(width: geometry.size.width * percentage, height: 20)
                    }
                }
                .frame(height: 20)
                
                // Player avatar (overlaid on left edge)
                AsyncAvatarImage(
                    avatarURL: player.avatarURL,
                    size: 20,
                    placeholderIcon: "person.circle.fill"
                )
                .overlay(
                    Circle()
                        .stroke(Color("BackgroundPrimary"), lineWidth: 1)
                )
                .offset(x: 0)
            }
            
            // Value (right aligned, rounded up)
            Text(isDecimal && decimalValue != nil ? "\(Int(ceil(decimalValue!)))" : "\(value)")
                .font(.caption.weight(.bold))
                .foregroundColor(Color("TextPrimary"))
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Player Turn Breakdown

struct PlayerTurnBreakdown: View {
    let player: MatchPlayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player name header
            Text(player.displayName)
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))
            
            // Turns
            VStack(spacing: 8) {
                ForEach(player.turns) { turn in
                    TurnRow(turn: turn)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
    }
}

// MARK: - Turn Row

struct TurnRow: View {
    let turn: MatchTurn
    
    var body: some View {
        HStack(spacing: 12) {
            // Turn number
            Text("Turn \(turn.turnNumber)")
                .font(.caption.weight(.semibold))
                .foregroundColor(Color("TextSecondary"))
                .frame(width: 60, alignment: .leading)
            
            // Darts
            HStack(spacing: 4) {
                ForEach(turn.darts, id: \.value) { dart in
                    Text(dart.displayText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(Color("TextPrimary"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color("BackgroundPrimary"))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Turn total
            Text("\(turn.turnTotal)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(turn.isBust ? Color.red : Color("AccentPrimary"))
            
            // Score after
            Text("→ \(turn.scoreAfter)")
                .font(.caption.weight(.medium))
                .foregroundColor(Color("TextSecondary"))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MatchDetailView(match: MatchResult.mock301)
    }
}
