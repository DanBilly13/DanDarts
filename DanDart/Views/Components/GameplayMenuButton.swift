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
    
    @ObservedObject private var soundManager = SoundManager.shared
    
    var body: some View {
        Menu {
            Button {
                onInstructions()
            } label: {
                Label("Instructions", systemImage: "info.circle")
            }
            
            // Sound Effects Toggle
            Button {
                soundManager.soundEffectsEnabled.toggle()
            } label: {
                Label {
                    Text("Sound Effects")
                } icon: {
                    Image(systemName: soundManager.soundEffectsEnabled ? "speaker.wave.2" : "speaker.slash")
                        .foregroundColor(soundManager.soundEffectsEnabled ? .green : .red)
                }
            }
            
            Divider()
            
            if canUndo, let undoAction = onUndo {
                Button(action: undoAction) {
                    Label("Undo Last Visit", systemImage: "arrow.uturn.backward.circle")
                }
            }
            
            Button {
                onRestart()
            } label: {
                Label("Restart Game", systemImage: "restart.circle")
            }
            
            Button(role: .destructive) {
                onExit()
            } label: {
                Label {
                    Text("Quit Game")
                } icon: {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
            }
        } label: {
            Image(systemName: "questionmark")
                .font(.system(size: 14, weight: .semibold))
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
