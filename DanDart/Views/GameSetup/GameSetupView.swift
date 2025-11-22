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
    @State private var scrollOffset: CGFloat = 0
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
        // scrollOffset is vertical contentOffset.y from TrackingScrollView
        let collapseDistance: CGFloat = 220
        let collapseProgress = min(max(scrollOffset / collapseDistance, 0), 1)
        let heroHeight: CGFloat = 280
        
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
                            config.optionView(selection: $selectedOption)
                        }
                    }
                    
                    // Player Selection Section
                    VStack(spacing: 16) {
                        if !selectedPlayers.isEmpty {
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
                /*.background(Color.gray)*/

                .padding(.horizontal, 16)
                /*.padding(.top, heroHeight + 24)*/
                .padding(.top, heroHeight - 58 + 32)
                .padding(.bottom, 16)
            }
            .background(Color.clear)
            
            // Sticky top bar that matches gameplay style and collapses the title
            VStack {
                HStack {
                    // Close Button
                    Button(action: {
                        router.pop()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))   // adjust size for a 28px circle
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)                 // ← FIXED SIZE CIRCLE
                            .background(Color.black.opacity(0.3 * (1 - collapseProgress)))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    // Compact game title that fades in as hero collapses
                    Text(config.game.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .opacity(collapseProgress)
                    
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.trailing, 16 + 28)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(
                    AppColor.backgroundPrimary
                        .opacity(collapseProgress)
                        .ignoresSafeArea(edges: .top)
                )
                
                Spacer()
            }
            
            // TEMP: Debug overlay to verify scrollOffset and collapseProgress
            VStack {
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "offset: %.1f", scrollOffset))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "collapse: %.2f", collapseProgress))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 40)
                    .padding(.trailing, 12)
                }
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
