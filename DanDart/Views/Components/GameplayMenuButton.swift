//
//  GameplayMenuButton.swift
//  Dart Freak
//
//  Reusable menu button for gameplay screens
//  Provides consistent styling across all game modes
//

import SwiftUI

struct GameplayMenuButton: View {
    let onInstructions: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        Menu {
            Button("Instructions") { 
                onInstructions() 
            }
            Button("Restart Game") { 
                onRestart() 
            }
            Button("Quit Game", role: .destructive) {
                onExit()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("InteractiveSecondaryBackground"))
        }
    }
}

#Preview {
    GameplayMenuButton(
        onInstructions: { print("Instructions") },
        onRestart: { print("Restart") },
        onExit: { print("Exit") }
    )
}
