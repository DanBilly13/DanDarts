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
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Score to beat")
                .font(.caption)
                .foregroundColor(Color("TextSecondary"))
            
            HStack(spacing: 8) {
                Text("\(score)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(Color("AccentPrimary"))
                
                Image("skull")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
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
            ScoreToBeatView(score: 0)
            ScoreToBeatView(score: 180)
        }
    }
}
