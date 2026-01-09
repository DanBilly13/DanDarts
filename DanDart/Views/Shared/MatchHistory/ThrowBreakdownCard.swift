//
//  ThrowBreakdownCard.swift
//  Dart Freak
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
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 32, alignment: .leading)

                
                // Players section - 2 per row
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, to: playerData.count, by: 2)), id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            // All darts first
                            HStack(spacing: 4) {
                                // First player darts
                                playerDarts(playerData[rowIndex])
                                
                                // Second player darts (if exists) or empty placeholder
                                if rowIndex + 1 < playerData.count {
                                    playerDarts(playerData[rowIndex + 1])
                                } else {
                                    // Empty placeholder to maintain layout
                                    emptyDartsPlaceholder()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .layoutPriority(1)
                            
                            Spacer()
                            
                            // All scores at the end
                            HStack(spacing: 0) {
                                // First player score
                                playerScore(playerData[rowIndex])
                                
                                // Second player score (if exists) or empty placeholder
                                if rowIndex + 1 < playerData.count {
                                    playerScore(playerData[rowIndex + 1])
                                } else {
                                    // Empty placeholder to maintain layout
                                    emptyScorePlaceholder()
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
            ForEach(Array(data.darts.enumerated()), id: \.offset) { index, dart in
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
    
    // Empty placeholder for darts section to maintain layout
    @ViewBuilder
    private func emptyDartsPlaceholder() -> some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Text("")
                    .font(.system(size: 14, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .layoutPriority(1)
    }
    
    // Empty placeholder for score section to maintain layout
    @ViewBuilder
    private func emptyScorePlaceholder() -> some View {
        Text("")
            .font(.system(size: 14, design: .rounded))
            .monospacedDigit()
            .fontWeight(.bold)
            .frame(minWidth: 36, alignment: .trailing)
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
                    color: AppColor.player1,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "5", "T20"],
                    scoreRemaining: 216,
                    color: AppColor.player2,
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
                    color: AppColor.player1,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "20", "20"],
                    scoreRemaining: 156,
                    color: AppColor.player2,
                    isBust: false
                )
            ]
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("4 Players") {
    VStack(spacing: 16) {
        ThrowBreakdownCard(
            roundNumber: 1,
            playerData: [
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["D19", "5", "1"],
                    scoreRemaining: 257,
                    color: AppColor.player1,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "5", "T20"],
                    scoreRemaining: 216,
                    color: AppColor.player2,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["T20", "T19", "T18"],
                    scoreRemaining: 130,
                    color: AppColor.player3,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["5", "1", "20"],
                    scoreRemaining: 275,
                    color: AppColor.player4,
                    isBust: false
                )
            ]
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("3 Players") {
    VStack(spacing: 16) {
        ThrowBreakdownCard(
            roundNumber: 1,
            playerData: [
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["50", "50", "1"],
                    scoreRemaining: 257,
                    color: AppColor.player1,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["20", "5", "T20"],
                    scoreRemaining: 216,
                    color: AppColor.player2,
                    isBust: false
                ),
                ThrowBreakdownCard.PlayerTurnData(
                    darts: ["50", "50", "1"],
                    scoreRemaining: 130,
                    color: AppColor.player3,
                    isBust: false
                ),
              
            ]
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
