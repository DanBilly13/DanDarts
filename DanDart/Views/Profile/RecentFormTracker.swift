//
//  RecentFormTracker.swift
//  Dart Freak
//
//  Win/Loss tracker for last 10 completed matches
//

import SwiftUI

struct RecentFormTracker: View {
    let formResults: [FormResult]
    let isLoading: Bool
    
    private let maxResults: Int = 10
    
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
            
            if isLoading {
                loadingState
            } else {
                formView
            }
        }
    }

    private var loadingState: some View {
        GeometryReader { proxy in
            let count = maxResults
            let spacing: CGFloat = 4
            let totalSpacing = CGFloat(count - 1) * spacing
            let availableWidth = proxy.size.width
            let boxWidth = max((availableWidth - totalSpacing) / CGFloat(count), 0)

            HStack(spacing: spacing) {
                ForEach(0..<maxResults, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColor.inputBackground)
                        .frame(width: boxWidth, height: 40)
                        .shimmer(isActive: true)
                }
            }
            .frame(width: availableWidth, alignment: .leading)
        }
        .frame(height: 40)
    }
    
    private var formView: some View {
        GeometryReader { proxy in
            let count = maxResults
            let spacing: CGFloat = 4
            let totalSpacing = CGFloat(count - 1) * spacing
            let availableWidth = proxy.size.width
            let boxWidth = max((availableWidth - totalSpacing) / CGFloat(count), 0)
            
            let resultsOldestToNewest = Array(formResults.reversed())
            let paddedResults: [FormResult?] = resultsOldestToNewest.map { Optional($0) } + Array(repeating: nil, count: max(0, maxResults - resultsOldestToNewest.count))
            
            HStack(spacing: spacing) {
                ForEach(Array(paddedResults.enumerated()), id: \.offset) { _, result in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(result?.isWin == true ? Color.green : (result == nil ? AppColor.inputBackground : Color.red))
                        .frame(width: boxWidth, height: 40)
                        .overlay {
                            if let result {
                                Text(result.isWin ? "W" : "L")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
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
        ],
        isLoading: false
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
        ],
        isLoading: false
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Empty State") {
    RecentFormTracker(formResults: [], isLoading: false)
        .padding()
        .background(AppColor.backgroundPrimary)
}
