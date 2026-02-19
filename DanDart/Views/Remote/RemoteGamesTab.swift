//
//  RemoteGamesTab.swift
//  DanDart
//
//  Remote matches tab - displays challenges and active matches
//

import SwiftUI

struct RemoteGamesTab: View {
    @StateObject private var remoteMatchService = RemoteMatchService()
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    
    @State private var processingMatchId: UUID?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showGameSelection = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.backgroundPrimary
                    .ignoresSafeArea()
                
                if remoteMatchService.isLoading {
                    loadingView
                } else if hasAnyMatches {
                    matchListView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Remote Games")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadMatches()
            }
            .refreshable {
                await loadMatches()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {
                    showError = false
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .confirmationDialog("Choose a game", isPresented: $showGameSelection) {
                Button("301") {
                    router.push(.remoteGameSetup(game: Game.remote301, opponent: nil))
                }
                Button("501") {
                    router.push(.remoteGameSetup(game: Game.remote501, opponent: nil))
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(AppColor.interactivePrimaryBackground)
            Text("Loading matches...")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(AppColor.textSecondary)
        }
    }
    
    // MARK: - Match List View
    
    private var matchListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Match Ready section (priority)
                if !remoteMatchService.readyMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Match Ready", systemImage: "checkmark.circle.fill", color: .green)
                        
                        ForEach(remoteMatchService.readyMatches) { matchWithPlayers in
                            PlayerChallengeCard(
                                player: Player(
                                    displayName: matchWithPlayers.opponent.displayName,
                                    nickname: matchWithPlayers.opponent.nickname,
                                    avatarURL: matchWithPlayers.opponent.avatarURL,
                                    isGuest: false,
                                    totalWins: matchWithPlayers.opponent.totalWins,
                                    totalLosses: matchWithPlayers.opponent.totalLosses,
                                    userId: matchWithPlayers.opponent.id
                                ),
                                state: .ready,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) },
                                onJoin: { joinMatch(matchId: matchWithPlayers.match.id) }
                            )
                        }
                    }
                }
                
                // Active match (in progress)
                if let activeMatch = remoteMatchService.activeMatch {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
                        
                        PlayerChallengeCard(
                            player: Player(
                                displayName: activeMatch.opponent.displayName,
                                nickname: activeMatch.opponent.nickname,
                                avatarURL: activeMatch.opponent.avatarURL,
                                isGuest: false,
                                totalWins: activeMatch.opponent.totalWins,
                                totalLosses: activeMatch.opponent.totalLosses,
                                userId: activeMatch.opponent.id
                            ),
                            state: activeMatch.match.status ?? .inProgress
                        )
                    }
                }
                
                // Received challenges
                if !remoteMatchService.pendingChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("You've been challenged", systemImage: "envelope.fill", color: .orange)
                        
                        ForEach(remoteMatchService.pendingChallenges) { matchWithPlayers in
                            PlayerChallengeCard(
                                player: Player(
                                    displayName: matchWithPlayers.opponent.displayName,
                                    nickname: matchWithPlayers.opponent.nickname,
                                    avatarURL: matchWithPlayers.opponent.avatarURL,
                                    isGuest: false,
                                    totalWins: matchWithPlayers.opponent.totalWins,
                                    totalLosses: matchWithPlayers.opponent.totalLosses,
                                    userId: matchWithPlayers.opponent.id
                                ),
                                state: .pending,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                onAccept: { acceptChallenge(matchId: matchWithPlayers.match.id) },
                                onDecline: { declineChallenge(matchId: matchWithPlayers.match.id) }
                            )
                        }
                    }
                }
                
                // Sent challenges
                if !remoteMatchService.sentChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Sent challenges", systemImage: "paperplane.fill", color: .gray)
                        
                        ForEach(remoteMatchService.sentChallenges) { matchWithPlayers in
                            PlayerChallengeCard(
                                player: Player(
                                    displayName: matchWithPlayers.opponent.displayName,
                                    nickname: matchWithPlayers.opponent.nickname,
                                    avatarURL: matchWithPlayers.opponent.avatarURL,
                                    isGuest: false,
                                    totalWins: matchWithPlayers.opponent.totalWins,
                                    totalLosses: matchWithPlayers.opponent.totalLosses,
                                    userId: matchWithPlayers.opponent.id
                                ),
                                state: .pending,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "network")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.textSecondary)
            
            VStack(spacing: 8) {
                Text("No Remote Matches")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textPrimary)
                
                Text("Challenge a friend to start playing")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            AppButton(role: .primary, controlSize: .large) {
                showGameSelection = true
            } label: {
                Text("Challenge a Friend")
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(AppColor.textPrimary)
                .textCase(.uppercase)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Helpers
    
    private var hasAnyMatches: Bool {
        !remoteMatchService.readyMatches.isEmpty ||
        !remoteMatchService.pendingChallenges.isEmpty ||
        !remoteMatchService.sentChallenges.isEmpty ||
        remoteMatchService.activeMatch != nil
    }
    
    private func loadMatches() async {
        guard let userId = authService.currentUser?.id else {
            print("❌ No current user - cannot load remote matches")
            return
        }
        
        do {
            try await remoteMatchService.loadMatches(userId: userId)
            await remoteMatchService.setupRealtimeSubscription(userId: userId)
        } catch {
            print("❌ Failed to load remote matches: \(error)")
        }
    }
    
    // MARK: - Button Actions
    
    private func acceptChallenge(matchId: UUID) {
        processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.acceptChallenge(matchId: matchId)
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                }
            } catch {
                await MainActor.run {
                    processingMatchId = nil
                    errorMessage = "Failed to accept challenge: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    private func declineChallenge(matchId: UUID) {
        processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.cancelChallenge(matchId: matchId)
                
                // Light haptic
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                }
            } catch {
                await MainActor.run {
                    processingMatchId = nil
                    errorMessage = "Failed to decline challenge: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    private func cancelMatch(matchId: UUID) {
        processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.cancelChallenge(matchId: matchId)
                
                // Light haptic
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                }
            } catch {
                await MainActor.run {
                    processingMatchId = nil
                    errorMessage = "Failed to cancel match: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    private func joinMatch(matchId: UUID) {
        processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.joinMatch(matchId: matchId)
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                }
                
                // TODO: Navigate to gameplay
            } catch {
                await MainActor.run {
                    processingMatchId = nil
                    errorMessage = "Failed to join match: \(error.localizedDescription)"
                    showError = true
                }
                
                // Error haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RemoteGamesTab()
        .environmentObject(AuthService.shared)
}
