//
//  AccumulationScoreDisplay.swift
//  Dart Freak
//
//  Score display for accumulation games (Halve It, Cricket, etc.)
//  Higher score is better, winner's score is meaningful
//

import SwiftUI

/// Score display for accumulation-style games where higher is better
/// Winner shows small trophy + score, non-winners show placement + score
struct AccumulationScoreDisplay: View {
    let isWinner: Bool
    let placement: Int
    let finalScore: Int
    let borderColor: Color
    let isMultiLegMatch: Bool
    let legsWon: Int
    let totalLegs: Int
    
    var body: some View {
        VStack(spacing: 4) {
            // Top row: crown or placement, in a fixed-height container so they align
            Group {
                if isWinner {
                    // Crown icon for winner
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
            
            // Bottom row: leg indicators or score, also in a fixed-height container
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
                } else {
                    // Single-leg game: show score for all players (winner and non-winners)
                    Text("\(finalScore)pts")
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

#Preview("Accumulation Score Display") {
    ZStack {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
        
        HStack(spacing: 24) {
            AccumulationScoreDisplay(
                isWinner: true,
                placement: 1,
                finalScore: 120,
                borderColor: AppColor.player1,
                isMultiLegMatch: true,
                legsWon: 3,
                totalLegs: 5
            )
            
            AccumulationScoreDisplay(
                isWinner: false,
                placement: 2,
                finalScore: 95,
                borderColor: AppColor.player2,
                isMultiLegMatch: true,
                legsWon: 2,
                totalLegs: 5
            )
            
            AccumulationScoreDisplay(
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
