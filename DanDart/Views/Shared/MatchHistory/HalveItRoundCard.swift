//
//  HalveItRoundCard.swift
//  DanDart
//
//  Round card for Halve-It match history
//  Shows: Round-Target | Player dots | Scores
//

import SwiftUI

/// Round card for Halve-It game showing hits/misses and scores
/// Layout: R1-15 | dots dots | score score (2 players per row)
struct HalveItRoundCard: View {
    let roundNumber: Int
    let targetDisplay: String // e.g., "15", "D20", "BULL"
    let playerData: [PlayerRoundData]
    
    struct PlayerRoundData {
        let hits: Int // 0-3
        let score: Int
        let color: Color
        let hitSequence: [Bool]? // Optional: exact sequence of hits/misses
        
        init(hits: Int, score: Int, color: Color, hitSequence: [Bool]? = nil) {
            self.hits = hits
            self.score = score
            self.color = color
            self.hitSequence = hitSequence
        }
    }
    
    var body: some View {
        RoundContainer {
            HStack(alignment: .center, spacing: 0) {
                // Round label - vertically centered
                Text("R\(roundNumber)-\(targetDisplay)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .frame(minWidth: 60, alignment: .leading)
                    .lineLimit(1)
                
                // Player rows
                VStack(spacing: 8) {
                    // Process players in groups of 2
                    ForEach(Array(stride(from: 0, to: playerData.count, by: 2)), id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            // Player dots
                            Spacer()
                            HStack(spacing: 20) {
                                if rowIndex < playerData.count {
                                    DartHitIndicators(
                                        hits: playerData[rowIndex].hits, 
                                        playerColor: playerData[rowIndex].color,
                                        hitSequence: playerData[rowIndex].hitSequence
                                    )
                                }
                                if rowIndex + 1 < playerData.count {
                                    DartHitIndicators(
                                        hits: playerData[rowIndex + 1].hits, 
                                        playerColor: playerData[rowIndex + 1].color,
                                        hitSequence: playerData[rowIndex + 1].hitSequence
                                    )
                                } else if playerData.count == 3 && rowIndex == 2 {
                                    // Invisible spacer for 3rd player to align with 1st player
                                    DartHitIndicators(hits: 0, playerColor: .clear)
                                        .opacity(0)
                                }
                            }
                            Spacer()
                            
                            // Scores at the end
                            HStack(spacing: 0) {
                                if rowIndex < playerData.count {
                                    RoundScoreDisplay(score: playerData[rowIndex].score, playerColor: playerData[rowIndex].color)
                                }
                                if rowIndex + 1 < playerData.count {
                                    RoundScoreDisplay(score: playerData[rowIndex + 1].score, playerColor: playerData[rowIndex + 1].color)
                                } else if playerData.count == 3 && rowIndex == 2 {
                                    // Invisible spacer for score alignment
                                    RoundScoreDisplay(score: 0, playerColor: .clear)
                                        .opacity(0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("2 Players") {
    VStack(spacing: 12) {
        HalveItRoundCard(
            roundNumber: 1,
            targetDisplay: "15",
            playerData: [
                .init(hits: 2, score: 130, color: Color("AccentSecondary")),
                .init(hits: 3, score: 145, color: Color("AccentPrimary"))
            ]
        )
        
        HalveItRoundCard(
            roundNumber: 2,
            targetDisplay: "D20",
            playerData: [
                .init(hits: 1, score: 70, color: Color("AccentSecondary")),
                .init(hits: 0, score: 23, color: Color("AccentPrimary"))
            ]
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("3 Players") {
    VStack(spacing: 12) {
        HalveItRoundCard(
            roundNumber: 1,
            targetDisplay: "15",
            playerData: [
                .init(hits: 2, score: 30, color: Color("AccentSecondary")),
                .init(hits: 3, score: 45, color: Color("AccentPrimary")),
                .init(hits: 3, score: 45, color: Color("AccentTertiary"))
            ]
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("4 Players") {
    VStack(spacing: 12) {
        HalveItRoundCard(
            roundNumber: 1,
            targetDisplay: "15",
            playerData: [
                .init(hits: 2, score: 30, color: Color("AccentSecondary")),
                .init(hits: 3, score: 45, color: Color("AccentPrimary")),
                .init(hits: 3, score: 45, color: Color("AccentTertiary")),
                .init(hits: 1, score: 15, color: Color("AccentQuaternary"))
            ]
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
