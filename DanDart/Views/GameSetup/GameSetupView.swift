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
    
    @State private var showSearchPlayer: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @StateObject private var friendsCache = FriendsCache()
    @EnvironmentObject private var authService: AuthService
    @StateObject private var setupState = GameSetupState()
    
    // Game-specific config
    private var config: any GameSetupConfigurable {
        switch game.title {
        case "Halve-It":
            return HalveItSetupConfig(game: game)
        case "Knockout":
            return KnockoutSetupConfig(game: game)
        case "Sudden Death":
            return SuddenDeathSetupConfig(game: game)
        case "Killer":
            return KillerSetupConfig(game: game)
        default: // 301, 501, or any other countdown game
            return CountdownSetupConfig(game: game)
        }
    }
    
    private var selectedPlayers: [Player] {
        setupState.selectedPlayers
    }
    
    private var canStartGame: Bool {
        selectedPlayers.count >= 2
    }
    
    var body: some View {
        // Layout constants
        let heroHeight: CGFloat = 280
        let topBarHeight: CGFloat = 58  // Includes safe area + bar content
        let contentSpacing: CGFloat = 32  // Visual spacing between hero and content
        
        // Scroll animation values
        let collapseDistance: CGFloat = 220
        let collapseProgress = min(max(scrollOffset / collapseDistance, 0), 1)
        
        // Top bar fades in later (starts at 70% scroll, fully visible at 100%)
        let topBarProgress = min(max((collapseProgress - 0.7) / 0.3, 0), 1)
        
        // Image scale: grows subtly as you scroll down (1.0 at top, 1.08 at bottom)
        let imageScale = 1.0 + (collapseProgress * 0.08)
        
        // Hero title fades out faster (fully gone at 60% scroll)
        let heroTitleOpacity = max(1.0 - (collapseProgress / 0.6), 0)
        
        ZStack(alignment: .top) {
            // Hero header behind, flush with top, fades as content scrolls
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    // Cover Image - use canonical coverImageName with gradient fallback
                    Group {
                        if UIImage(named: config.game.coverImageName) != nil {
                            Image(config.game.coverImageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: heroHeight)
                                .scaleEffect(imageScale)
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
                            .frame(height: heroHeight)
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
                    .frame(height: heroHeight)
                    
                    // Game Title
                    Text(config.game.title)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.leading, 20)
                        .padding(.bottom, 24)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
                        .opacity(heroTitleOpacity)
                }
                .frame(height: heroHeight)
                .frame(maxWidth: .infinity)
                .overlay(
                    Color.black.opacity(collapseProgress)
                )

                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // Main content with scroll tracking that can move over the header area
            TrackingScrollView(offset: $scrollOffset) {
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
                            config.optionView(
                                selection: $setupState.selectedOption
                            )
                        }
                    }
                    
                    // Player Selection Section (only shown when players are selected)
                    if !selectedPlayers.isEmpty {
                        VStack(spacing: 16) {
                            HStack(spacing: 8) {
                                Text("Players")
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColor.textPrimary)

                                Text("\(selectedPlayers.count) of \(config.playerLimit)")
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: 12) {
                                ForEach(selectedPlayers.indices, id: \.self) { index in
                                    let player = selectedPlayers[index]
                                    PlayerCard(player: player, playerNumber: index + 1)
                                        .customSwipeAction(
                                            title: "Remove",
                                            systemImage: "xmark.circle",
                                            role: .destructive
                                        ) {
                                            removePlayer(player)
                                        }
                                }
                            }
                        }
                    }
                    
                    // Game Instructions
                    GameInstructionsContent(game: config.game)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, heroHeight - topBarHeight + contentSpacing)
                .padding(.bottom, 16)
            }
            .background(Color.clear)
            .environmentObject(setupState)
            
            // Sticky top bar that matches gameplay style and collapses the title
            VStack {
                HStack {
                    // Close Button
                    Button(action: {
                        router.pop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.black.opacity(0.3 * (1 - collapseProgress)))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    // Compact game title that fades in as hero collapses
                    Text(config.game.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .opacity(topBarProgress)
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.trailing, 16 + 28)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(
                    AppColor.backgroundPrimary
                        .opacity(topBarProgress)
                        .ignoresSafeArea(edges: .top)
                )
                
                Spacer()
            }
            
            // Bottom action bar (Add players / Start game)
            VStack {
                Spacer()
                BottomActionContainer {
                    if selectedPlayers.isEmpty {
                        AppButton(role: .primary, controlSize: .extraLarge) {
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
                                let params = config.gameParameters(players: selectedPlayers, selection: setupState.selectedOption)
                                router.push(.preGameHype(
                                    game: params.game,
                                    players: params.players,
                                    matchFormat: params.matchFormat,
                                    halveItDifficulty: params.halveItDifficulty,
                                    knockoutLives: params.knockoutLives,
                                    killerLives: params.killerLives
                                ))
                            } label: {
                                Text("Start game")
                            }
                        }
                    }
                }
            }
        }
        .background(AppColor.backgroundPrimary.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSearchPlayer) {
            SearchPlayerSheet(
                selectedPlayers: $setupState.selectedPlayers,
                friendsCache: friendsCache
            )
        }
        .onAppear {
            if setupState.selectedOption == 0 {
                setupState.selectedOption = config.defaultSelection
            }
        }
    }

    // MARK: - Helper Methods

    private func addPlayer(_ player: Player) {
        if setupState.selectedPlayers.count < config.playerLimit &&
            !setupState.selectedPlayers.contains(where: { $0.id == player.id }) {
            setupState.selectedPlayers.append(player)
        }
    }

    private func removePlayer(_ player: Player) {
        setupState.selectedPlayers.removeAll { $0.id == player.id }
    }
}

