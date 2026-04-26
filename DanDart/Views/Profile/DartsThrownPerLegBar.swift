//
//  DartsThrownPerLegBar.swift
//  Dart Freak
//
//  Visual bar showing average darts thrown per leg with rank thresholds
//  For 301/501 matches only
//

import SwiftUI

struct DartsThrownPerLegBar: View {
    let avgDarts: Double
    let rank: RankTier
    let gameType: String
    
    private let pixelsPerDart: CGFloat = 10.0
    
    private var markerDarts: [Int] {
        RankingHelper.thresholdMarkers(for: gameType)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avg. Darts Per Leg")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)
            
            if avgDarts == 0 {
                emptyState
            } else {
                barView
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 40))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))
            Text("No winning matches yet")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
            Text("Win some 301/501 games to see your average")
                .font(.caption)
                .foregroundColor(AppColor.textSecondary.opacity(0.7))
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private var barView: some View {
        HStack(spacing: 12) {
            GeometryReader { geometry in
                let barWidth = geometry.size.width
                let dartPosition = min(CGFloat(avgDarts) * pixelsPerDart, barWidth)
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.inputBackground.opacity(0.5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.interactivePrimaryBackground)
                        .frame(width: dartPosition, height: 12)
                    
                    ForEach(markerDarts, id: \.self) { markerDart in
                        let markerX = min(CGFloat(markerDart) * pixelsPerDart, barWidth)
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 1, height: 12)
                            .offset(x: markerX)
                    }
                }
                
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 16)
                    
                    HStack(spacing: 0) {
                        VStack(spacing: 0) {
                            TrianglePointer()
                                .fill(Color.white)
                                .frame(width: 12, height: 12)
                            
                            Text(rank.displayName.uppercased())
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.medium)
                                .foregroundColor(.black)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.white)
                                .cornerRadius(4)
                                .fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 100)
                .offset(x: dartPosition - 50)
            }
            .frame(height: 50)
            
            VStack(alignment: .trailing) {
                Text(String(format: "%.1f", avgDarts))
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 35, alignment: .trailing)
                Spacer()
            }
            .frame(height: 50)
        }
    }
}

#Preview("With Data - 301") {
    DartsThrownPerLegBar(
        avgDarts: 15.3,
        rank: .proLevel,
        gameType: "301"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("With Data - 501") {
    DartsThrownPerLegBar(
        avgDarts: 18.7,
        rank: .advanced,
        gameType: "501"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    DartsThrownPerLegBar(
        avgDarts: 0,
        rank: .unranked,
        gameType: "301"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
