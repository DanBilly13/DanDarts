//
//  GameSetupView.swift
//  DanDart
//
//  Game setup screen for configuring players and game options
//

import SwiftUI

struct GameSetupView: View {
    let game: Game
    @State private var selectedPlayers: [Player] = []
    @State private var showSearchPlayer: Bool = false
    @State private var showGameView: Bool = false
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationManager = NavigationManager.shared
    
    private let playerLimit = 8 // Maximum players for MVP
    private var canStartGame: Bool {
        selectedPlayers.count >= 2
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
                        Text("Games")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("AccentPrimary"))
                }
                
                Spacer()
                
                Text("Setup")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color("TextPrimary"))
                
                Spacer()
                
                // Placeholder for balance
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Games")
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
                    // Game Info Section
                    VStack(spacing: 16) {
                        // Game Title and Description
                        VStack(spacing: 8) {
                            Text(game.title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text(game.subtitle)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .multilineTextAlignment(.center)
                        }
                        
                        // Game Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to Play")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text(game.instructions)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color("TextSecondary"))
                                .lineLimit(nil)
                        }
                        .padding(16)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                    }
                    
                    // Player Selection Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Players")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Spacer()
                            
                            Text("\(selectedPlayers.count) of \(playerLimit)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                        
                        // Sequential Player Addition
                        VStack(spacing: 12) {
                            // Show selected players first
                            ForEach(Array(selectedPlayers.enumerated()), id: \.element.id) { index, player in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Player \(index + 1)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("AccentPrimary"))
                                        Spacer()
                                    }
                                    
                                    PlayerCard(player: player, showRemoveButton: true) {
                                        removePlayer(player)
                                    }
                                }
                            }
                            
                            // Add next player button (if under limit)
                            if selectedPlayers.count < playerLimit {
                                Button(action: {
                                    showSearchPlayer = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                        Text("Add Player \(selectedPlayers.count + 1)")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(Color("AccentPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color("InputBackground"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("AccentPrimary"), lineWidth: 2)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        // Empty state when no players
                        if selectedPlayers.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "person.2.badge.plus")
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundColor(Color("TextSecondary"))
                                
                                Text("Add players to start the game")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                                
                                Text("You need at least 2 players")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(Color("TextSecondary").opacity(0.7))
                            }
                            .padding(.vertical, 32)
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            
            // Start Game Button
            VStack(spacing: 16) {
                AppButton(role: .primary, controlSize: .regular, isDisabled: !canStartGame) {
                    showGameView = true
                } label: {
                    Text("Start Game").bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)

                if !canStartGame && selectedPlayers.count == 1 {
                    Text("Add at least one more player")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 16)
            .background(Color("BackgroundPrimary"))
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showGameView) {
                // Always show black background to prevent white flash
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if !navigationManager.shouldDismissToGamesList {
                        PreGameHypeView(game: game, players: selectedPlayers)
                    }
                }
            }
            .onChange(of: navigationManager.shouldDismissToGamesList) {
                if navigationManager.shouldDismissToGamesList {
                    navigationManager.resetDismissFlag()
                    dismiss()
                }
            }
            .sheet(isPresented: $showSearchPlayer) {
                SearchPlayerSheet { player in
                    addPlayer(player)
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func addPlayer(_ player: Player) {
        if selectedPlayers.count < playerLimit && !selectedPlayers.contains(where: { $0.id == player.id }) {
            selectedPlayers.append(player)
        }
    }
    
    private func removePlayer(_ player: Player) {
        selectedPlayers.removeAll { $0.id == player.id }
    }
}

// MARK: - Placeholder Sheet Components

struct SearchPlayerSheet: View {
    let onPlayerSelected: (Player) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAddGuestPlayer = false
    
    // Mock current user - in real app this would come from AuthService
    private let currentUser = User.mockUser1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(Color("AccentPrimary"))
                    }
                    
                    Spacer()
                    
                    // Add Guest button
                    AppButton(role: .primary, controlSize: .small, compact: true) {
                        showAddGuestPlayer = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Guest")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(width: 100)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("BackgroundPrimary"))
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Add Player")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text("Choose yourself, a friend, or add a new guest")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)
                        
                        // Current User Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("You")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                Spacer()
                            }
                            
                            Button(action: {
                                // Convert User to Player
                                let currentUserAsPlayer = Player(
                                    displayName: currentUser.displayName,
                                    nickname: currentUser.nickname,
                                    avatarURL: currentUser.avatarURL,
                                    isGuest: false,
                                    totalWins: currentUser.totalWins,
                                    totalLosses: currentUser.totalLosses
                                )
                                onPlayerSelected(currentUserAsPlayer)
                                dismiss()
                            }) {
                                PlayerCard(player: Player(
                                    displayName: currentUser.displayName,
                                    nickname: currentUser.nickname,
                                    avatarURL: currentUser.avatarURL,
                                    isGuest: false,
                                    totalWins: currentUser.totalWins,
                                    totalLosses: currentUser.totalLosses
                                ))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Friends section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Your Friends")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(Player.mockConnectedPlayers, id: \.id) { player in
                                    Button(action: {
                                        onPlayerSelected(player)
                                        dismiss()
                                    }) {
                                        PlayerCard(player: player)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .background(Color("BackgroundPrimary"))
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddGuestPlayer) {
                AddGuestPlayerView { player in
                    onPlayerSelected(player)
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    GameSetupView(game: Game.preview301)
}

#Preview("GameSetup - 501") {
    GameSetupView(game: Game.preview501)
}

#Preview("GameSetup - Dark Mode") {
    GameSetupView(game: Game.previewHalveIt)
        .preferredColorScheme(.dark)
}
