//
//  GameEndView.swift
//  DanDart
//
//  Game end screen showing winner and celebration
//  Design: Dark dramatic with winner spotlight
//

import SwiftUI

struct GameEndView: View {
    let game: Game
    let winner: Player
    let players: [Player]
    let onPlayAgain: () -> Void
    let onChangePlayers: () -> Void
    let onBackToGames: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCelebration = false
    
    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color("BackgroundPrimary"),
                    Color.black,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Winner Section
                VStack(spacing: 24) {
                    // Trophy/Crown Icon
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(Color("AccentPrimary"))
                        .shadow(color: Color("AccentPrimary").opacity(0.5), radius: 20, x: 0, y: 0)
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showCelebration)
                    
                    // Winner Avatar
                    PlayerAvatarView(
                        avatarURL: winner.avatarURL,
                        size: 120,
                        borderColor: Color("AccentPrimary")
                    )
                    .shadow(color: Color("AccentPrimary").opacity(0.4), radius: 30, x: 0, y: 10)
                    .scaleEffect(showCelebration ? 1.0 : 0.8)
                    .opacity(showCelebration ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showCelebration)
                    
                    // Winner Name
                    VStack(spacing: 8) {
                        Text("WINNER!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color("AccentPrimary"))
                            .tracking(2)
                        
                        Text(winner.displayName)
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("@\(winner.nickname)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color("TextSecondary"))
                    }
                    .scaleEffect(showCelebration ? 1.0 : 0.8)
                    .opacity(showCelebration ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: showCelebration)
                    
                    // Celebration Message
                    Text("🎯 Perfect Finish! 🎯")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("AccentPrimary"))
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.3).delay(0.6), value: showCelebration)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Play Again Button (same players)
                    Button(action: {
                        onPlayAgain()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Play Again")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color("AccentPrimary"))
                        )
                        .shadow(color: Color("AccentPrimary").opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    // New Game Button (same game, different players)
                    Button(action: {
                        onChangePlayers()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Change Players")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color("TextPrimary"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(Color("InputBackground"))
                        )
                    }
                    
                    // Back to Games Button
                    Button(action: {
                        onBackToGames()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Back to Games")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(Color("TextSecondary"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(Color("TextSecondary").opacity(0.3), lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showCelebration ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.7), value: showCelebration)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            // Trigger celebration animation
            withAnimation {
                showCelebration = true
            }
            
            // Play celebration sound
            SoundManager.shared.playGameWin()
        }
    }
}

// MARK: - Preview
#Preview("Game End - 301") {
    GameEndView(
        game: Game.preview301,
        winner: Player.mockGuest1,
        players: [Player.mockGuest1, Player.mockGuest2],
        onPlayAgain: { print("Play Again") },
        onChangePlayers: { print("Change Players") },
        onBackToGames: { print("Back to Games") }
    )
}

#Preview("Game End - Connected Player") {
    GameEndView(
        game: Game.preview501,
        winner: Player.mockConnected1,
        players: [Player.mockConnected1, Player.mockGuest1],
        onPlayAgain: { print("Play Again") },
        onChangePlayers: { print("Change Players") },
        onBackToGames: { print("Back to Games") }
    )
}
