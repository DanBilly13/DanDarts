//
//  RoundContainer.swift
//  DanDart
//
//  Universal round card container for match history
//

import SwiftUI

/// Reusable container for round cards in match history
/// Provides consistent styling: 16px padding, 8px corners, full width
struct RoundContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(AppColor.inputBackground)
            .cornerRadius(8)
    }
}

#Preview("Round Container") {
    VStack(spacing: 12) {
        RoundContainer {
            HStack {
                Text("R1")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                Text("Example Content")
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        
        RoundContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("Round 2")
                    .font(.headline)
                Text("More content here")
                    .font(.subheadline)
            }
        }
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
