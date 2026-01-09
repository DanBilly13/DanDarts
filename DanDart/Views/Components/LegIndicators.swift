//
//  LegIndicators.swift
//  Dart Freak
//
//  Reusable leg indicators component for multi-leg matches
//

import SwiftUI

/// Displays leg indicators (filled and empty dots) for multi-leg matches
struct LegIndicators: View {
    let legsWon: Int
    let totalLegs: Int
    let color: Color
    let dotSize: CGFloat
    let spacing: CGFloat
    
    init(
        legsWon: Int,
        totalLegs: Int,
        color: Color = Color("AccentPrimary"),
        dotSize: CGFloat = 8,
        spacing: CGFloat = 4
    ) {
        self.legsWon = legsWon
        self.totalLegs = totalLegs
        self.color = color
        self.dotSize = dotSize
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            // All dots - filled for legs won, unfilled for remaining
            ForEach(0..<totalLegs, id: \.self) { index in
                Circle()
                    .fill(index < legsWon ? color : Color("TextSecondary").opacity(0.3))
                    .frame(width: dotSize, height: dotSize)
            }
        }
    }
}

// MARK: - Preview

#Preview("Single Leg Won") {
    VStack(spacing: 20) {
        LegIndicators(legsWon: 1, totalLegs: 3, color: AppColor.player1)
        LegIndicators(legsWon: 1, totalLegs: 3, color: AppColor.player2)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Two Legs Won") {
    VStack(spacing: 20) {
        LegIndicators(legsWon: 2, totalLegs: 3, color: AppColor.player1)
        LegIndicators(legsWon: 2, totalLegs: 4, color: AppColor.player2)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("All Legs Won") {
    VStack(spacing: 20) {
        LegIndicators(legsWon: 3, totalLegs: 3, color: AppColor.player1)
        LegIndicators(legsWon: 4, totalLegs: 4, color: AppColor.player2)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Different Sizes") {
    VStack(spacing: 20) {
        LegIndicators(legsWon: 2, totalLegs: 3, color: AppColor.player1, dotSize: 6, spacing: 3)
        LegIndicators(legsWon: 2, totalLegs: 3, color: AppColor.player1, dotSize: 8, spacing: 4)
        LegIndicators(legsWon: 2, totalLegs: 3, color: AppColor.player1, dotSize: 10, spacing: 5)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
