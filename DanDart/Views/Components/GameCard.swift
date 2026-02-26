//
//  GameCard.swift
//  Dart Freak
//
//  Game card component for displaying dart games in the games list
//

import SwiftUI
import UIKit

struct GameCard: View {
    let game: Game
    let onPlayTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Artwork Header
            ZStack(alignment: .bottomLeading) {
                Group {
                    if UIImage(named: game.coverImageName) != nil {
                        Image(game.coverImageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 188)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                AppColor.brandPrimary.opacity(0.6),
                                AppColor.brandPrimary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 188)
                    }
                }
                
                // Bottom-left angled readability gradient (lighter)
           
                
                // Title overlay for a bit of App Store feel
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.title)
                        .font(.system(.largeTitle, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            
            // Info + Play section
            HStack(alignment: .center) {
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.subtitle)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(2)
                       
                    
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        Text(game.players)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                    
                }
                
                Spacer()
                
                AppButton(role: .primary, controlSize: .regular, compact: true) {
                    onPlayTapped()
                } label: {
                    Text("Play")
                        .bold()
                }
                .frame(width: 88)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppColor.inputBackground)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onPlayTapped()
        }
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
#if DEBUG
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
    .background(AppColor.backgroundPrimary)
}
#endif

#if DEBUG
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
    .background(AppColor.backgroundPrimary)
}
#endif

#if DEBUG
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
    .background(AppColor.backgroundPrimary)
}
#endif

#if DEBUG
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
#endif
