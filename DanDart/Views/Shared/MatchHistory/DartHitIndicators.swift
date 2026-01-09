//
//  DartHitIndicators.swift
//  Dart Freak
//
//  Reusable 3-dot hit/miss indicator for dart throws
//

import SwiftUI

/// Displays 3 circles showing hits (colored) vs misses (gray)
/// Used in Halve-It and potentially other games
struct DartHitIndicators: View {
    let hits: Int // Number of darts that hit (0-3) - DEPRECATED, use hitSequence instead
    let playerColor: Color
    let hitSequence: [Bool]? // Optional: [true, false, true] = hit, miss, hit
    let circleSize: CGFloat = 12
    let spacing: CGFloat = 12
    
    init(hits: Int, playerColor: Color, hitSequence: [Bool]? = nil) {
        self.hits = hits
        self.playerColor = playerColor
        self.hitSequence = hitSequence
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotColor(for: index))
                    .frame(width: circleSize, height: circleSize)
            }
        }
    }
    
    private func dotColor(for index: Int) -> Color {
        if let sequence = hitSequence {
            // Use sequence if provided (shows exact hit/miss order)
            return index < sequence.count && sequence[index] 
                ? playerColor 
                : AppColor.textSecondary.opacity(0.3)
        } else {
            // Fallback to old behavior (just count)
            return index < hits ? playerColor : AppColor.textSecondary.opacity(0.3)
        }
    }
}

#Preview("Dart Hit Indicators") {
    VStack(spacing: 16) {
        HStack {
            Text("3 hits:")
            DartHitIndicators(hits: 3, playerColor: AppColor.player1)
        }
        
        HStack {
            Text("2 hits:")
            DartHitIndicators(hits: 2, playerColor: AppColor.player2)
        }
        
        HStack {
            Text("1 hit:")
            DartHitIndicators(hits: 1, playerColor: AppColor.player3)
        }
        
        HStack {
            Text("0 hits:")
            DartHitIndicators(hits: 0, playerColor: AppColor.player4)
        }
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
