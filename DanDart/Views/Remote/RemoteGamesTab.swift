//
//  RemoteGamesTab.swift
//  DanDart
//
//  Remote matches tab - displays challenges and active matches
//

import SwiftUI

struct RemoteGamesTab: View {
    @EnvironmentObject var remoteMatchService: RemoteMatchService
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
                // Load matches when tab appears
                // Note: Realtime subscription is now set up in MainTabView on app launch
                await loadMatches()
                
                // Clean up cancelled IDs for matches that no longer exist
                let allMatchIds = Set(
                    remoteMatchService.pendingChallenges.map { $0.match.id } +
                    remoteMatchService.sentChallenges.map { $0.match.id } +
                    remoteMatchService.readyMatches.map { $0.match.id } +
                    (remoteMatchService.activeMatch.map { [$0.match.id] } ?? [])
                )
                remoteMatchService.cancelledMatchIds = remoteMatchService.cancelledMatchIds.intersection(allMatchIds)
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
                // Ready matches
                if !remoteMatchService.readyMatches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("Ready to join", systemImage: "checkmark.circle.fill", color: .green)
                        
                        ForEach(remoteMatchService.readyMatches.filter { 
                            !expiredMatchIds.contains($0.id) && 
                            $0.id != remoteMatchService.activeMatch?.id 
                        }) { matchWithPlayers in
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
                                gameType: matchWithPlayers.match.gameType,
                                matchFormat: matchWithPlayers.match.matchFormat,
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
                        
                        ForEach(remoteMatchService.pendingChallenges.filter { 
                            !expiredMatchIds.contains($0.id) && 
                            $0.id != remoteMatchService.activeMatch?.id 
                        }) { matchWithPlayers in
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
                                gameType: matchWithPlayers.match.gameType,
                                matchFormat: matchWithPlayers.match.matchFormat,
                                isProcessing: processingMatchId == matchWithPlayers.match.id,
                                expiresAt: matchWithPlayers.match.challengeExpiresAt,
                                onAccept: {
                                    print("🔴 [DEBUG] onAccept closure called from RemoteGamesTab for matchId: \(matchWithPlayers.match.id)")
                                    acceptChallenge(matchId: matchWithPlayers.match.id)
                                },
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
                        sectionHeader("Challenges sent", systemImage: "paperplane.fill", color: .blue)
                        
                        ForEach(remoteMatchService.sentChallenges.filter { 
                            !expiredMatchIds.contains($0.id) && 
                            $0.id != remoteMatchService.activeMatch?.id 
                        }) { matchWithPlayers in
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
                                gameType: matchWithPlayers.match.gameType,
                                matchFormat: matchWithPlayers.match.matchFormat,
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
                if let activeMatch = remoteMatchService.activeMatch,
                   processingMatchId == nil,
                   !remoteMatchService.cancelledMatchIds.contains(activeMatch.match.id) {
                    let _ = print("🎯 [RENDER] Active Match section rendering - matchId: \(activeMatch.id), processingMatchId: \(String(describing: processingMatchId))")
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
                            gameType: activeMatch.match.gameType,
                            matchFormat: activeMatch.match.matchFormat,
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
        } catch {
            print("❌ Failed to load remote matches: \(error)")
        }
    }
    
    // MARK: - Button Actions
    
    private func acceptChallenge(matchId: UUID) {
        print("🔵 [DEBUG] acceptChallenge called with matchId: \(matchId)")
        print("🔵 [DEBUG] processingMatchId: \(String(describing: processingMatchId))")
        
        // Prevent double-accept
        guard processingMatchId == nil else {
            print("❌ [DEBUG] Blocked by processingMatchId guard")
            return
        }
        
        // CRITICAL: Capture opponent data NOW before state changes
        guard let matchWithPlayers = remoteMatchService.pendingChallenges.first(where: { $0.match.id == matchId }) else {
            print("❌ [DEBUG] Cannot find match in pendingChallenges")
            return
        }
        let opponent = matchWithPlayers.opponent
        print("✅ [DEBUG] Opponent captured: \(opponent.displayName)")
        
        print("✅ [DEBUG] Guard passed, setting processingMatchId to \(matchId)")
        processingMatchId = matchId
        
        Task {
            do {
                guard let currentUser = authService.currentUser else {
                    throw RemoteMatchError.notAuthenticated
                }
                
                // Step 1: Accept challenge (pending → ready)
                try await remoteMatchService.acceptChallenge(matchId: matchId)
                
                // Step 2: Auto-join match (ready → lobby)
                // Guard: Skip auto-join if match was cancelled
                let isCancelled = await MainActor.run { remoteMatchService.cancelledMatchIds.contains(matchId) }
                guard !isCancelled else {
                    print("🚫 [DEBUG] Skipping auto-join - match was cancelled")
                    await MainActor.run {
                        processingMatchId = nil
                    }
                    return
                }
                try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
                
                // Step 2.5: Fetch updated match with joinWindowExpiresAt
                print("🔍 [DEBUG] Fetching updated match data...")
                guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    throw RemoteMatchError.databaseError("Failed to fetch updated match")
                }
                print("✅ [DEBUG] Updated match fetched")
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                // Step 3: Navigate to lobby with fresh match data (receiver flow)
                await MainActor.run {
                    print("🔵 [TIMING] MainActor.run START - processingMatchId: \(String(describing: processingMatchId))")
                    
                    // Guard: Don't navigate if match was cancelled
                    guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
                        print("🚫 [DEBUG] Skipping navigation - match was cancelled")
                        processingMatchId = nil
                        return
                    }
                    
                    print("🔵 [TIMING] About to call router.push - processingMatchId: \(String(describing: processingMatchId))")
                    print("✅ [DEBUG] Navigating to lobby with ID-based routing (receiver)")
                    
                    router.push(.remoteLobby(matchId: matchId))
                    
                    print("🔵 [TIMING] router.push called - processingMatchId: \(String(describing: processingMatchId))")
                    
                    // Clear processingMatchId AFTER navigation is initiated
                    processingMatchId = nil
                    print("🔵 [TIMING] processingMatchId set to nil")
                    print("🔵 [TIMING] MainActor.run END")
                }
                
                // Reload matches in background to update UI state after navigation
                // This ensures the card state is consistent when realtime updates arrive
                Task {
                    guard let userId = authService.currentUser?.id else { return }
                    try? await remoteMatchService.loadMatches(userId: userId)
                    print("✅ [DEBUG] Background reload complete after receiver navigation")
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
        print("🟠 [DEBUG] declineChallenge called with matchId: \(matchId)")
        
        // Guard 1: Not already processing
        guard processingMatchId == nil else {
            print("🟠 [DEBUG] Already processing another match")
            return
        }
        
        // Guard 2: Match exists in pending challenges
        guard remoteMatchService.pendingChallenges
            .contains(where: { $0.match.id == matchId }) else {
            print("🟠 [DEBUG] Match not found in pendingChallenges")
            return
        }
        
        print("🟠 [DEBUG] Guards passed, setting processingMatchId")
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
        print("🟠 [RemoteTab] cancelMatch called with matchId: \(matchId)")
        
        // Guard 1: Not already processing
        guard processingMatchId == nil else {
            print("🟠 [RemoteTab] Already processing another match")
            return
        }
        
        // Guard 2: Match exists in ready matches - CAPTURE DATA EARLY
        guard let matchWithPlayers = remoteMatchService.readyMatches
            .first(where: { $0.match.id == matchId }) else {
            print("🟠 [RemoteTab] Match not found in readyMatches")
            return
        }
        
        // CRITICAL: Capture status BEFORE any state changes
        let matchStatus = matchWithPlayers.match.status
        print("🟠 [RemoteTab] Match status: \(matchStatus?.rawValue ?? "nil")")
        
        // Log user context
        print("🔍 [CancelMatch] ========================================")
        print("🔍 [CancelMatch] User cancelling: \(authService.currentUser?.id.uuidString ?? "unknown")")
        print("🔍 [CancelMatch] Match ID: \(matchId)")
        print("🔍 [CancelMatch] Challenger ID: \(matchWithPlayers.match.challengerId)")
        print("🔍 [CancelMatch] Receiver ID: \(matchWithPlayers.match.receiverId)")
        print("🔍 [CancelMatch] ========================================")
        
        print("🟠 [RemoteTab] Guards passed, setting cancellation guard")
        
        // IMMEDIATELY mark as cancelled (before async call)
        remoteMatchService.cancelledMatchIds.insert(matchId)
        processingMatchId = matchId
        
        Task {
            do {
                // Route to correct endpoint based on status
                if matchStatus == .lobby || matchStatus == .inProgress {
                    print("🟠 [RemoteTab] Calling abortMatch")
                    try await remoteMatchService.abortMatch(matchId: matchId)
                } else {
                    print("🟠 [RemoteTab] Calling cancelChallenge")
                    try await remoteMatchService.cancelChallenge(matchId: matchId)
                }
                
                print("✅ [RemoteTab] Cancel/abort successful")
                
                // Light haptic
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                }
            } catch {
                print("❌ [RemoteTab] Failed to cancel/abort: \(error)")
                
                await MainActor.run {
                    // On error, remove from cancelled set to allow retry
                    remoteMatchService.cancelledMatchIds.remove(matchId)
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
        // Guard: Don't join if match was cancelled
        guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
            print("🚫 [DEBUG] Ignoring join - match was cancelled")
            return
        }
        
        processingMatchId = matchId
        
        Task {
            do {
                guard let currentUser = authService.currentUser else {
                    throw RemoteMatchError.notAuthenticated
                }
                
                try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    processingMatchId = nil
                    
                    // Guard: Don't navigate if match was cancelled
                    guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
                        print("🚫 [DEBUG] Skipping navigation - match was cancelled")
                        return
                    }
                    
                    router.push(.remoteLobby(matchId: matchId))
                }
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
        
        // Fire-and-forget: Call API to update status to expired
        // Don't await - let it happen in background
        Task {
            do {
                try await remoteMatchService.expireMatch(matchId: matchId)
                print("✅ Match expired via client: \(matchId)")
            } catch {
                print("⚠️ Failed to expire match (server will handle): \(error)")
            }
        }
        
        // Wait 5 seconds after expiration
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            print("🌫️ Starting fade animation for match: \(matchId)")
            // Start fade animation
            fadingMatchIds.insert(matchId)
            
            // Remove after fade completes (0.5s)
            // Note: No manual reload needed - realtime subscription will handle updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🗑️ Removing expired match from UI: \(matchId)")
                expiredMatchIds.insert(matchId)
                fadingMatchIds.remove(matchId)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RemoteGamesTab()
        .environmentObject(AuthService.shared)
}
