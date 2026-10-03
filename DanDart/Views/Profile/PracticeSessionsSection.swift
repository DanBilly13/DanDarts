//
//  PracticeSessionsSection.swift
//  Dart Freak
//
//  The same throwing widgets as the main Profile stats, computed over solo
//  practice matches only, so how you throw in practice can be compared with how
//  you throw in real matches. Practice isn't a win or a loss, so there is no
//  Recent Form and it never counts towards Wins, Losses or Rank.
//

import SwiftUI

struct PracticeSessionsSection: View {
    let practice: ThrowingStats
    /// Shared with the main trend chart so the two read at the same height.
    let trendScale: TrendYScale
    let isLoading: Bool

    private var subtitle: String {
        let sessions = practice.matchCount == 1 ? "1 solo session" : "\(practice.matchCount) solo sessions"
        return "\(sessions) · not counted in wins, losses or rank"
    }

    var body: some View {
        VStack(spacing: 48) {
            Divider()
                .overlay(AppColor.inputBackground)

            VStack(alignment: .leading, spacing: 4) {
                Text("Practice Sessions")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColor.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ThreeDartAverageTrendChart(
                dataPoints: practice.threeDartAverageHistory,
                isLoading: isLoading,
                yScale: trendScale
            )

            DartsThrownPerLegBar(
                avgDarts: practice.avgDartsPerLeg,
                rank: practice.avgDartsRank,
                gameType: "301",
                isLoading: isLoading
            )

            ScoringDistributionChart(
                distribution: practice.scoringDistribution,
                isLoading: isLoading
            )

            PersonalBestBars(
                highestVisit: practice.highestVisit,
                bestCheckout: practice.bestCheckout,
                checkoutPercentage: practice.checkoutPercentage,
                isLoading: isLoading
            )
        }
    }
}
