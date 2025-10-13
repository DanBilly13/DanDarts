//
//  GameCard.swift
//  DanDart
//
//  Game card component for displaying dart games in the games list
//

import SwiftUI

struct GameCard: View {
    let game: Game
    let onPlayTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Game Info Section
            VStack(alignment: .leading, spacing: 8) {
                // Game Title - Simple text to avoid crashes
                Text(game.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Subtitle - Simple text
                Text(game.subtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
                
                // Players info
                Text("Players: \(game.players)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // Simple Play Button
            HStack {
                Spacer()
                
                Button(action: onPlayTapped) {
                    Text("Play")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color("InputBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Custom Button Style

struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - GameCard with 90% Width Container

struct GameCardContainer: View {
    let game: Game
    let onPlayTapped: () -> Void
    
    var body: some View {
        GameCard(game: game, onPlayTapped: onPlayTapped)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .infinity)
            // 90% width calculation: 10% padding split between sides = 5% each
            .padding(.horizontal, UIScreen.main.bounds.width * 0.05)
    }
}

// MARK: - Preview
#Preview("Game Card - 301") {
    VStack(spacing: 20) {
        GameCard(game: Game.preview301) {
            print("Play 301 tapped")
        }
        
        GameCard(game: Game.preview501) {
            print("Play 501 tapped")
        }
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}

#Preview("Game Card - All Games") {
    ScrollView {
        LazyVStack(spacing: 16) {
            ForEach(Game.loadGames()) { game in
                GameCard(game: game) {
                    print("Play \(game.title) tapped")
                }
            }
        }
        .padding()
    }
    .background(Color("BackgroundPrimary"))
}

#Preview("Game Card - 90% Width") {
    ScrollView {
        LazyVStack(spacing: 16) {
            ForEach(Array(Game.loadGames().prefix(3))) { game in
                GameCard(game: game) {
                    print("Play \(game.title) tapped")
                }
            }
        }
        .padding(.vertical)
    }
    .background(Color("BackgroundPrimary"))
}

#Preview("Game Card - Dark Mode") {
    VStack(spacing: 20) {
        GameCard(game: Game.previewHalveIt) {
            print("Play Halve-It tapped")
        }
        
        GameCard(game: Game.preview301) {
            print("Play 301 tapped")
        }
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
