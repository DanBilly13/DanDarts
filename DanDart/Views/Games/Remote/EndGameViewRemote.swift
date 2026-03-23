//
//  EndGameViewRemote.swift
//  Dart Freak
//
//  Remote match end screen showing winner and celebration
//  Dedicated view for remote matches to enable replay/rematch features
//  Design: Dark dramatic with winner spotlight (carbon copy of GameEndView)
//
//  Phase 16 Task 1: Foundation for replay/rematch
//  - Separates remote end-game from local end-game
//  - Maintains identical visual styling and behavior
//  - Prepared for replay overlay in future tasks
//

import SwiftUI

struct EndGameViewRemote: View {
    let game: Game
    let winner: Player
    let players: [Player]
    let onBackToGames: () -> Void
    let matchFormat: Int?
    let legsWon: [UUID: Int]?
    let matchId: UUID? // For navigating to match details
    let matchResult: MatchResult? // Optional pre-loaded match result for instant access
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var showCelebration = false
    @State private var showMatchDetails = false
    @State private var loadedMatch: MatchResult?
    @State private var isLoadingMatch = false
    
    // MARK: - Future Replay State (Phase 16 Task 4+)
    // @State private var showReplayOverlay = false
    // @State private var replayRequestState: ReplayRequestState = .none
    
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
                    AppColor.backgroundPrimary,
                    AppColor.justBlack,
                    AppColor.justBlack
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
                    Image(systemName: "crown")
                        .font(.system(size: 60, weight: .regular))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                        .shadow(color: AppColor.interactivePrimaryBackground.opacity(0.5), radius: 20, x: 0, y: 0)
                        .scaleEffect(showCelebration ? 1.0 : 0.5)
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: showCelebration)
                    
                    // Winner Avatar
                    PlayerAvatarView(
                        avatarURL: winner.avatarURL,
                        size: 120,
                        borderColor: AppColor.interactivePrimaryBackground
                    )
                    .shadow(color: AppColor.interactivePrimaryBackground.opacity(0.4), radius: 30, x: 0, y: 10)
                    .scaleEffect(showCelebration ? 1.0 : 0.8)
                    .opacity(showCelebration ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.3), value: showCelebration)
                    
                    // Winner Name
                    VStack(spacing: 8) {
                        Text("WINNER!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .tracking(2)
                        
                        Text(winner.displayName)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("@\(winner.nickname)")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    .scaleEffect(showCelebration ? 1.0 : 0.8)
                    .opacity(showCelebration ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.4), value: showCelebration)
                    
                    // Match result (if multi-leg)
                    if let resultText = matchResultText {
                        Text("Wins \(resultText)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                            .opacity(showCelebration ? 1.0 : 0.0)
                            .animation(.easeIn(duration: 0.3).delay(0.5), value: showCelebration)
                    }
                    
                    // Match Details Link
                    if matchId != nil {
                        Button {
                            loadMatchAndShowDetails()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingMatch {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(isLoadingMatch ? "Loading..." : "View Match Details")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColor.textPrimary)
                                    .underline()
                            }
                        }
                        .disabled(isLoadingMatch)
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.3).delay(0.7), value: showCelebration)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    // PHASE 16 TASK 4+: Replace with replay overlay trigger
                    // This button will initiate replay request using PlayerChallengeCard
                    AppButton(role: .primary, controlSize: .extraLarge, compact: true) {
                        // TODO: Phase 16 Task 4 - Trigger replay overlay
                        print("🎮 [EndGameViewRemote] Play Again tapped - replay not yet implemented")
                    } label: {
                        Label("Play Again", systemImage: "arrow.clockwise")
                    }
                    
                    // Back to Games Button
                    AppButton(role: .primaryOutline, controlSize: .extraLarge, compact: true) {
                        onBackToGames()
                    } label: {
                        Label("Back to Games", systemImage: "house.fill")
                    }
                }
                .padding(.horizontal, 64)
                .padding(.bottom, 40)
                .opacity(showCelebration ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.3).delay(0.8), value: showCelebration)
            }
            
            // PHASE 16 TASK 4+: Replay overlay will go here
            // ZStack overlay with PlayerChallengeCard (sent/pending states)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $showMatchDetails) {
            // Navigate to match details as a main screen
            if let matchResult = loadedMatch {
                MatchDetailView(match: matchResult, isSheet: false)
                    .background(AppColor.backgroundPrimary)
            } else {
                // Fallback if match not found
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                    
                    Text("Match details not available")
                        .font(.headline)
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("Unable to load match data")
                        .font(.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.backgroundPrimary)
            }
        }
        .onAppear {
            // Trigger celebration animation
            withAnimation {
                showCelebration = true
            }
            
            // Refresh current user profile to show updated stats
            Task {
                do {
                    try await authService.refreshCurrentUser()
                    print("✅ [EndGameViewRemote] User profile refreshed after remote match")
                } catch {
                    print("⚠️ [EndGameViewRemote] Failed to refresh user profile: \(error)")
                }
            }
            
            // Note: Game win sound plays from RemoteGameViewModel and carries over to this screen
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load match from local storage or cloud and show details sheet
    private func loadMatchAndShowDetails() {
        print("🔍 [EndGameViewRemote] loadMatchAndShowDetails called")
        print("   - matchId: \(matchId?.uuidString.prefix(8) ?? "nil")...")
        print("   - matchResult passed in: \(matchResult != nil)")

        // If matchResult is already provided, use it AND seed the cache
        if let matchResult = matchResult {
            print("✅ [EndGameViewRemote] Using pre-loaded matchResult")
            
            // Seed the cache so future revisits are instant
            MatchHistoryService.shared.seedDetailCache(match: matchResult)
            
            loadedMatch = matchResult
            showMatchDetails = true
            return
        }

        guard let matchId = matchId else {
            print("❌ [EndGameViewRemote] No matchId provided")
            return
        }

        isLoadingMatch = true

        Task {
            print("🔍 [EndGameViewRemote] Loading match \(matchId.uuidString.prefix(8))...")

            do {
                // Use MatchHistoryService's cached loader (may already be cached from above)
                let match = try await MatchHistoryService.shared.loadFullDetail(matchId: matchId)
                await MainActor.run {
                    loadedMatch = match
                    isLoadingMatch = false
                    showMatchDetails = true
                }
            } catch {
                print("❌ [EndGameViewRemote] Failed to load match: \(error)")
                await MainActor.run {
                    isLoadingMatch = false
                    showMatchDetails = true
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Remote Game End - 301") {
    EndGameViewRemote(
        game: Game.preview301,
        winner: Player.mockGuest1,
        players: [Player.mockGuest1, Player.mockGuest2],
        onBackToGames: { print("Back to Games") },
        matchFormat: nil,
        legsWon: nil,
        matchId: UUID(),
        matchResult: nil
    )
    .environmentObject(AuthService.mockAuthenticated)
}

#Preview("Remote Game End - Multi-Leg Match") {
    let player1 = Player.mockGuest1
    let player2 = Player.mockGuest2
    
    EndGameViewRemote(
        game: Game.preview301,
        winner: player1,
        players: [player1, player2],
        onBackToGames: { print("Back to Games") },
        matchFormat: 3,
        legsWon: [player1.id: 2, player2.id: 1],
        matchId: UUID(),
        matchResult: nil
    )
    .environmentObject(AuthService.mockAuthenticated)
}
#endif
