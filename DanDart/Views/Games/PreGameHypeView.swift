//
//  PreGameHypeView.swift
//  DanDart
//
//  Pre-game hype screen with boxing match style presentation
//

import SwiftUI

struct PreGameHypeView: View {
    let game: Game
    let players: [Player]
    
    // Navigation state
    @State private var navigateToGameplay = false
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationManager = NavigationManager.shared
    
    // Animation states
    @State private var showPlayer1 = false
    @State private var showPlayer2 = false
    @State private var showVS = false
    @State private var showGetReady = false
    
    var body: some View {
            GeometryReader { geometry in
                ZStack {
                    // Solid black background to prevent white page
                    Color.black
                        .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Game name at top
                    VStack(spacing: 8) {
                        Text(game.title)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Text("MATCH STARTING")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(Color("AccentPrimary"))
                            .tracking(2)
                    }
                    .padding(.top, 60)
                    
                    Spacer()
                    
                    // Players and VS section
                    HStack(spacing: 0) {
                        // Player 1 (Left side)
                        VStack(spacing: 16) {
                            // Avatar
                            PlayerAvatarView(
                                avatarURL: players.first?.avatarURL,
                                size: 120,
                                borderColor: Color("AccentPrimary")
                            )
                            .scaleEffect(showPlayer1 ? 1.0 : 0.8)
                            .opacity(showPlayer1 ? 1.0 : 0.0)
                            .offset(x: showPlayer1 ? 0 : -100)
                            
                            // Player name and nickname
                            VStack(spacing: 4) {
                                Text(players.first?.displayName ?? "Player 1")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                    .opacity(showPlayer1 ? 1.0 : 0.0)
                                
                                Text("@\(players.first?.nickname ?? "player1")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                    .opacity(showPlayer1 ? 1.0 : 0.0)
                            }
                            
                            // Stats
                            HStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    Text("\(players.first?.totalWins ?? 0)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color("AccentPrimary"))
                                    Text("WINS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color("TextSecondary"))
                                        .tracking(1)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(players.first?.totalLosses ?? 0)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color("TextSecondary"))
                                    Text("LOSSES")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color("TextSecondary"))
                                        .tracking(1)
                                }
                            }
                            .opacity(showPlayer1 ? 1.0 : 0.0)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // VS in center
                        VStack(spacing: 8) {
                            Text("VS")
                                .font(.system(size: 48, weight: .black, design: .default))
                                .foregroundColor(Color("AccentPrimary"))
                                .scaleEffect(showVS ? 1.0 : 0.5)
                                .opacity(showVS ? 1.0 : 0.0)
                            
                            Rectangle()
                                .fill(Color("AccentPrimary"))
                                .frame(width: 40, height: 2)
                                .opacity(showVS ? 1.0 : 0.0)
                        }
                        .frame(width: 100)
                        
                        // Player 2 (Right side)
                        VStack(spacing: 16) {
                            // Avatar
                            PlayerAvatarView(
                                avatarURL: players.count > 1 ? players[1].avatarURL : nil,
                                size: 120,
                                borderColor: Color("AccentSecondary")
                            )
                            .scaleEffect(showPlayer2 ? 1.0 : 0.8)
                            .opacity(showPlayer2 ? 1.0 : 0.0)
                            .offset(x: showPlayer2 ? 0 : 100)
                            
                            // Player name and nickname
                            VStack(spacing: 4) {
                                Text(players.count > 1 ? players[1].displayName : "Player 2")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                    .opacity(showPlayer2 ? 1.0 : 0.0)
                                
                                Text("@\(players.count > 1 ? players[1].nickname : "player2")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                    .opacity(showPlayer2 ? 1.0 : 0.0)
                            }
                            
                            // Stats
                            HStack(spacing: 12) {
                                VStack(spacing: 2) {
                                    Text("\(players.count > 1 ? players[1].totalWins : 0)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color("AccentSecondary"))
                                    Text("WINS")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color("TextSecondary"))
                                        .tracking(1)
                                }
                                
                                VStack(spacing: 2) {
                                    Text("\(players.count > 1 ? players[1].totalLosses : 0)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color("TextSecondary"))
                                    Text("LOSSES")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color("TextSecondary"))
                                        .tracking(1)
                                }
                            }
                            .opacity(showPlayer2 ? 1.0 : 0.0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // GET READY section at bottom
                    VStack(spacing: 16) {
                        Text("GET READY! 🎯")
                            .font(.system(size: 32, weight: .black, design: .default))
                            .foregroundColor(Color("AccentPrimary"))
                            .tracking(2)
                            .scaleEffect(showGetReady ? 1.0 : 0.8)
                            .opacity(showGetReady ? 1.0 : 0.0)
                        
                        Text("Tap to skip")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("TextSecondary"))
                            .opacity(showGetReady ? 0.7 : 0.0)
                    }
                    .padding(.bottom, 60)
                }
                } // End of conditional content
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .onAppear {
                // Check if we should dismiss immediately (from cancel game)
                if navigationManager.shouldDismissToGamesList {
                    navigationManager.resetDismissFlag()
                    dismiss()
                    return
                }
                
                startAnimationSequence()
                // Play boxing sound when view appears
                SoundManager.shared.playBoxingSound()
            }
            .onChange(of: navigationManager.shouldDismissToGamesList) {
                if navigationManager.shouldDismissToGamesList {
                    navigationManager.resetDismissFlag()
                    dismiss()
                }
            }
        .onTapGesture {
            navigateToGameplay = true
        }
        .navigationDestination(isPresented: $navigateToGameplay) {
            GameplayView(game: game, players: players)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Animation Sequence
    
    private func startAnimationSequence() {
        // Player 1 slides in from left
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            showPlayer1 = true
        }
        
        // Player 2 slides in from right (slight delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showPlayer2 = true
            }
        }
        
        // VS appears with scale animation (after players)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showVS = true
            }
        }
        
        // GET READY appears last
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                showGetReady = true
            }
        }
        
        // Auto-transition to gameplay after 3 seconds total
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            navigateToGameplay = true
        }
    }
}

// MARK: - Preview
#Preview("Pre-Game Hype - 301") {
    PreGameHypeView(
        game: Game.preview301,
        players: [Player.mockGuest1, Player.mockGuest2]
    )
}

#Preview("Pre-Game Hype - 501") {
    PreGameHypeView(
        game: Game.preview501,
        players: [Player.mockConnected1, Player.mockConnected2]
    )
}

#Preview("Pre-Game Hype - Single Player") {
    PreGameHypeView(
        game: Game.previewHalveIt,
        players: [Player.mockGuest1]
    )
}
