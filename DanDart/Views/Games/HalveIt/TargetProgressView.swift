//
//  TargetProgressView.swift
//  DanDart
//
//  Displays the target sequence for Halve It game
//  Shows current target highlighted, completed targets dimmed
//

import SwiftUI

struct TargetProgressView: View {
    let targets: [HalveItTarget]
    let currentRound: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                // Target text
                Text(target.displayText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColor.interactiveTertiaryBackground)
                    .opacity(index == currentRound ? 1.0 : 0.5)
                
                // Arrow separator (except after last target)
                if index < targets.count - 1 {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColor.interactiveTertiaryBackground)
                        .opacity(0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview("Target Progress - Round 2") {
    VStack(spacing: 20) {
        // Round 0 (first target)
        TargetProgressView(
            targets: [.double(20), .single(5), .single(12), .triple(19), .double(14), .bull],
            currentRound: 0
        )
        
        // Round 2 (middle)
        TargetProgressView(
            targets: [.double(20), .single(5), .single(12), .triple(19), .double(14), .bull],
            currentRound: 2
        )
        
        // Round 5 (last - Bull)
        TargetProgressView(
            targets: [.double(20), .single(5), .single(12), .triple(19), .double(14), .bull],
            currentRound: 5
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
