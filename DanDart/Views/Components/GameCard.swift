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
                // Game Name - Simple text to avoid crashes
                Text(game.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Tagline - Simple text
                Text(game.tagline)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
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
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(Color.gray.opacity(0.1))
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
            ForEach(Game.mockGames) { game in
                GameCard(game: game) {
                    print("Play \(game.name) tapped")
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
            ForEach(Game.mockGames.prefix(3)) { game in
                GameCardContainer(game: game) {
                    print("Play \(game.name) tapped")
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
    }
    .padding()
    .background(Color("BackgroundPrimary"))
    .preferredColorScheme(.dark)
}
