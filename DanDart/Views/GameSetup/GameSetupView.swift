//
//  GameSetupView.swift
//  DanDart
//
//  Generic game setup view that works for all game types
//  Uses GameSetupConfigurable protocol for game-specific options
//

import SwiftUI

struct GameSetupView: View {
    let config: any GameSetupConfigurable
    
    @State private var selectedPlayers: [Player] = []
    @State private var showSearchPlayer: Bool = false
    @State private var showGameView: Bool = false
    @State private var selectedOption: Int = 0
    @Environment(\.dismiss) private var dismiss
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var friendsCache = FriendsCache()
    @EnvironmentObject private var authService: AuthService
    
    private var canStartGame: Bool {
        selectedPlayers.count >= 2
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main content with ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header with Cover Image
                    ZStack(alignment: .bottomLeading) {
                        // Cover Image
                        if let coverImage = UIImage(named: "game-cover/\(config.game.title)") {
                            Image(uiImage: coverImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 280)
                                .clipped()
                        } else {
                            // Fallback gradient if no image
                            LinearGradient(
                                colors: [
                                    Color("AccentPrimary").opacity(0.6),
                                    Color("AccentPrimary").opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: 280)
                        }
                        
                        // Gradient overlay for text readability
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 280)
                        
                        // Game Title
                        Text(config.game.title)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.leading, 20)
                            .padding(.bottom, 24)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    
                    // Content below header
                    VStack(spacing: 24) {
                        // Game-specific Options Section (if applicable)
                        if config.showOptions {
                            VStack(spacing: 16) {
                                HStack {
                                    Text(config.optionLabel)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color("TextPrimary"))
                                    
                                    Spacer()
                                }
                                
                                // Game-specific segmented control
                                config.optionView(selection: $selectedOption)
                            }
                        }
                        
                        // Player Selection Section
                        VStack(spacing: 16) {
                            HStack {
                                Text("Players")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color("TextPrimary"))
                                
                                Spacer()
                                
                                Text("\(selectedPlayers.count) of \(config.playerLimit)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                            
                            // Sequential Player Addition
                            VStack(spacing: 12) {
                                // Show selected players in a List for swipe actions
                                List {
                                    ForEach(Array(selectedPlayers.enumerated()), id: \.element.id) { index, player in
                                        PlayerCard(player: player, playerNumber: index + 1)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button {
                                                    removePlayer(player)
                                                } label: {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                                .tint(.clear)
                                            }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(selectedPlayers.count * 92)) // 80pt card + 12pt spacing
                                .background(Color.clear)
                                
                                // Add next player button (if under limit)
                                if selectedPlayers.count < config.playerLimit {
                                    AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
                                        showSearchPlayer = true
                                    } label: {
                                        Label("Add Player \(selectedPlayers.count + 1)", systemImage: "plus")
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                        }
                        
                        // Start Game Button
                        VStack(spacing: 12) {
                            AppButton(role: .primary, controlSize: .extraLarge, isDisabled: !canStartGame) {
                                showGameView = true
                            } label: {
                                Text("Start Game")
                            }
                            .frame(maxWidth: .infinity)

                            if !canStartGame && selectedPlayers.count == 1 {
                                Text("Add at least one more player")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                        }
                        
                        // Game Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to Play")
                                .font(.headline)
                                .foregroundStyle(Color("TextPrimary"))
                            
                            Text(config.game.instructions)
                                .font(.body)
                                .foregroundStyle(Color("TextSecondary"))
                        }
                        .padding(16)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
            }
            .background(Color("BackgroundPrimary"))
            .edgesIgnoringSafeArea(.top)
            
            // Transparent Navigation Bar Overlay
            VStack {
                HStack {
                    // Back Button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showGameView) {
            // Always show black background to prevent white flash
            ZStack {
                Color.black.ignoresSafeArea()
                
                if !navigationManager.shouldDismissToGamesList {
                    let params = config.gameParameters(players: selectedPlayers, selection: selectedOption)
                    PreGameHypeView(
                        game: params.game,
                        players: params.players,
                        matchFormat: params.matchFormat,
                        halveItDifficulty: params.halveItDifficulty,
                        suddenDeathLives: params.suddenDeathLives
                    )
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
            SearchPlayerSheet(selectedPlayers: selectedPlayers, onPlayerSelected: { player in
                addPlayer(player)
            }, friendsCache: friendsCache)
        }
        .onAppear {
            selectedOption = config.defaultSelection
        }
    }
    
    // MARK: - Helper Methods
    
    private func addPlayer(_ player: Player) {
        if selectedPlayers.count < config.playerLimit && !selectedPlayers.contains(where: { $0.id == player.id }) {
            selectedPlayers.append(player)
        }
    }
    
    private func removePlayer(_ player: Player) {
        selectedPlayers.removeAll { $0.id == player.id }
    }
}
