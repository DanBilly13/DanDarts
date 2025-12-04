//
//  LivesDisplay.swift
//  DanDart
//
//  Reusable lives display component for games with life-based mechanics
//  Used in: Sudden Death, Knockout, Killer
//

import SwiftUI

struct LivesDisplay: View {
    let lives: Int
    let startingLives: Int
    var animatingLifeLoss: Bool = false
    
    var body: some View {
        // Only show lives row if game has more than 1 life
        if startingLives > 1 {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .scaleEffect(animatingLifeLoss ? 2.0 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4), value: animatingLifeLoss)
                Text("\(lives)")
                    .font(.footnote)
                    .foregroundColor(AppColor.textSecondary)
            }
        }
    }
}

#Preview("3 Lives") {
    VStack(spacing: 16) {
        LivesDisplay(lives: 3, startingLives: 3)
        LivesDisplay(lives: 2, startingLives: 3)
        LivesDisplay(lives: 1, startingLives: 3)
        LivesDisplay(lives: 0, startingLives: 3)
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("1 Life (Hidden)") {
    LivesDisplay(lives: 1, startingLives: 1)
        .padding()
        .background(AppColor.backgroundPrimary)
}
