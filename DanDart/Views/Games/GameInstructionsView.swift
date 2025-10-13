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
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Game Title
                    Text(game.name)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color("AccentPrimary"))
                        .padding(.top, 20)
                    
                    // Game Description
                    Text(gameDescription)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color("TextPrimary"))
                        .lineSpacing(4)
                    
                    // Objective Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objective")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                        
                        Text(gameObjective)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color("TextPrimary"))
                            .lineSpacing(4)
                    }
                    
                    // How to Play Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Play")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(gameRules, id: \.self) { rule in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color("AccentSecondary"))
                                    
                                    Text(rule)
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(Color("TextPrimary"))
                                        .lineSpacing(4)
                                }
                            }
                        }
                    }
                    
                    // Scoring Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scoring")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                        
                        Text(scoringRules)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color("TextPrimary"))
                            .lineSpacing(4)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(Color("BackgroundPrimary"))
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
            }
        }
    }
    
    // MARK: - Game Content
    
    private var gameDescription: String {
        switch game.name {
        case "301":
            return "301 is a classic dart game where players start with 301 points and work their way down to exactly zero."
        case "501":
            return "501 is the most popular dart game worldwide. Players start with 501 points and race to reach exactly zero."
        default:
            return "A classic dart game that tests your accuracy and strategy."
        }
    }
    
    private var gameObjective: String {
        switch game.name {
        case "301", "501":
            return "Be the first player to reduce your score from \(game.name) to exactly zero points."
        default:
            return "Follow the game rules to achieve the winning condition."
        }
    }
    
    private var gameRules: [String] {
        switch game.name {
        case "301", "501":
            return [
                "Each player takes turns throwing 3 darts",
                "Subtract your dart scores from your starting total",
                "You must finish on exactly zero points",
                "If you go below zero or land on zero with remaining darts, you 'bust'",
                "When you bust, your score returns to what it was at the start of your turn",
                "The first player to reach exactly zero wins"
            ]
        default:
            return [
                "Each player takes turns throwing 3 darts",
                "Follow the specific rules for this game variant",
                "The first player to achieve the winning condition wins"
            ]
        }
    }
    
    private var scoringRules: String {
        return """
        • Numbers 1-20: Score the number hit
        • 25: Single bull (outer bullseye)
        • Bull: Double bull (inner bullseye) = 50 points
        • Miss: No points scored
        • Bust: Turn ends, score reverts to start of turn
        """
    }
}

#Preview {
    GameInstructionsView(game: Game.preview301)
}
