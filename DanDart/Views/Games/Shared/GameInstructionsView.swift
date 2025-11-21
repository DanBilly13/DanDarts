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
            GameInstructionsContent(game: game)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GameInstructionsContent: View {
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Game Subtitle
            
            if !game.subtitle.isEmpty {
                Text(game.subtitle)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.textSecondary)
            }
            
            // Players
            
            
            // Divider
            Divider()
                .background(AppColor.textSecondary.opacity(0.3))
            
            // Instructions from JSON
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("How to Play")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.body)
                            .foregroundColor(AppColor.interactiveSecondaryBackground)
                        
                        Text(game.players)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
                
                
                Text(game.instructions)
                    .font(.body)
                    .foregroundColor(AppColor.textPrimary)
                    .lineSpacing(6)
            }
        }
    }
}

#Preview {
    GameInstructionsView(game: Game.preview301)
}
