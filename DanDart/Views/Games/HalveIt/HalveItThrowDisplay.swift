//
//  HalveItThrowDisplay.swift
//  DanDart
//
//  Halve-It specific throw display showing target hits/misses
//  Shows red X for missed targets, normal display for hits
//

import SwiftUI

struct HalveItThrowDisplay: View {
    let currentThrow: [ScoredThrow]
    let selectedDartIndex: Int?
    let currentTarget: HalveItTarget
    let onDartTapped: (Int) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Individual throw scores
            ForEach(0..<3, id: \.self) { index in
                let isSelected = selectedDartIndex == index
                let hasDart = index < currentThrow.count
                let dart = hasDart ? currentThrow[index] : nil
                let isTargetHit = dart != nil && currentTarget.isHit(by: dart!)
                
                Button(action: {
                    if hasDart {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onDartTapped(index)
                    }
                }) {
                    ZStack {
                        // Base dart display
                        Text(hasDart ? dart!.displayText : "—")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(
                                hasDart ? (isTargetHit ? AppColor.textPrimary : AppColor.textSecondary) : AppColor.textSecondary
                            )
                            .frame(width: 40, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColor.textPrimary.opacity(hasDart ? 0.15 : 0.10))
                            )
                        
                        // Red X overlay for missed targets
                        if hasDart && !isTargetHit {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected ? AppColor.interactivePrimaryBackground : Color.clear,
                                lineWidth: isSelected ? 2 : 0
                            )
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                }
                .buttonStyle(PlainButtonStyle())
                .allowsHitTesting(hasDart)
            }
            
            // Equals sign
            Text("=")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, 8)
            
            // Total score (only counts target hits)
            Text("\(calculateTargetScore())")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 50, height: 40)
                .background(AppColor.textPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Helper
    
    /// Calculate score from darts that hit the target
    private func calculateTargetScore() -> Int {
        var total = 0
        for dart in currentThrow {
            if currentTarget.isHit(by: dart) {
                total += dart.totalValue
            }
        }
        return total
    }
}

// MARK: - Preview

#Preview("Target Hit") {
    VStack(spacing: 20) {
        Text("Target: 16")
            .font(.headline)
        
        // All hits
        HalveItThrowDisplay(
            currentThrow: [
                ScoredThrow(baseValue: 16, scoreType: .single),
                ScoredThrow(baseValue: 16, scoreType: .single),
                ScoredThrow(baseValue: 16, scoreType: .single)
            ],
            selectedDartIndex: nil,
            currentTarget: .single(16),
            onDartTapped: { _ in }
        )
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Mixed Hits and Misses") {
    VStack(spacing: 20) {
        Text("Target: 16")
            .font(.headline)
        
        // Hit, miss (number), miss (number)
        HalveItThrowDisplay(
            currentThrow: [
                ScoredThrow(baseValue: 16, scoreType: .single),  // Hit = 16
                ScoredThrow(baseValue: 11, scoreType: .single),  // Miss (shows 11 with X)
                ScoredThrow(baseValue: 9, scoreType: .single)    // Miss (shows 9 with X)
            ],
            selectedDartIndex: nil,
            currentTarget: .single(16),
            onDartTapped: { _ in }
        )
        
        Text("Total: 16 (only target hits count)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("All Misses") {
    VStack(spacing: 20) {
        Text("Target: D20")
            .font(.headline)
        
        // All misses
        HalveItThrowDisplay(
            currentThrow: [
                ScoredThrow(baseValue: 20, scoreType: .single),  // Miss (single not double)
                ScoredThrow(baseValue: 5, scoreType: .single),   // Miss (wrong number)
                ScoredThrow(baseValue: 0, scoreType: .single)    // Miss (miss button)
            ],
            selectedDartIndex: nil,
            currentTarget: .double(20),
            onDartTapped: { _ in }
        )
        
        Text("Total: 0 (no target hits)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
