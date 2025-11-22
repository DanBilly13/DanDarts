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
        VStack(alignment: .leading, spacing: 32) {
            
            /*
             // Game Subtitle
             
             if !game.subtitle.isEmpty {
             Text(game.subtitle)
             .font(.title3)
             .fontWeight(.medium)
             .foregroundColor(AppColor.textSecondary)
             }*/
             
             // Players
             
             
             // Divider
             Divider()
             .background(AppColor.textSecondary.opacity(0.3))
             
            // Instructions from JSON
            VStack(alignment: .leading, spacing: 16) {
                Text("How to Play")
                    .font(.system(.headline, design: .rounded))  .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                
                HStack(spacing: 8) {
                    
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                    
                    Text("\(game.players) players")
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textPrimary)
                }
                
                Text(game.instructions)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textSecondary)
                    .lineSpacing(6)
            }
        }
    }
}

#Preview {
    GameInstructionsView(game: Game.preview301)
}
