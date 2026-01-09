//
//  CountdownScoreDisplay.swift
//  Dart Freak
//
//  Score display for countdown games (301, 501)
//  Lower score is better, winner always has 0
//

import SwiftUI

/// Score display for countdown-style games where lower is better
/// Winner shows trophy only (no score), non-winners show placement + remaining points
struct CountdownScoreDisplay: View {
    let isWinner: Bool
    let placement: Int
    let finalScore: Int
    let borderColor: Color
    let isMultiLegMatch: Bool
    let legsWon: Int
    let totalLegs: Int
    
    var body: some View {
        VStack(spacing: 4) {
            // Top row: trophy or placement, in a fixed-height container so they align
            Group {
                if isWinner {
                    // Trophy icon - 24px (no score shown for countdown winners)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                } else {
                    // Placement text - Apple headline style
                    Text(placementText)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .frame(height: 24, alignment: .bottom)
            
            // Bottom row: leg indicators or remaining points, also in a fixed-height container
            Group {
                if isMultiLegMatch {
                    // Leg indicators using reusable component
                    LegIndicators(
                        legsWon: legsWon,
                        totalLegs: totalLegs,
                        color: borderColor,
                        dotSize: 8,
                        spacing: 4
                    )
                } else if isWinner {
                    // Single-leg game: show "WINNER" text for winner
                    Text("WINNER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .tracking(0.5)
                } else {
                    // Single-leg game: show remaining points for non-winners
                    Text("(\(finalScore)pts)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
            .frame(height: 16, alignment: .center)
        }
        .frame(width: 60)
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
    
    #Preview("Countdown Score Display") {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            HStack(spacing: 24) {
                CountdownScoreDisplay(
                    isWinner: true,
                    placement: 1,
                    finalScore: 0,
                    borderColor: AppColor.player1,
                    isMultiLegMatch: true,
                    legsWon: 3,
                    totalLegs: 5
                )
                
                CountdownScoreDisplay(
                    isWinner: false,
                    placement: 2,
                    finalScore: 40,
                    borderColor: AppColor.player2,
                    isMultiLegMatch: true,
                    legsWon: 2,
                    totalLegs: 5
                )
                
                CountdownScoreDisplay(
                    isWinner: false,
                    placement: 3,
                    finalScore: 80,
                    borderColor: AppColor.player3,
                    isMultiLegMatch: false,
                    legsWon: 0,
                    totalLegs: 1
                )
            }
            .padding()
        }
    }

