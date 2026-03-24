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
    @EnvironmentObject private var remoteMatchService: RemoteMatchService
    @EnvironmentObject private var router: Router
    @State private var showCelebration = false
    @State private var showMatchDetails = false
    @State private var loadedMatch: MatchResult?
    @State private var isLoadingMatch = false
    
    // MARK: - Phase 16 Task 4: Replay Overlay State
    @State private var showReplayOverlay = false
    @State private var replayMatchId: UUID?
    @State private var replayMatch: RemoteMatch?
    @State private var isCreatingReplay = false
    @State private var replayError: String?
    
    // MARK: - Computed Properties
    
    /// Get the opponent player (the player who is not the current user)
    private var opponent: Player? {
        guard let currentUserId = authService.currentUser?.id else { return nil }
        return players.first { $0.id != currentUserId }
    }
    
    /// Determine the card presentation state based on replay match status
    private var replayCardState: CardPresentationState? {
        guard let match = replayMatch else { return nil }
        guard let currentUserId = authService.currentUser?.id else { return nil }
        
        let iAmChallenger = match.challengerId == currentUserId
        
        switch match.status {
        case .pending:
            return iAmChallenger ? .sent : .pending
        case .ready:
            return .ready
        case .lobby:
            return .lobby
        case .cancelled:
            return .cancelled
        case .expired:
            return .expired
        default:
            return nil
        }
    }
    
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
                    // PHASE 16 TASK 4: Replay overlay trigger
                    AppButton(role: .primary, controlSize: .extraLarge, compact: true) {
                        createReplayRequest()
                    } label: {
                        if isCreatingReplay {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Creating...")
                            }
                        } else {
                            Label("Play Again", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isCreatingReplay)
                    
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
            
            // PHASE 16 TASK 4: Replay overlay with PlayerChallengeCard
            if showReplayOverlay, let opponent = opponent, let matchId = replayMatchId, let cardState = replayCardState {
                ZStack {
                    // Semi-transparent backdrop
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Dismiss overlay on backdrop tap (only if not in active state)
                            if cardState == .cancelled || cardState == .expired {
                                dismissReplayOverlay()
                            }
                        }
                    
                    // Challenge card overlay
                    VStack {
                        Spacer()
                        
                        PlayerChallengeCard(
                            matchId: matchId,
                            player: opponent,
                            state: cardState,
                            gameType: game.title,
                            matchFormat: matchFormat ?? 1,
                            isProcessing: isCreatingReplay,
                            expiresAt: replayMatch?.joinWindowExpiresAt,
                            onAccept: {
                                acceptReplayRequest()
                            },
                            onDecline: {
                                declineReplayRequest()
                            },
                            onJoin: {
                                navigateToLobby()
                            }
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .transition(.opacity)
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
                    print("✅ [EndGameViewRemote] User profile refreshed after remote match")
                } catch {
                    print("⚠️ [EndGameViewRemote] Failed to refresh user profile: \(error)")
                }
            }
            
            // Note: Game win sound plays from RemoteGameViewModel and carries over to this screen
            
            // Scan for incoming replay requests (Player B detection)
            scanForIncomingReplayRequest()
            
            // Subscribe to replay match updates
            Task {
                await subscribeToReplayMatch()
            }
        }
        .onChange(of: replayMatch?.status) { oldStatus, newStatus in
            handleReplayStatusChange(from: oldStatus, to: newStatus)
        }
        .onChange(of: remoteMatchService.pendingChallenges) { oldValue, newValue in
            print("🔔 [EndGameViewRemote] pendingChallenges changed: \(oldValue.count) -> \(newValue.count)")
            if !newValue.isEmpty {
                print("🔔 [EndGameViewRemote] New pending challenges:")
                for challenge in newValue {
                    let isReplay = challenge.match.isReplay ?? false
                    let sourceId = challenge.match.replaySourceMatchId?.uuidString.prefix(8) ?? "nil"
                    print("  - match=\(challenge.match.id.uuidString.prefix(8)) isReplay=\(isReplay) source=\(sourceId) challenger=\(challenge.challenger.displayName)")
                }
            }
            scanForIncomingReplayRequest()
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
    
    // MARK: - Replay Request Methods
    
    /// Create a replay request (rematch)
    private func createReplayRequest() {
        print("🎮 [EndGameViewRemote] Creating replay request...")
        
        guard let opponent = opponent else {
            print("❌ [EndGameViewRemote] No opponent found")
            return
        }
        
        guard let currentUserId = authService.currentUser?.id else {
            print("❌ [EndGameViewRemote] No current user ID")
            return
        }
        
        isCreatingReplay = true
        
        Task {
            do {
                let matchId = try await remoteMatchService.createChallenge(
                    receiverId: opponent.id,
                    gameType: game.title,
                    matchFormat: matchFormat ?? 1,
                    currentUserId: currentUserId,
                    isReplay: true,
                    replaySourceMatchId: self.matchId
                )
                
                print("✅ [EndGameViewRemote] Replay request created: \(matchId)")
                
                // Manually load matches to populate RemoteMatchService arrays
                // (normally skipped during remote flow)
                print("🔄 [EndGameViewRemote] Manually loading matches to populate service arrays...")
                try await remoteMatchService.loadMatches(userId: currentUserId)
                print("✅ [EndGameViewRemote] Matches loaded")
                
                await MainActor.run {
                    replayMatchId = matchId
                    isCreatingReplay = false
                    
                    // Show overlay with animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showReplayOverlay = true
                    }
                    
                    print("🔍 [EndGameViewRemote] Overlay state - showReplayOverlay: \(showReplayOverlay), replayMatchId: \(String(describing: replayMatchId)), opponent: \(opponent != nil), replayMatch: \(replayMatch != nil), replayCardState: \(String(describing: replayCardState))")
                    
                    // Success haptic
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                    
                    // Start subscription to populate replayMatch
                    Task {
                        await subscribeToReplayMatch()
                    }
                }
            } catch {
                print("❌ [EndGameViewRemote] Failed to create replay: \(error)")
                
                await MainActor.run {
                    isCreatingReplay = false
                    replayError = error.localizedDescription
                    
                    // Error haptic
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                }
            }
        }
    }
    
    /// Subscribe to replay match updates from RemoteMatchService
    private func subscribeToReplayMatch() async {
        guard let matchId = replayMatchId else {
            print("⚠️ [EndGameViewRemote] subscribeToReplayMatch called but replayMatchId is nil")
            return
        }
        
        print("🔄 [EndGameViewRemote] Starting replay match subscription for \(matchId)")
        
        // Poll for match updates (RemoteMatchService already handles realtime subscriptions)
        while showReplayOverlay {
            // Search across all RemoteMatchService arrays for the replay match
            await MainActor.run {
                let allMatches = remoteMatchService.pendingChallenges + 
                                remoteMatchService.sentChallenges + 
                                remoteMatchService.readyMatches
                
                if let matchWithPlayers = allMatches.first(where: { $0.match.id == matchId }) {
                    print("✅ [EndGameViewRemote] Found replay match in service arrays - status: \(matchWithPlayers.match.status?.rawValue ?? "nil")")
                    replayMatch = matchWithPlayers.match
                } else if let activeMatch = remoteMatchService.activeMatch, activeMatch.match.id == matchId {
                    print("✅ [EndGameViewRemote] Found replay match in activeMatch - status: \(activeMatch.match.status?.rawValue ?? "nil")")
                    replayMatch = activeMatch.match
                } else {
                    print("⚠️ [EndGameViewRemote] Replay match \(matchId) not found in RemoteMatchService yet")
                }
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s polling
        }
        
        print("🛑 [EndGameViewRemote] Stopped replay match subscription")
    }
    
    /// Accept the replay request (receiver only)
    /// Player B accepts and enters lobby immediately
    private func acceptReplayRequest() {
        print("🎮 [REPLAY NAV] acceptReplayRequest() called - receiver flow")
        print("✅ [EndGameViewRemote] Accepting replay request...")
        
        guard let matchId = replayMatchId else { return }
        
        isCreatingReplay = true
        
        Task {
            do {
                try await remoteMatchService.acceptChallenge(matchId: matchId)
                print("✅ [EndGameViewRemote] Replay accepted - waiting for ready state...")
                
                // Wait for match to move to readyMatches (realtime update)
                var attempts = 0
                let maxAttempts = 20 // 2 seconds max
                while attempts < maxAttempts {
                    if remoteMatchService.readyMatches.contains(where: { $0.match.id == matchId }) {
                        print("✅ [EndGameViewRemote] Match is ready - navigating to lobby")
                        break
                    }
                    try await Task.sleep(for: .milliseconds(100))
                    attempts += 1
                }
                
                if attempts >= maxAttempts {
                    print("⚠️ [EndGameViewRemote] Timeout waiting for ready state, navigating anyway")
                }
                
                await MainActor.run {
                    isCreatingReplay = false
                    
                    // Success haptic
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                    
                    // Player B enters lobby immediately after accepting
                    navigateToLobby()
                }
            } catch {
                print("❌ [EndGameViewRemote] Failed to accept replay: \(error)")
                
                await MainActor.run {
                    isCreatingReplay = false
                    replayError = error.localizedDescription
                    
                    // Error haptic
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                }
            }
        }
    }
    
    /// Decline the replay request (cancel it)
    private func declineReplayRequest() {
        print("❌ [EndGameViewRemote] Cancelling replay request...")
        
        guard let matchId = replayMatchId else { return }
        
        Task {
            do {
                try await remoteMatchService.cancelChallenge(matchId: matchId)
                print("✅ [EndGameViewRemote] Replay cancelled")
                
                await MainActor.run {
                    // Dismiss overlay after brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismissReplayOverlay()
                    }
                }
            } catch {
                print("❌ [EndGameViewRemote] Failed to cancel replay: \(error)")
            }
        }
    }
    
    /// Dismiss the replay overlay and release ownership
    private func dismissReplayOverlay() {
        // Release ownership of replay navigation
        if let matchId = replayMatchId {
            remoteMatchService.activeReplayMatchId = nil
            print("🔓 [EndGameViewRemote] Released replay ownership for match \(matchId.uuidString.prefix(8))")
        }

        withAnimation(.easeOut(duration: 0.3)) {
            showReplayOverlay = false
        }

        // Clear state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.replayMatchId = nil
            self.replayMatch = nil
        }
    }
    
    /// Navigate to lobby (used by both Player A and Player B)
    /// Player B calls this immediately after accepting
    /// Player A calls this when tapping "Join now" button
    /// Follows the same entry contract as normal accept/join flows:
    /// 1. Call enterLobby() to transition match to lobby status
    /// 2. Fetch fresh match from server
    /// 3. Revalidate status
    /// 4. Push to RemoteLobbyView
    private func navigateToLobby() {
        print("🎮 [REPLAY NAV] navigateToLobby() called from EndGameViewRemote")
        print("🚀 [EndGameViewRemote] Navigating to lobby...")
        
        guard let match = replayMatch else {
            print("❌ [EndGameViewRemote] No replay match to join")
            return
        }
        
        guard let currentUser = authService.currentUser else {
            print("❌ [EndGameViewRemote] No current user")
            return
        }
        
        // Set loading state
        isCreatingReplay = true
        
        Task {
            do {
                // Step 1: Call enterLobby to transition match from ready -> lobby
                print("🚪 [EndGameViewRemote] Calling enterLobby for replay match \(match.id.uuidString.prefix(8))")
                try await remoteMatchService.enterLobby(matchId: match.id)
                print("✅ [EndGameViewRemote] enterLobby completed")
                
                // Step 2: Fetch fresh match from server (authoritative source)
                print("🔄 [EndGameViewRemote] Fetching fresh match after enterLobby")
                guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: match.id) else {
                    throw RemoteMatchError.databaseError("Failed to fetch updated match")
                }
                let statusStr = updatedMatch.status?.rawValue ?? "nil"
                print("✅ [EndGameViewRemote] Fetched match - status: \(statusStr)")
                
                // Step 3: Revalidate - only continue for valid lobby states
                let status = updatedMatch.status
                print("🔍 [EndGameViewRemote] REVALIDATE status=\(statusStr)")
                
                guard status == .lobby || status == .inProgress else {
                    print("❌ [EndGameViewRemote] REVALIDATE FAILED - invalid status for lobby entry: \(statusStr)")
                    
                    await MainActor.run {
                        isCreatingReplay = false
                        
                        // Show user-friendly error
                        if status == .expired {
                            replayError = "This replay request has expired"
                        } else if status == .cancelled {
                            replayError = "This replay request was cancelled"
                        } else if status == .completed {
                            replayError = "This match has already been completed"
                        } else {
                            replayError = "This replay is no longer available"
                        }
                        
                        // Error haptic
                        #if canImport(UIKit)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                        #endif
                    }
                    return
                }
                
                print("✅ [EndGameViewRemote] REVALIDATE OK - continuing to navigation")
                
                // Step 4: Get opponent from local data (can use cached data for User object)
                let allMatches = remoteMatchService.pendingChallenges + 
                                remoteMatchService.sentChallenges + 
                                remoteMatchService.readyMatches
                
                var matchWithPlayers: RemoteMatchWithPlayers?
                if let found = allMatches.first(where: { $0.match.id == match.id }) {
                    matchWithPlayers = found
                } else if let activeMatch = remoteMatchService.activeMatch, activeMatch.match.id == match.id {
                    matchWithPlayers = activeMatch
                }
                
                guard let matchWithPlayers = matchWithPlayers else {
                    print("❌ [EndGameViewRemote] Match not found in RemoteMatchService")
                    await MainActor.run {
                        isCreatingReplay = false
                        replayError = "Unable to find match details"
                    }
                    return
                }
                
                let opponentUser = matchWithPlayers.opponent
                
                // Step 5: Navigate to RemoteLobbyView with fresh match (status = lobby)
                await MainActor.run {
                    isCreatingReplay = false
                    
                    // Dismiss overlay before navigation
                    dismissReplayOverlay()
                    
                    print("🎮 [REPLAY NAV] Pushing to remoteLobby with status=\(statusStr)")
                    
                    // Navigate to RemoteLobbyView with replay match
                    // Reuse existing lobby flow (countdown, voice-ready, etc.)
                    router.push(.remoteLobby(
                        match: updatedMatch,  // Use fresh match from fetchMatch (status = lobby)
                        opponent: opponentUser,
                        currentUser: currentUser,
                        cancelledMatchIds: .constant(Set()),
                        onCancel: {
                            // Handle lobby cancellation - pop back to end game view
                            self.router.pop()
                        },
                        onUnfreeze: {
                            // No-op for replay flow - no freeze state to handle
                        }
                    ))
                }
            } catch {
                print("❌ [EndGameViewRemote] Failed to enter lobby: \(error)")
                
                await MainActor.run {
                    isCreatingReplay = false
                    replayError = error.localizedDescription
                    
                    // Error haptic
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                }
            }
        }
    }
    
    /// Handle replay status changes
    private func handleReplayStatusChange(from oldStatus: RemoteMatchStatus?, to newStatus: RemoteMatchStatus?) {
        print("🔄 [EndGameViewRemote] Replay status changed: \(oldStatus?.rawValue ?? "nil") → \(newStatus?.rawValue ?? "nil")")
        guard let newStatus else { return }

        switch newStatus {
        case .cancelled, .expired:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismissReplayOverlay()
            }
        default:
            break
        }
    }
    
    /// Scan for incoming replay requests (Player B detection)
    private func scanForIncomingReplayRequest() {
        guard let opponent = opponent else {
            print("⚠️ [EndGameViewRemote] scanForIncomingReplayRequest: opponent is nil")
            return
        }
        guard let currentMatchId = matchId else {
            print("⚠️ [EndGameViewRemote] scanForIncomingReplayRequest: matchId is nil")
            return
        }
        
        print("🔍 [EndGameViewRemote] Scanning for replay requests...")
        print("🔍 [EndGameViewRemote]   - opponent: \(opponent.displayName) (\(opponent.id.uuidString.prefix(8)))")
        print("🔍 [EndGameViewRemote]   - currentMatchId: \(currentMatchId.uuidString.prefix(8))")
        print("🔍 [EndGameViewRemote]   - pendingChallenges count: \(remoteMatchService.pendingChallenges.count)")
        
        for challengeWithPlayers in remoteMatchService.pendingChallenges {
            let match = challengeWithPlayers.match
            
            print("🔍 [EndGameViewRemote] Checking challenge \(match.id.uuidString.prefix(8)):")
            print("🔍 [EndGameViewRemote]   - challengerId: \(match.challengerId.uuidString.prefix(8)) (expected: \(opponent.id.uuidString.prefix(8)))")
            print("🔍 [EndGameViewRemote]   - isReplay: \(match.isReplay ?? false)")
            print("🔍 [EndGameViewRemote]   - replaySourceMatchId: \(match.replaySourceMatchId?.uuidString.prefix(8) ?? "nil") (expected: \(currentMatchId.uuidString.prefix(8)))")
            
            guard match.challengerId == opponent.id else {
                print("⏭️ [EndGameViewRemote]   - Skip: challenger mismatch")
                continue
            }
            guard match.isReplay == true else {
                print("⏭️ [EndGameViewRemote]   - Skip: not a replay")
                continue
            }
            guard match.replaySourceMatchId == currentMatchId else {
                print("⏭️ [EndGameViewRemote]   - Skip: source match mismatch")
                continue
            }
            
            print("✅ [EndGameViewRemote] Found replay request from \(opponent.displayName)")
            handleIncomingReplayRequest(matchId: match.id, match: match)
            return
        }
        
        print("❌ [EndGameViewRemote] No matching replay request found")
    }
    
    /// Handle incoming replay request (Player B)
    private func handleIncomingReplayRequest(matchId: UUID, match: RemoteMatch) {
        // Idempotency check 1: Already showing overlay for this match?
        if replayMatchId == matchId && showReplayOverlay {
            print("⏭️ [EndGameViewRemote] Replay overlay already showing for this match")
            return
        }
        
        // Idempotency check 2: Already set to this match?
        if replayMatchId == matchId {
            print("⏭️ [EndGameViewRemote] Replay match ID already set")
            return
        }
        
        print("🎮 [EndGameViewRemote] Showing replay overlay for Player B")
        
        replayMatchId = matchId
        replayMatch = match
        
        // Claim ownership of replay navigation
        remoteMatchService.activeReplayMatchId = matchId
        print("🔒 [EndGameViewRemote] Claimed replay ownership for match \(matchId.uuidString.prefix(8))")
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showReplayOverlay = true
        }
        
        // Success haptic
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
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
