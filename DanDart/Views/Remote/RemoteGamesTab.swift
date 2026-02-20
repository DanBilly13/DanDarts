//
//  RemoteGamesTab.swift
//  DanDart
//
//  Remote matches tab - displays challenges and active matches
//

import SwiftUI

struct RemoteGamesTab: View {
    @StateObject private var remoteMatchService = RemoteMatchService()
    @StateObject private var router = Router.shared
    @EnvironmentObject var authService: AuthService
    
    @State private var processingMatchId: UUID?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showGameSelection = false
    @State private var currentTime = Date()
    @State private var expiredMatchIds: Set<UUID> = []
    @State private var fadingMatchIds: Set<UUID> = []
    
    var body: some View {
        NavigationStack(path: $router.path) {
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
            .navigationTitle("Remote matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitle(title: "Remote matches")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showGameSelection = true
                    } label: {
                        Text("Challenge")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .frame(minWidth: 44)
                }
            }
            .customNavBar(title: "Remote matches", subtitle: nil)
            .task {
                await loadMatches()
            }
            .refreshable {
                await loadMatches()
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
                currentTime = time
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
            .alert("Choose a game", isPresented: $showGameSelection) {
                Button("301") {
                    let opponent: User? = nil
                    router.push(.remoteGameSetup(game: Game.remote301, opponent: opponent))
                }
                Button("501") {
                    let opponent: User? = nil
                    router.push(.remoteGameSetup(game: Game.remote501, opponent: opponent))
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Select which game type you'd like to play")
            }
            .navigationDestination(for: Route.self) { route in
                router.view(for: route)
                    .background(AppColor.backgroundPrimary)
            }
        }
        .environmentObject(router)
        .background(AppColor.backgroundPrimary).ignoresSafeArea()
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
                // Match Ready section (highest priority)
                if !remoteMatchService.readyMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Match Ready", systemImage: "checkmark.circle.fill", color: .green)
                        
                        ForEach(remoteMatchService.readyMatches.filter { !expiredMatchIds.contains($0.id) }) { matchWithPlayers in
                            let _ = currentTime // Force re-evaluation when currentTime changes
                            let isExpired = matchWithPlayers.isExpired
                            let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                            
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
                                state: isExpired ? .expired : .ready,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                expiresAt: matchWithPlayers.match.joinWindowExpiresAt,
                                onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) },
                                onJoin: { joinMatch(matchId: matchWithPlayers.match.id) }
                            )
                            .opacity(isFading ? 0 : 1)
                            .animation(.easeOut(duration: 0.5), value: isFading)
                            .onChange(of: isExpired) { _, newValue in
                                if newValue {
                                    handleExpiration(matchId: matchWithPlayers.id)
                                }
                            }
                        }
                    }
                }
                
                // Received challenges (dimmed when match ready)
                if !remoteMatchService.pendingChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("You've been challenged", systemImage: "envelope.fill", color: .orange)
                        
                        ForEach(remoteMatchService.pendingChallenges.filter { !expiredMatchIds.contains($0.id) }) { matchWithPlayers in
                            let _ = currentTime // Force re-evaluation when currentTime changes
                            let isExpired = matchWithPlayers.isExpired
                            let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                            
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
                                state: isExpired ? .expired : .pending,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                expiresAt: matchWithPlayers.match.challengeExpiresAt,
                                onAccept: { acceptChallenge(matchId: matchWithPlayers.match.id) },
                                onDecline: { declineChallenge(matchId: matchWithPlayers.match.id) }
                            )
                            .opacity(isFading ? 0 : 1)
                            .animation(.easeOut(duration: 0.5), value: isFading)
                            .onChange(of: isExpired) { _, newValue in
                                if newValue {
                                    handleExpiration(matchId: matchWithPlayers.id)
                                }
                            }
                        }
                    }
                    .opacity(remoteMatchService.readyMatches.isEmpty ? 1.0 : 0.5)
                }
                
                // Sent challenges (dimmed when match ready)
                if !remoteMatchService.sentChallenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Sent challenges", systemImage: "paperplane.fill", color: .gray)
                        
                        ForEach(remoteMatchService.sentChallenges.filter { !expiredMatchIds.contains($0.id) }) { matchWithPlayers in
                            let _ = currentTime // Force re-evaluation when currentTime changes
                            let isExpired = matchWithPlayers.isExpired
                            let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                            let _ = print("🎯 RemoteGamesTab - Rendering sent challenge: opponent=\(matchWithPlayers.opponent.displayName), isExpired=\(isExpired), isFading=\(isFading), status=\(matchWithPlayers.match.status?.rawValue ?? "nil")")
                            
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
                                state: isExpired ? .expired : .sent,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                expiresAt: matchWithPlayers.match.joinWindowExpiresAt ?? matchWithPlayers.match.challengeExpiresAt,
                                onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) }
                            )
                            .opacity(isFading ? 0 : 1)
                            .animation(.easeOut(duration: 0.5), value: isFading)
                            .onChange(of: isExpired) { _, newValue in
                                if newValue {
                                    handleExpiration(matchId: matchWithPlayers.id)
                                }
                            }
                        }
                    }
                    .opacity(remoteMatchService.readyMatches.isEmpty ? 1.0 : 0.5)
                }
                
                // Active match (in progress, dimmed when match ready)
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
                            state: activeMatch.match.status ?? .inProgress,
                            expiresAt: nil
                        )
                    }
                    .opacity(remoteMatchService.readyMatches.isEmpty ? 1.0 : 0.5)
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
                .font(.system(size: 80))
                .foregroundStyle(AppColor.textSecondary.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("You have no\nremote matches")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            
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
        !remoteMatchService.pendingChallenges.isEmpty ||
        !remoteMatchService.sentChallenges.isEmpty ||
        !remoteMatchService.readyMatches.isEmpty ||
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
    
    private func handleExpiration(matchId: UUID) {
        // Prevent duplicate handling
        guard !fadingMatchIds.contains(matchId) && !expiredMatchIds.contains(matchId) else {
            return
        }
        
        print("⏰ Starting expiration timer for match: \(matchId)")
        
        // Wait 5 seconds after expiration
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🌫️ Starting fade animation for match: \(matchId)")
            // Start fade animation
            fadingMatchIds.insert(matchId)
            
            // Remove after fade completes (0.5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🗑️ Removing expired match from UI: \(matchId)")
                expiredMatchIds.insert(matchId)
                fadingMatchIds.remove(matchId)
                
                // Delete from database
                Task {
                    do {
                        try await remoteMatchService.deleteExpiredMatch(matchId: matchId)
                    } catch {
                        print("⚠️ Failed to delete expired match from database: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RemoteGamesTab()
        .environmentObject(AuthService.shared)
}
