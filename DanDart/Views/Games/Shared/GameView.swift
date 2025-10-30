//
//  GameView.swift
//  DanDart
//
//  Active game screen for playing dart games
//

import SwiftUI

struct GameView: View {
    let game: Game
    let playerNames: [String]
    @State private var currentPlayerIndex: Int = 0
    @State private var playerScores: [Int] = []
    @State private var dartScores: [Int] = [0, 0, 0] // Current turn's dart scores
    @State private var currentDart: Int = 0 // Which dart (0, 1, or 2)
    @State private var gameCompleted: Bool = false
    @State private var winner: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    var currentPlayer: String {
        playerNames[currentPlayerIndex]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar with Back Button
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Setup")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
                
                Spacer()
                
                Text(game.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                // Placeholder for balance
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Setup")
                        .font(.system(size: 16, weight: .medium))
                }
                .opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color("BackgroundPrimary"))
            
            ScrollView {
                VStack(spacing: 24) {
                    // Current Player Section
                    VStack(spacing: 16) {
                        Text("Current Player")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                        
                        Text(currentPlayer)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color("AccentPrimary"))
                        
                        Text("Dart \(currentDart + 1) of 3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .padding(20)
                    .background(Color("InputBackground"))
                    .cornerRadius(16)
                    
                    // Scores Section
                    VStack(spacing: 16) {
                        Text("Scores")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        VStack(spacing: 12) {
                            ForEach(Array(playerNames.enumerated()), id: \.offset) { index, playerName in
                                HStack {
                                    // Player name
                                    Text(playerName.isEmpty ? "Player \(index + 1)" : playerName)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(index == currentPlayerIndex ? Color("AccentPrimary") : Color("TextPrimary"))
                                    
                                    Spacer()
                                    
                                    // Score
                                    Text("\(playerScores[safe: index] ?? getInitialScore())")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(index == currentPlayerIndex ? Color("AccentPrimary") : Color("TextPrimary"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(index == currentPlayerIndex ? Color("AccentPrimary").opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color("InputBackground"))
                    .cornerRadius(16)
                    
                    // Current Turn Section
                    VStack(spacing: 16) {
                        Text("Current Turn")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { dartIndex in
                                VStack(spacing: 8) {
                                    Text("Dart \(dartIndex + 1)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color("TextSecondary"))
                                    
                                    Text("\(dartScores[dartIndex])")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(dartIndex == currentDart ? Color("AccentPrimary") : Color("TextPrimary"))
                                        .frame(width: 60, height: 60)
                                        .background(dartIndex == currentDart ? Color("AccentPrimary").opacity(0.1) : Color("InputBackground"))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(dartIndex == currentDart ? Color("AccentPrimary") : Color.clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        
                        Text("Turn Total: \(dartScores.reduce(0, +))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                    }
                    .padding(20)
                    .background(Color("InputBackground"))
                    .cornerRadius(16)
                    
                    // Score Input Section
                    VStack(spacing: 16) {
                        Text("Enter Score")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        // Quick score buttons
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 25, 50], id: \.self) { score in
                                Button(action: {
                                    enterScore(score)
                                }) {
                                    Text("\(score)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(height: 44)
                                        .frame(maxWidth: .infinity)
                                        .background(Color("AccentPrimary"))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(Color("InputBackground"))
                    .cornerRadius(16)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            
            // Bottom Action Buttons
            VStack(spacing: 12) {
                if currentDart < 2 {
                    Button(action: {
                        nextDart()
                    }) {
                        Text("Next Dart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        endTurn()
                    }) {
                        Text("End Turn")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("AccentPrimary"))
                            .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    undoLastDart()
                }) {
                    Text("Undo Last Dart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("AccentPrimary"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                }
                .disabled(currentDart == 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .background(Color("BackgroundPrimary"))
        }
        .background(Color("BackgroundPrimary"))
        .navigationBarHidden(true)
        .onAppear {
            initializeGame()
        }
        .alert("Game Complete!", isPresented: $gameCompleted) {
            Button("New Game") {
                // TODO: Reset game or navigate back
                dismiss()
            }
            Button("Back to Menu") {
                dismiss()
            }
        } message: {
            if let winner = winner {
                Text("\(winner) wins!")
            }
        }
    }
    
    // MARK: - Game Logic
    
    private func initializeGame() {
        // Initialize player scores based on game type
        playerScores = Array(repeating: getInitialScore(), count: playerNames.count)
    }
    
    private func getInitialScore() -> Int {
        switch game.title {
        case "301":
            return 301
        case "501":
            return 501
        default:
            return 301 // Default fallback
        }
    }
    
    private func enterScore(_ score: Int) {
        dartScores[currentDart] = score
    }
    
    private func nextDart() {
        if currentDart < 2 {
            currentDart += 1
        }
    }
    
    private func undoLastDart() {
        if currentDart > 0 {
            currentDart -= 1
            dartScores[currentDart] = 0
        }
    }
    
    private func endTurn() {
        let turnTotal = dartScores.reduce(0, +)
        
        // Apply score based on game type
        if game.title == "301" || game.title == "501" {
            // Countdown games
            let newScore = playerScores[currentPlayerIndex] - turnTotal
            
            // Check for valid finish (must end on exactly 0)
            if newScore == 0 {
                // Player wins!
                winner = currentPlayer
                gameCompleted = true
                return
            } else if newScore < 0 {
                // Bust - score stays the same
                // Don't update the score
            } else {
                // Valid score
                playerScores[currentPlayerIndex] = newScore
            }
        }
        
        // Reset for next turn
        dartScores = [0, 0, 0]
        currentDart = 0
        
        // Move to next player
        currentPlayerIndex = (currentPlayerIndex + 1) % playerNames.count
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview
#Preview {
    GameView(game: Game.preview301, playerNames: ["Alice", "Bob"])
}

#Preview("GameView - 501") {
    GameView(game: Game.preview501, playerNames: ["Player 1", "Player 2", "Player 3"])
}
