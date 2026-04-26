//
//  RecentFormTracker.swift
//  Dart Freak
//
//  Win/Loss tracker for last 10 completed matches
//

import SwiftUI

struct RecentFormTracker: View {
    let formResults: [FormResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Form")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColor.textSecondary)
                
                Spacer()
                
                if !formResults.isEmpty {
                    Text("Last \(formResults.count)")
                        .font(.caption)
                        .foregroundColor(AppColor.textSecondary.opacity(0.7))
                }
            }
            
            if formResults.isEmpty {
                emptyState
            } else {
                formView
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))
            Text("No recent matches")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
            Text("Play some 301/501 games to track your form")
                .font(.caption)
                .foregroundColor(AppColor.textSecondary.opacity(0.7))
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
    }
    
    private var formView: some View {
        GeometryReader { proxy in
            let count = max(formResults.count, 1)
            let spacing: CGFloat = 4
            let totalSpacing = CGFloat(count - 1) * spacing
            let availableWidth = proxy.size.width
            let boxWidth = max((availableWidth - totalSpacing) / CGFloat(count), 0)
            
            HStack(spacing: spacing) {
                ForEach(formResults.reversed()) { result in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(result.isWin ? Color.green : Color.red)
                        .frame(width: boxWidth, height: 40)
                        .overlay {
                            Text(result.isWin ? "W" : "L")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                }
            }
            // Align the row to fill the full available width of GeometryReader
            .frame(width: availableWidth, alignment: .leading)
        }
        // Give the GeometryReader a fixed height equal to the row height
        .frame(height: 40)
    }
}

#Preview("Full Form - Mixed") {
    RecentFormTracker(
        formResults: [
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: false, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: false, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: false, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: false, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date())
        ]
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Partial Form") {
    RecentFormTracker(
        formResults: [
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: false, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date()),
            FormResult(matchId: UUID(), isWin: true, timestamp: Date())
        ]
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    RecentFormTracker(formResults: [])
        .padding()
        .background(AppColor.backgroundPrimary)
}
