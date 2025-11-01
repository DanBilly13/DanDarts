//
//  ThrowBreakdownCard.swift
//  DanDart
//
//  Reusable component for displaying 301/501 turn breakdown
//  Shows round number, dart throws, and remaining scores
//

import SwiftUI

struct ThrowBreakdownCard: View {
    let roundNumber: Int
    let playerData: [PlayerTurnData]
    
    struct PlayerTurnData {
        let darts: [String] // e.g., ["D19", "5", "1"]
        let scoreRemaining: Int
        let color: Color
        let isBust: Bool
    }
    
    var body: some View {
        RoundContainer {
            HStack(alignment: .center, spacing: 12) {
                // Round number label (flexible width)
                Text("R\(roundNumber)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                    .frame(width: 32, alignment: .leading)

                
                // Players section - 2 per row
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, to: playerData.count, by: 2)), id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            // All darts first
                            HStack(spacing: 4) {
                                // First player darts
                                playerDarts(playerData[rowIndex])
                                
                                // Second player darts (if exists)
                                if rowIndex + 1 < playerData.count {
                                    playerDarts(playerData[rowIndex + 1])
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                            
                            Spacer()
                            
                            // All scores at the end
                            HStack(spacing: 0) {
                                // First player score
                                playerScore(playerData[rowIndex])
                                
                                // Second player score (if exists)
                                if rowIndex + 1 < playerData.count {
                                    playerScore(playerData[rowIndex + 1])
                                }
                            }
                            .layoutPriority(0)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func playerDarts(_ data: PlayerTurnData) -> some View {
        HStack(spacing: 0) {
            ForEach(data.darts, id: \.self) { dart in
                Text(dart)
                    .font(.system(size: 14, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(data.color)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }
    
    @ViewBuilder
    private func playerScore(_ data: PlayerTurnData) -> some View {
        RoundScoreDisplay(
            score: data.scoreRemaining,
            playerColor: data.isBust ? .red : data.color
        )
    }
}

// MARK: - Preview

#Preview("2 Players") {
    VStack(spacing: 16) {
        ThrowBreakdownCard(
            roundNumber: 1,
            playerData: [
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["D19", "5", "1"],
                    scoreRemaining: 257,
                    color: Color("AccentSecondary"),
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "5", "T20"],
                    scoreRemaining: 216,
                    color: Color("AccentPrimary"),
                    isBust: false
                )
            ]
        )
        
        ThrowBreakdownCard(
            roundNumber: 2,
            playerData: [
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["T20", "T20", "T20"],
                    scoreRemaining: 77,
                    color: Color("AccentSecondary"),
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "20", "20"],
                    scoreRemaining: 156,
                    color: Color("AccentPrimary"),
                    isBust: false
                )
            ]
        )
    }
    .padding()
    .background(Color.yellow)
}

#Preview("4 Players") {
    VStack(spacing: 16) {
        ThrowBreakdownCard(
            roundNumber: 1,
            playerData: [
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["D19", "5", "1"],
                    scoreRemaining: 257,
                    color: Color("AccentSecondary"),
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "5", "T20"],
                    scoreRemaining: 216,
                    color: Color("AccentPrimary"),
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["T20", "T19", "T18"],
                    scoreRemaining: 130,
                    color: Color("AccentTertiary"),
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["5", "1", "20"],
                    scoreRemaining: 275,
                    color: Color("AccentQuaternary"),
                    isBust: false
                )
            ]
        )
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
