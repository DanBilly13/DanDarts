//
//  DartHitIndicators.swift
//  DanDart
//
//  Reusable 3-dot hit/miss indicator for dart throws
//

import SwiftUI

/// Displays 3 circles showing hits (colored) vs misses (gray)
/// Used in Halve-It and potentially other games
struct DartHitIndicators: View {
    let hits: Int // Number of darts that hit (0-3)
    let playerColor: Color
    let circleSize: CGFloat = 12
    let spacing: CGFloat = 12
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < hits ? playerColor : Color("TextSecondary").opacity(0.3))
                    .frame(width: circleSize, height: circleSize)
            }
        }
    }
}

#Preview("Dart Hit Indicators") {
    VStack(spacing: 16) {
        HStack {
            Text("3 hits:")
            DartHitIndicators(hits: 3, playerColor: .green)
        }
        
        HStack {
            Text("2 hits:")
            DartHitIndicators(hits: 2, playerColor: .red)
        }
        
        HStack {
            Text("1 hit:")
            DartHitIndicators(hits: 1, playerColor: .yellow)
        }
        
        HStack {
            Text("0 hits:")
            DartHitIndicators(hits: 0, playerColor: .blue)
        }
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
