//
//  GameInstructionsView.swift
//  DanDart
//
//  Game instructions sheet for displaying rules and gameplay
//

import SwiftUI

struct GameInstructionsView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        StandardSheetView(
            title: game.title,
            dismissButtonTitle: "Done",
            onDismiss: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: 24) {
                // Game Subtitle
                if !game.subtitle.isEmpty {
                    Text(game.subtitle)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextSecondary"))
                }
                
                // Players
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundColor(Color("AccentSecondary"))
                    
                    Text(game.players)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextPrimary"))
                }
                
                // Divider
                Divider()
                    .background(Color("TextSecondary").opacity(0.3))
                
                // Instructions from JSON
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to Play")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("AccentPrimary"))
                    
                    Text(game.instructions)
                        .font(.body)
                        .foregroundColor(Color("TextPrimary"))
                        .lineSpacing(6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    GameInstructionsView(game: Game.preview301)
}
