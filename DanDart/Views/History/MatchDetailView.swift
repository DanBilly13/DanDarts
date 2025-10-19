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
                // Game Type Header with Date
                gameTypeHeader
                
                // Players and Scores
                playersSection
                
                // Stats Comparison (if 2 players)
                if match.players.count == 2 {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Sub Views
    
    private var gameTypeHeader: some View {
        VStack(spacing: 8) {
            Text(match.gameName)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color("TextPrimary"))
            
            Text(match.formattedDate)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
        }
    }
    
    private var playersSection: some View {
        Group {
            if match.players.count == 2 {
                // Side-by-side for 2 players
                HStack(spacing: 12) {
                    CompactPlayerCard(
                        player: match.players[0],
                        isWinner: match.players[0].id == match.winnerId,
                        alignment: .leading
                    )
                    
                    CompactPlayerCard(
                        player: match.players[1],
                        isWinner: match.players[1].id == match.winnerId,
                        alignment: .trailing
                    )
                }
            } else {
                // Vertical stack for more than 2 players
                VStack(spacing: 16) {
                    ForEach(match.players) { player in
                        MatchPlayerCard(
                            player: player,
                            isWinner: player.id == match.winnerId
                        )
                    }
                }
            }
        }
    }
    
    private var statsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stats")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            VStack(spacing: 12) {
                // 180s thrown
                StatComparisonRow(
                    label: "180 thrown",
                    player1Value: count180s(for: match.players[0]),
                    player2Value: count180s(for: match.players[1])
                )
                
                // 140+ thrown
                StatComparisonRow(
                    label: "140+ thrown",
                    player1Value: count140Plus(for: match.players[0]),
                    player2Value: count140Plus(for: match.players[1])
                )
                
                // 100+ thrown
                StatComparisonRow(
                    label: "100+ thrown",
                    player1Value: count100Plus(for: match.players[0]),
                    player2Value: count100Plus(for: match.players[1])
                )
                
                // Highest visit
                StatComparisonRow(
                    label: "Highest visit",
                    player1Value: highestVisit(for: match.players[0]),
                    player2Value: highestVisit(for: match.players[1])
                )
                
                // 3-dart average
                StatComparisonRow(
                    label: "Average visit   ",
                    player1Value: Int(match.players[0].averageScore),
                    player2Value: Int(match.players[1].averageScore),
                    isDecimal: true,
                    player1Decimal: match.players[0].averageScore,
                    player2Decimal: match.players[1].averageScore
                )
                
                // Number of turns
                StatComparisonRow(
                    label: "Number of turns",
                    player1Value: match.players[0].turns.count,
                    player2Value: match.players[1].turns.count
                )
            }
        }
        .padding(16)
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
    
    var body: some View {
        VStack(alignment: alignment, spacing: 12) {
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
                        .foregroundColor(Color("AccentPrimary"))
                        .offset(y: -55)
                }
            }
            .overlay(
                Circle()
                    .stroke(isWinner ? Color("AccentPrimary") : Color("InputBackground"), lineWidth: 3)
            )
            
            // Player info
            VStack(alignment: alignment, spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isWinner ? Color("AccentPrimary") : Color("TextPrimary"))
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            
            // Final score
            VStack(spacing: 2) {
                Text("\(player.finalScore)")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(isWinner ? Color("AccentPrimary") : Color("TextPrimary"))
                
                Text("FINAL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
    }
}

// MARK: - Match Player Card

struct MatchPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color("InputBackground"))
                    .frame(width: 80, height: 80)
                
                if let avatarURL = player.avatarURL {
                    Image(avatarURL)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                }
                
                // Winner crown
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color("AccentPrimary"))
                        .offset(y: -45)
                }
            }
            .overlay(
                Circle()
                    .stroke(isWinner ? Color("AccentPrimary") : Color("InputBackground"), lineWidth: 3)
            )
            
            // Player Info
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isWinner ? Color("AccentPrimary") : Color("TextPrimary"))
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
                
                Text("Average: \(player.formattedAverage)")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color("TextSecondary"))
            }
            
            Spacer()
            
            // Final Score
            VStack(spacing: 4) {
                Text("\(player.finalScore)")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(isWinner ? Color("AccentPrimary") : Color("TextPrimary"))
                
                Text("FINAL")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("TextSecondary"))
                    .tracking(1)
            }
        }
        .padding(16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
        }
    }
}

// MARK: - Stat Comparison Row

struct StatComparisonRow: View {
    let label: String
    let player1Value: Int
    let player2Value: Int
    var isDecimal: Bool = false
    var player1Decimal: Double = 0
    var player2Decimal: Double = 0
    
    private var maxValue: Int {
        max(player1Value, player2Value, 1) // Minimum 1 to avoid division by zero
    }
    
    private var player1Percentage: CGFloat {
        CGFloat(player1Value) / CGFloat(maxValue)
    }
    
    private var player2Percentage: CGFloat {
        CGFloat(player2Value) / CGFloat(maxValue)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Top row: Value - Label - Value
            HStack(spacing: 12) {
                // Player 1 value (left)
                Text(isDecimal ? String(format: "%.2f", player1Decimal) : "\(player1Value)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .frame(width: 50, alignment: .leading)
                
                Spacer()
                
                // Label (center)
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                // Player 2 value (right)
                Text(isDecimal ? String(format: "%.2f", player2Decimal) : "\(player2Value)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .frame(width: 50, alignment: .trailing)
            }
            
            // Bottom row: Bars extending from center
            ZStack {
                // Background bars (full width, light gray)
                HStack(spacing: 4) {
                    // Left bar background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("BackgroundPrimary"))
                        .frame(height: 8)
                    
                    // Right bar background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color("BackgroundPrimary"))
                        .frame(height: 8)
                }
                
                // Filled bars (proportional)
                GeometryReader { geometry in
                    HStack(spacing: 4) {
                        // Left bar (Player 1) - grows from center to left
                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("AccentPrimary"))
                                .frame(width: (geometry.size.width / 2 - 2) * player1Percentage, height: 8)
                        }
                        .frame(width: geometry.size.width / 2 - 2)
                        
                        // Right bar (Player 2) - grows from center to right
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color("AccentSecondary"))
                                .frame(width: (geometry.size.width / 2 - 2) * player2Percentage, height: 8)
                            Spacer()
                        }
                        .frame(width: geometry.size.width / 2 - 2)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Player Turn Breakdown

struct PlayerTurnBreakdown: View {
    let player: MatchPlayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player name header
            Text(player.displayName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("TextPrimary"))
            
            // Turns
            VStack(spacing: 8) {
                ForEach(player.turns) { turn in
                    TurnRow(turn: turn)
                }
            }
        }
        .padding(16)
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color("TextSecondary"))
                .frame(width: 60, alignment: .leading)
            
            // Darts
            HStack(spacing: 4) {
                ForEach(turn.darts, id: \.value) { dart in
                    Text(dart.displayText)
                        .font(.system(size: 12, weight: .medium))
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
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(turn.isBust ? Color.red : Color("AccentPrimary"))
            
            // Score after
            Text("→ \(turn.scoreAfter)")
                .font(.system(size: 12, weight: .medium))
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
