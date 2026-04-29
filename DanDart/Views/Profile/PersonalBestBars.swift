//
//  PersonalBestBars.swift
//  Dart Freak
//
//  Personal best achievement bars for highest visit, best checkout, and checkout %
//

import SwiftUI

struct PersonalBestBars: View {
    let highestVisit: Int
    let bestCheckout: Int
    let checkoutPercentage: Double
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Bests")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)

            if isLoading {
                loadingState
            } else {
                VStack(spacing: 16) {
                    StatBar(
                        label: "Highest Visit",
                        value: highestVisit,
                        maxValue: 180,
                        suffix: ""
                    )
                    
                    StatBar(
                        label: "Best Checkout",
                        value: bestCheckout,
                        maxValue: 170,
                        suffix: ""
                    )
                    
                    StatBar(
                        label: "Checkout %",
                        value: Int(checkoutPercentage),
                        maxValue: 100,
                        suffix: "%"
                    )
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            SkeletonBlock(height: 12, cornerRadius: 6, isShimmering: true)
            SkeletonBlock(height: 12, cornerRadius: 6, isShimmering: true)
            SkeletonBlock(height: 12, cornerRadius: 6, isShimmering: true)
        }
        .padding(.top, 8)
    }
}

struct StatBar: View {
    let label: String
    let value: Int
    let maxValue: Int
    let suffix: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColor.textSecondary)
            
            HStack(spacing: 12) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppColor.inputBackground)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(barColor)
                            .frame(width: barWidth(totalWidth: geometry.size.width), height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(value)\(suffix)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 45, alignment: .trailing)
            }
        }
    }
    
    private func barWidth(totalWidth: CGFloat) -> CGFloat {
        guard maxValue > 0 else { return 0 }
        let percentage = CGFloat(value) / CGFloat(maxValue)
        return min(percentage * totalWidth, totalWidth)
    }
    
    private var barColor: Color {
        let percentage = Double(value) / Double(maxValue)
        
        if percentage >= 0.8 {
            return .green
        } else if percentage >= 0.6 {
            return .yellow
        } else if percentage >= 0.4 {
            return .orange
        } else {
            return AppColor.interactivePrimaryBackground
        }
    }
}

#Preview("With Data") {
    PersonalBestBars(
        highestVisit: 180,
        bestCheckout: 121,
        checkoutPercentage: 42.5,
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Partial Data") {
    PersonalBestBars(
        highestVisit: 140,
        bestCheckout: 76,
        checkoutPercentage: 28.3,
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    PersonalBestBars(
        highestVisit: 0,
        bestCheckout: 0,
        checkoutPercentage: 0,
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
