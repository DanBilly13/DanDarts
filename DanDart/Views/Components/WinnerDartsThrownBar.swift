//
//  WinnerDartsThrownBar.swift
//  Dart Freak
//
//  Visual bar showing winner's darts thrown performance with rank thresholds
//  For 301/501 matches only
//

import SwiftUI

struct WinnerDartsThrownBar: View {
    let match: MatchResult
    let gameType: String
    
    // Scaling: 10px per dart
    private let pixelsPerDart: CGFloat = 10.0
    
    private var winner: MatchPlayer? {
        match.players.first { $0.id == match.winnerId }
    }
    
    private var winnerDarts: Int {
        winner?.totalDartsThrown ?? 0
    }
    
    private var winnerIndex: Int {
        match.players.firstIndex { $0.id == match.winnerId } ?? 0
    }
    
    private var winnerColor: Color {
        switch winnerIndex {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    private var rank: RankTier {
        RankingHelper.rankForWinningDarts(game: gameType, dartsThrown: winnerDarts)
    }
    
    // Marker positions for different game types
    private var markerDarts: [Int] {
        if gameType.contains("301") {
            return [6, 12, 18, 27]
        } else if gameType.contains("501") {
            return [9, 15, 21, 30]
        }
        return []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label (matches StatCategorySection)
            Text("Darts Thrown")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)
            
            // Bar + Value (matches PlayerStatBar layout)
            HStack(spacing: 12) {
                // Bar with markers
                GeometryReader { geometry in
                    let barWidth = geometry.size.width
                    let dartPosition = min(CGFloat(winnerDarts) * pixelsPerDart, barWidth)
                    
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColor.inputBackground)
                            .frame(height: 12)
                        
                        // Filled bar (winner's color)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(winnerColor)
                            .frame(width: dartPosition, height: 12)
                        
                        // Marker lines
                        ForEach(markerDarts, id: \.self) { markerDart in
                            let markerX = min(CGFloat(markerDart) * pixelsPerDart, barWidth)
                            Rectangle()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 1, height: 12)
                                .offset(x: markerX)
                        }
                    }
                    
                    // Rank pointer below bar
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 16)
                        
                        // Triangle and label centered together
                        HStack(spacing: 0) {
                            VStack(spacing: 0) {
                                // Triangle pointer (upright isosceles)
                                TrianglePointer()
                                    .fill(Color.white)
                                    .frame(width: 12, height: 12)
                                
                                // Rank label
                                Text(rank.displayName.uppercased())
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white)
                                    .cornerRadius(4)
                                    .fixedSize()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: 100)
                    .offset(x: dartPosition - 50)
                }
                .frame(height: 50)
                
                // Value (right aligned, matches PlayerStatBar)
                VStack(alignment: .trailing) {
                    Text("\(winnerDarts)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 35, alignment: .trailing)
                    Spacer()
                }
                .frame(height: 50)
            }
        }
    }
    
}

// MARK: - Triangle Pointer Shape

struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Upright isosceles triangle (12px × 12px)
        // Base at bottom, tip at top center
        path.move(to: CGPoint(x: 0, y: rect.maxY))              // Bottom left
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))   // Bottom right
        path.addLine(to: CGPoint(x: rect.midX, y: 0))           // Top center (tip)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview("301 Match - Pro Level") {
    WinnerDartsThrownBar(
        match: MatchResult(
            id: UUID(),
            gameType: "301",
            gameName: "301",
            players: [
                MatchPlayer(
                    id: UUID(),
                    displayName: "Winner",
                    nickname: "winner",
                    avatarURL: nil,
                    isGuest: false,
                    finalScore: 0,
                    startingScore: 301,
                    totalDartsThrown: 11,
                    turns: [],
                    legsWon: 1
                ),
                MatchPlayer(
                    id: UUID(),
                    displayName: "Loser",
                    nickname: "loser",
                    avatarURL: nil,
                    isGuest: false,
                    finalScore: 50,
                    startingScore: 301,
                    totalDartsThrown: 45,
                    turns: [],
                    legsWon: 0
                )
            ],
            winnerId: UUID(),
            duration: 180,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: nil
        ),
        gameType: "301"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("501 Match - Immortal") {
    let winnerId = UUID()
    return WinnerDartsThrownBar(
        match: MatchResult(
            id: UUID(),
            gameType: "501",
            gameName: "501",
            players: [
                MatchPlayer(
                    id: winnerId,
                    displayName: "Legend",
                    nickname: "legend",
                    avatarURL: nil,
                    isGuest: false,
                    finalScore: 0,
                    startingScore: 501,
                    totalDartsThrown: 9,
                    turns: [],
                    legsWon: 1
                ),
                MatchPlayer(
                    id: UUID(),
                    displayName: "Opponent",
                    nickname: "opponent",
                    avatarURL: nil,
                    isGuest: false,
                    finalScore: 200,
                    startingScore: 501,
                    totalDartsThrown: 60,
                    turns: [],
                    legsWon: 0
                )
            ],
            winnerId: winnerId,
            duration: 240,
            matchFormat: 1,
            totalLegsPlayed: 1,
            metadata: nil
        ),
        gameType: "501"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
