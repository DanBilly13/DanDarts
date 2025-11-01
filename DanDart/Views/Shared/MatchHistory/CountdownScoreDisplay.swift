//
//  CountdownScoreDisplay.swift
//  DanDart
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
            // Trophy icon or placement text
            if isWinner {
                // Trophy icon - 32px (no score shown for countdown winners)
                Image(systemName: "trophy")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(Color("AccentTertiary"))
            } else {
                // Placement text - Apple title3 style
                Text(placementText)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextSecondary"))
            }
            
            // Show leg indicators for multi-leg matches OR remaining points for non-winners
            if isMultiLegMatch {
                // Leg indicators using reusable component
                LegIndicators(
                    legsWon: legsWon,
                    totalLegs: totalLegs,
                    color: borderColor,
                    dotSize: 8,
                    spacing: 4
                )
            } else if !isWinner {
                // Single-leg game: show remaining points for non-winners
                Text("(\(finalScore)pts)")
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
