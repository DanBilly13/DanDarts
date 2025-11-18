//
//  GameSetupView.swift
//  DanDart
//
//  Generic game setup view that works for all game types
//  Uses GameSetupConfigurable protocol for game-specific options
//

import SwiftUI
import UIKit

struct GameSetupView: View {
    let game: Game
    
    @State private var selectedPlayers: [Player] = []
    @State private var showSearchPlayer: Bool = false
    @State private var selectedOption: Int = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @StateObject private var friendsCache = FriendsCache()
    @EnvironmentObject private var authService: AuthService
    
    // Game-specific config
    private var config: any GameSetupConfigurable {
        switch game.title {
        case "Halve-It":
            return HalveItSetupConfig(game: game)
        case "Knockout":
            return KnockoutSetupConfig(game: game)
        case "Sudden Death":
            return SuddenDeathSetupConfig(game: game)
        default: // 301, 501, or any other countdown game
            return CountdownSetupConfig(game: game)
        }
    }
    
    private var canStartGame: Bool {
        selectedPlayers.count >= 2
    }
    
    var body: some View {
        ZStack {
            // Main content with ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header with Cover Image
                    ZStack(alignment: .bottomLeading) {
                        // Cover Image - use canonical coverImageName with gradient fallback
                        Group {
                            if UIImage(named: config.game.coverImageName) != nil {
                                Image(config.game.coverImageName)
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
                        }
                        
                        // Gradient overlay for text readability
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.3)
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
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.semibold)
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
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("TextPrimary"))
                                
                                Spacer()
                                
                                Text("\(selectedPlayers.count) of \(config.playerLimit)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("TextSecondary"))
                            }
                            
                            // Sequential Player Addition
                            VStack(spacing: 12) {
                                // Add next player button (if under limit)
                                if selectedPlayers.count < config.playerLimit {
                                    AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
                                        showSearchPlayer = true
                                    } label: {
                                        Label("Add Player \(selectedPlayers.count + 1)", systemImage: "plus")
                                            .font(.system(size: 16))
                                    }
                                }
                                
                                // Show selected players in a List for swipe actions
                                List {
                                    ForEach(selectedPlayers.indices, id: \.self) { index in
                                        let player = selectedPlayers[index]
                                        PlayerCard(player: player, playerNumber: index + 1)
                                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                            .listRowBackground(Color.clear)
                                            .listRowSeparator(.hidden)
                                            .customSwipeAction(
                                                title: "Remove",
                                                systemImage: "xmark.circle",
                                                role: .destructive
                                            ) {
                                                removePlayer(player)
                                            }
                                    }
                                }
                                .listStyle(.plain)
                                .scrollDisabled(true)
                                .frame(height: CGFloat(selectedPlayers.count * 92)) // 80pt card + 12pt spacing
                                .background(Color.clear)
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
            .background(Color.clear)
            .edgesIgnoringSafeArea(.top)
            
            // Transparent Navigation Bar Overlay (top)
            VStack {
                HStack {
                    // Close Button
                    Button(action: {
                        router.pop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
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
        .background(Color("BackgroundPrimary").ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if canStartGame {
                VStack(spacing: 12) {
                    AppButton(role: .primary, controlSize: .extraLarge) {
                        let params = config.gameParameters(players: selectedPlayers, selection: selectedOption)
                        router.push(.preGameHype(
                            game: params.game,
                            players: params.players,
                            matchFormat: params.matchFormat,
                            halveItDifficulty: params.halveItDifficulty,
                            knockoutLives: params.knockoutLives
                        ))
                    } label: {
                        Text("Start Game")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 64)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
        .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)
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
