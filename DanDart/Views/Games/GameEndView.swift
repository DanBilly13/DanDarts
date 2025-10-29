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
    let matchFormat: Int?
    let legsWon: [UUID: Int]?
    let matchId: UUID? // For navigating to match details
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCelebration = false
    @State private var showMatchDetails = false
    
    // Computed property for match result text
    private var matchResultText: String? {
        guard let matchFormat = matchFormat,
              let legsWon = legsWon,
              matchFormat > 1 else {
            return nil
        }
        
        let winnerLegs = legsWon[winner.id] ?? 0
        let loser = players.first { $0.id != winner.id }
        let loserLegs = loser.flatMap { legsWon[$0.id] } ?? 0
        
        return "\(winnerLegs)-\(loserLegs)"
    }
    
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
                    
                    // Match result (if multi-leg)
                    if let resultText = matchResultText {
                        Text("Wins \(resultText)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color("AccentPrimary"))
                            .opacity(showCelebration ? 1.0 : 0.0)
                            .animation(.easeIn(duration: 0.3).delay(0.5), value: showCelebration)
                    }
                    
                    // Celebration Message
                    Text("🎯 Perfect Finish! 🎯")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("AccentPrimary"))
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.3).delay(0.6), value: showCelebration)
                    
                    // Match Details Link
                    if matchId != nil {
                        Button(action: {
                            showMatchDetails = true
                        }) {
                            Text("View Match Details")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("AccentSecondary"))
                                .underline()
                        }
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.3).delay(0.7), value: showCelebration)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Play Again Button (same players)
                    AppButton(role: .primary, controlSize: .small, compact: true) {
                        onPlayAgain()
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                    }
                    
                    // Back to Games Button
                    AppButton(role: .secondary, controlSize: .small, compact: true) {
                        onBackToGames()
                    } label: {
                        Label("Back to Games", systemImage: "house.fill")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .opacity(showCelebration ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.8), value: showCelebration)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showMatchDetails) {
            // Navigate to Match Detail View
            if let matchId = matchId,
               let matchResult = MatchStorageManager.shared.loadMatch(byId: matchId) {
                NavigationStack {
                    MatchDetailView(match: matchResult)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showMatchDetails = false
                                }
                                .fontWeight(.semibold)
                                .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                // Fallback if match not found
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(Color("AccentSecondary"))
                    
                    Text("Match details not available")
                        .font(.headline)
                        .foregroundColor(Color("TextPrimary"))
                    
                    Text("The match is being saved...")
                        .font(.subheadline)
                        .foregroundColor(Color("TextSecondary"))
                    
                    Button("Close") {
                        showMatchDetails = false
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
                .padding(40)
            }
        }
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
        onBackToGames: { print("Back to Games") },
        matchFormat: nil,
        legsWon: nil,
        matchId: UUID()
    )
}

#Preview("Game End - Multi-Leg Match") {
    let player1 = Player.mockGuest1
    let player2 = Player.mockGuest2
    
    GameEndView(
        game: Game.preview301,
        winner: player1,
        players: [player1, player2],
        onPlayAgain: { print("Play Again") },
        onChangePlayers: { print("Change Players") },
        onBackToGames: { print("Back to Games") },
        matchFormat: 3,
        legsWon: [player1.id: 2, player2.id: 1],
        matchId: UUID()
    )
}
