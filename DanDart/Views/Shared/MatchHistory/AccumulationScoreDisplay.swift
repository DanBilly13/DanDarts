//
//  AccumulationScoreDisplay.swift
//  DanDart
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
            // Trophy icon or placement text
            if isWinner {
                // Trophy icon - 24px (smaller to make room for score)
                Image(systemName: "trophy")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(Color("AccentTertiary"))
            } else {
                // Placement text - Apple title3 style
                Text(placementText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextSecondary"))
            }
            
            // Show leg indicators for multi-leg matches OR score for all players
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
                    .foregroundColor(Color("TextSecondary"))
            }
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
