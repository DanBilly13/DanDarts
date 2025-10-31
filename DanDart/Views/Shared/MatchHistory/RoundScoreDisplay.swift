//
//  RoundScoreDisplay.swift
//  DanDart
//
//  Color-coded score display for match history rounds
//

import SwiftUI

/// Displays a score in the player's color
/// Used for showing round scores in match history
struct RoundScoreDisplay: View {
    let score: Int
    let playerColor: Color
    
    var body: some View {
        Text("\(score)")
            .font(.caption.weight(.bold))
            .foregroundColor(playerColor)
            .frame(minWidth: 36, alignment: .trailing)
    }
}

#Preview("Round Score Display") {
    HStack(spacing: 16) {
        RoundScoreDisplay(score: 30, playerColor: .green)
        RoundScoreDisplay(score: 45, playerColor: .red)
        RoundScoreDisplay(score: 120, playerColor: .yellow)
        RoundScoreDisplay(score: 5, playerColor: .blue)
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
