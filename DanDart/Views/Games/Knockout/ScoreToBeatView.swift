//
//  ScoreToBeatView.swift
//  DanDart
//
//  Score to beat display for Sudden Death game
//  Shows the current high score that players must beat to stay in the game
//

import SwiftUI

struct ScoreToBeatView: View {
    let score: Int
    let showScoreAnimation: Bool
    let showSkullWiggle: Bool
    
    @State private var wiggleAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 4) {
            /*Text("Score to beat")
                .font(.caption)
                .foregroundColor(Color("TextSecondary"))*/
            
            HStack(spacing: 8) {
                Text("\(score)")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(Color("AccentPrimary"))
                    .scaleEffect(showScoreAnimation ? 1.35 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.4), value: showScoreAnimation)
                
                Image("BoxingGloveLeft")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: 36, height: 26)
                    .rotationEffect(.degrees(wiggleAngle))
                    .scaleEffect(showSkullWiggle ? 1.8 : 1.0)
                    .onChange(of: showSkullWiggle) { _, newValue in
                        if newValue {
                            withAnimation(.easeInOut(duration: 0.08).repeatCount(6, autoreverses: true)) {
                                wiggleAngle = 12
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                wiggleAngle = 0 // reset to neutral
                            }
                        }
                    }
            }
        }
        .padding(.vertical, 0)
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            ScoreToBeatView(score: 0, showScoreAnimation: false, showSkullWiggle: false)
            ScoreToBeatView(score: 180, showScoreAnimation: false, showSkullWiggle: false)
        }
    }
}
