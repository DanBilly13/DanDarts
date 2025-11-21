//
//  CurrentThrowDisplay.swift
//  DanDart
//
//  Reusable component for displaying current throw with tap-to-edit functionality
//  Shows 3 dart slots, selected dart border, and total score
//

import SwiftUI

struct CurrentThrowDisplay: View {
    let currentThrow: [ScoredThrow]
    let selectedDartIndex: Int?
    let onDartTapped: (Int) -> Void
    var showScore: Bool = true // Optional parameter to show/hide score total
    
    var body: some View {
        HStack(spacing: 12) {
            // Individual throw scores
            ForEach(0..<3, id: \.self) { index in
                let isSelected = selectedDartIndex == index
                let hasDart = index < currentThrow.count
                
                Button(action: {
                    if hasDart {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onDartTapped(index)
                    }
                }) {
                    Text(hasDart ? currentThrow[index].displayText : "—")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(hasDart ? AppColor.textPrimary : AppColor.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColor.textPrimary.opacity(hasDart ? 0.15 : 0.10))
                        )
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
            
            // Score section (optional)
            if showScore {
                // Equals sign
                Text("=")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.horizontal, 8)
                
                // Total score
                Text("\(currentThrow.reduce(0) { $0 + $1.totalValue })")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 50, height: 40)
                    .background(AppColor.textPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 0)
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview
#Preview("Empty Throw") {
    CurrentThrowDisplay(
        currentThrow: [],
        selectedDartIndex: nil,
        onDartTapped: { _ in }
    )
    .padding(.vertical,0)
    .background(AppColor.backgroundPrimary)
}

#Preview("Partial Throw") {
    CurrentThrowDisplay(
        currentThrow: [
            ScoredThrow(baseValue: 20, scoreType: .triple),
            ScoredThrow(baseValue: 20, scoreType: .single)
        ],
        selectedDartIndex: nil,
        onDartTapped: { _ in }
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Full Throw - Selected") {
    CurrentThrowDisplay(
        currentThrow: [
            ScoredThrow(baseValue: 17, scoreType: .single),
            ScoredThrow(baseValue: 17, scoreType: .single),
            ScoredThrow(baseValue: 17, scoreType: .single)
        ],
        selectedDartIndex: 2,
        onDartTapped: { _ in }
    )
    .padding(.vertical,0)
    .background(AppColor.backgroundPrimary)
}
