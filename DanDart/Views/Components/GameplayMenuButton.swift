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
    var onUndo: (() -> Void)? = nil
    var canUndo: Bool = false
    
    var body: some View {
        Menu {
            Button("Instructions") { 
                onInstructions() 
            }
            
            if canUndo, let undoAction = onUndo {
                Button(action: undoAction) {
                    Label("Undo Last Visit", systemImage: "arrow.uturn.backward.circle")
                }
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
