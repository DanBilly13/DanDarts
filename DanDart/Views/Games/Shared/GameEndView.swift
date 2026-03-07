//
//  GameEndView.swift
//  Dart Freak
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
    let matchResult: MatchResult? // Optional pre-loaded match result for instant access
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var showCelebration = false
    @State private var showMatchDetails = false
    @State private var loadedMatch: MatchResult?
    @State private var isLoadingMatch = false
    @State private var hasPlayedWinSound = false
    
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
                    
                    // Celebration Message
                   /* Text("🎯 Perfect Finish! 🎯")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color("AccentPrimary"))
                        .opacity(showCelebration ? 1.0 : 0.0)
                        .animation(.easeIn(duration: 0.3).delay(0.6), value: showCelebration)*/
                    
                    // Match Details Link
                    if matchId != nil {
                        Button {
                            loadMatchAndShowDetails()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoadingMatch {
                                    ProgressView()
                                        .scaleEffect(0.8)
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
                    // Play Again Button (same players)
                    AppButton(role: .primary, controlSize: .extraLarge, compact: true) {
                        onPlayAgain()
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
                    print("✅ User profile refreshed after match")
                } catch {
                    print("⚠️ Failed to refresh user profile: \(error)")
                }
            }
            
            // Note: Game win sound now plays from the game logic itself
            // (e.g., Winner301 for 301/501 games) and carries over to this screen
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load match from local storage or cloud and show details sheet
    private func loadMatchAndShowDetails() {
        print("🔍 [GameEndView] loadMatchAndShowDetails called")
        print("   - matchId: \(matchId?.uuidString.prefix(8) ?? "nil")...")
        print("   - matchResult passed in: \(matchResult != nil)")

        // If matchResult is already provided, use it
        if let matchResult = matchResult {
            print("✅ [GameEndView] Using pre-loaded matchResult")
            loadedMatch = matchResult
            showMatchDetails = true
            return
        }

        guard let matchId = matchId else {
            print("❌ [GameEndView] No matchId provided")
            return
        }

        isLoadingMatch = true

        Task {
            print("🔍 [GameEndView] Loading match \(matchId.uuidString.prefix(8))...")

            // 1) Local storage
            let localMatches = MatchStorageManager.shared.loadMatches()
            if let localMatch = localMatches.first(where: { $0.id == matchId }) {
                print("✅ [GameEndView] Found match in local storage")
                await MainActor.run {
                    loadedMatch = localMatch
                    isLoadingMatch = false
                    showMatchDetails = true
                }
                return
            }

            // 2) Supabase direct query by id
            do {
                if authService.currentUser != nil {
                    print("☁️ [GameEndView] Querying Supabase directly by ID...")
                    let matchesService = MatchesService()

                    if let match = try await matchesService.loadMatchById(matchId) {
                        print("✅ [GameEndView] Found match in Supabase")
                        await MainActor.run {
                            loadedMatch = match
                            isLoadingMatch = false
                            showMatchDetails = true
                        }
                        return
                    } else {
                        print("⚠️ [GameEndView] Match not found in Supabase")
                    }
                }
            } catch {
                print("⚠️ [GameEndView] Failed to load match from Supabase: \(error)")
            }

            // 3) Fallback: MatchHistoryService
            await MainActor.run {
                let historyMatches = MatchHistoryService.shared.matches
                print("📊 [GameEndView] Checking MatchHistoryService (\(historyMatches.count) matches)")

                if let historyMatch = historyMatches.first(where: { $0.id == matchId }) {
                    print("✅ [GameEndView] Found match in MatchHistoryService")
                    loadedMatch = historyMatch
                } else {
                    print("❌ [GameEndView] Match not found anywhere: \(matchId)")
                }

                isLoadingMatch = false
                showMatchDetails = true
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
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
        matchId: UUID(),
        matchResult: nil
    )
    .environmentObject(AuthService.mockAuthenticated)
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
        matchId: UUID(),
        matchResult: nil
    )
    .environmentObject(AuthService.mockAuthenticated)
}
#endif
