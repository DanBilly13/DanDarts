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
        Group {
            if score == 0 {
                // Show crown icon for winners (score of 0)
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(playerColor)
            } else {
                // Show score for non-zero values
                Text("\(score)")
                    .font(.system(size: 14, design: .rounded))
                    .monospacedDigit()
                    .fontWeight(.bold)
                    .foregroundColor(playerColor)
            }
        }
        .frame(minWidth: 36, alignment: .trailing)
    }
}

#Preview("Round Score Display") {
    HStack(spacing: 16) {
        RoundScoreDisplay(score: 0, playerColor: AppColor.player1)  // Winner - shows crown
        RoundScoreDisplay(score: 30, playerColor: AppColor.player1)
        RoundScoreDisplay(score: 45, playerColor: AppColor.player2)
        RoundScoreDisplay(score: 120, playerColor: AppColor.player3)
        RoundScoreDisplay(score: 5, playerColor: AppColor.player4)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
