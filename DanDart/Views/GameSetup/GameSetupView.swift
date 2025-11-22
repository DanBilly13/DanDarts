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
                                        AppColor.interactivePrimaryBackground.opacity(0.6),
                                        AppColor.interactivePrimaryBackground.opacity(0.3)
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
                    VStack(spacing: 32) {
                        // Game-specific Options Section (if applicable)
                        if config.showOptions {
                            VStack(spacing: 16) {
                                HStack {
                                    Text(config.optionLabel)
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColor.textPrimary)
                                    
                                    Spacer()
                                }
                                
                                // Game-specific segmented control
                                config.optionView(selection: $selectedOption)
                            }
                        }
                        
                        // Player Selection Section
                        VStack(spacing: 16) {
                            if !selectedPlayers.isEmpty {
                                HStack(spacing:8) {
                                    Text("Players")
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(AppColor.textPrimary)

                                    /*Spacer()*/

                                    Text("\(selectedPlayers.count) of \(config.playerLimit)")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColor.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VStack(spacing: 12) {
                                // Selected players list
                                if !selectedPlayers.isEmpty {
                                    List {
                                        ForEach(selectedPlayers.indices, id: \.self) { index in
                                            let player = selectedPlayers[index]
                                            PlayerCard(player: player, playerNumber: index + 1)
                                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
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
                                    .frame(height: CGFloat(selectedPlayers.count * 96)) // 80pt card + 6pt spacing
                                    .background(Color.clear)
                                }
                            }
                            
                        }
                        
                        
                        // Game Instructions
                        GameInstructionsContent(game: config.game)
                            
                        
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
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            BottomActionContainer {
                if selectedPlayers.count < 2 {
                    // Only Add players button
                    AppButton(role: .secondary, controlSize: .extraLarge) {
                        showSearchPlayer = true
                    } label: {
                        Label("Add players", systemImage: "plus")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Add players + Start game side by side
                    HStack(spacing: 12) {
                        AppButton(role: .secondary, controlSize: .extraLarge) {
                            showSearchPlayer = true
                        } label: {
                            Label("Add players", systemImage: "plus")
                        }

                        AppButton(role: .primary, controlSize: .extraLarge, isDisabled: !canStartGame) {
                            let params = config.gameParameters(players: selectedPlayers, selection: selectedOption)
                            router.push(.preGameHype(
                                game: params.game,
                                players: params.players,
                                matchFormat: params.matchFormat,
                                halveItDifficulty: params.halveItDifficulty,
                                knockoutLives: params.knockoutLives
                            ))
                        } label: {
                            Text("Start game")
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showSearchPlayer) {
                SearchPlayerSheet(selectedPlayers: $selectedPlayers, friendsCache: friendsCache)
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
