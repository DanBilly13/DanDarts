//
//  TypingIndicator.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-04-16.
//

import SwiftUI

struct TypingIndicator: View {
    @State private var activeDot = -1
    // Increased to 1.1s to double the "dead air" after the 3rd bounce
    let timer = Timer.publish(every: 1.1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .offset(y: activeDot == index ? -10 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: activeDot)
            }
        }
        .onReceive(timer) { _ in
            animateSequence()
        }
        .onAppear {
            animateSequence()
        }
    }

    private func animateSequence() {
        // Dot 1 jumps immediately
        activeDot = 0
        
        // Dot 2 jumps after 0.18s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            activeDot = 1
        }
        
        // Dot 3 jumps after 0.36s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            activeDot = 2
        }
        
        // All dots land at 0.54s
        // The Timer waits until 1.1s to restart, creating a ~0.56s pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            activeDot = -1
        }
    }
}

#Preview {
    TypingIndicator()
}
