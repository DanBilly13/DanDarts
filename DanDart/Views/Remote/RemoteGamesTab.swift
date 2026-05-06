//
//  RemoteGamesTab.swift
//  DanDart
//
//  Remote matches tab - displays challenges and active matches
//

import SwiftUI

struct RemoteGamesTab: View {
    @EnvironmentObject var remoteMatchService: RemoteMatchService
    @EnvironmentObject private var router: Router
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var expiredChallengeService = ExpiredChallengeService.shared
    
    @Binding var showGameSelection: Bool
    
    // Stage 1: Track if this tab is currently visible
    @State private var isTabVisible = false
    
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var expiredMatchIds: Set<UUID> = []
    @State private var fadingMatchIds: Set<UUID> = []
    @State private var cancelledMatchIds: Set<UUID> = []

    // Only show the full-screen loading view on the very first load.
    // For subsequent background refreshes, keep the list mounted to avoid row DISAPPEAR/APPEAR flashes.
    @State private var hasLoadedOnce = false
    @State private var hasRequestedVoicePermission = false
    
    
    // Frozen list snapshot - prevents reading live @Published during enter flow
    @State private var listFrozen = false
    @State private var frozenPending: [RemoteMatchWithPlayers] = []
    @State private var frozenReady: [RemoteMatchWithPlayers] = []
    @State private var frozenSent: [RemoteMatchWithPlayers] = []

    // Task 5: push-tap deep link consumption
    @State private var highlightedMatchId: UUID? = nil
    @State private var isConsumingNotificationIntent: Bool = false
    
    // Phase 10: Declined challenge presentation
    @State private var previousSentChallenges: [RemoteMatchWithPlayers] = []
    @State private var previousPendingChallenges: [RemoteMatchWithPlayers] = []
    @State private var declinedMatchesCache: [UUID: RemoteMatchWithPlayers] = [:]
    @State private var showDeclinedForMatchIds: Set<UUID> = []
    @State private var declineHandledMatchIds: Set<UUID> = []
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()

            // IMPORTANT: never swap the entire list subtree in/out when `isLoading` toggles.
            // That teardown is what produces the visible “flash” (rows DISAPPEAR/APPEAR).
            Group {
                if hasAnyMatches {
                    matchListView
                } else {
                    emptyStateView
                }
            }
            .overlay {
                if remoteMatchService.isLoading {
                    // Non-destructive loading indicator (including the first load).
                    ProgressView()
                        .tint(AppColor.interactivePrimaryBackground)
                        .padding(12)
                        .background(AppColor.backgroundPrimary.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .task {
            // Permission requests now happen during sign-up via PermissionsOnboardingView.
            // We still retry token sync here in case a previous sync failed (no UI prompt).
            await notificationService.retryTokenSyncIfNeeded()
            await requestVoicePermissionIfNeeded()
            
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
            cancelledMatchIds = cancelledMatchIds.intersection(allMatchIds)
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
        .background(AppColor.backgroundPrimary)
    .onAppear {
        isTabVisible = true
    }
    .onDisappear {
        isTabVisible = false
    }
    }
    
    
    // MARK: - Match List View
    
    // CRITICAL: Render from frozen snapshot while entering flow to prevent reading live @Published

    @ViewBuilder
    private var readyMatchesSection: some View {
        if !readyForUIStable.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Ready to join", systemImage: "checkmark.circle.fill", color: .green)
                
                ForEach(readyForUIStable) { matchWithPlayers in
                    let isExpired = matchWithPlayers.isExpired
                    let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                    if !expiredMatchIds.contains(matchWithPlayers.id) &&
                       matchWithPlayers.id != remoteMatchService.activeMatch?.id {
                        PlayerChallengeCard(
                            matchId: matchWithPlayers.match.id,
                            player: player(from: matchWithPlayers),
                            state: cardPresentationState(
                                for: matchWithPlayers,
                                isExpired: isExpired,
                                showAsDeclined: false
                            ),
                            gameType: matchWithPlayers.match.gameType,
                            matchFormat: matchWithPlayers.match.matchFormat,
                            isProcessing: remoteMatchService.processingMatchId == matchWithPlayers.match.id,
                            expiresAt: matchWithPlayers.match.joinWindowExpiresAt,
                            onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) },
                            onJoin: { joinMatch(matchId: matchWithPlayers.match.id) }
                        )
                        .id(matchWithPlayers.match.id)
                        .remoteCardHighlight(isHighlighted: highlightedMatchId == matchWithPlayers.match.id)
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
        }
    }
    
    @ViewBuilder
    private var receivedChallengesSection: some View {
        if !pendingForUIStable.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("You've been challenged", systemImage: "envelope.fill", color: .orange)
                
                ForEach(pendingForUIStable) { matchWithPlayers in
                    // CRITICAL GUARD: This section is ONLY for received challenges
                    let _ = {
                        if let currentUserId = authService.currentUser?.id,
                           matchWithPlayers.match.challengerId == currentUserId {
                            print("❌ [UI-GUARD] Challenger match rendered in receiver section! matchId=\(matchWithPlayers.match.id.uuidString.prefix(8))")
                        }
                    }()
                    let isExpired = matchWithPlayers.isExpired
                    let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                    if !expiredMatchIds.contains(matchWithPlayers.id) &&
                       matchWithPlayers.id != remoteMatchService.activeMatch?.id {
                        PlayerChallengeCard(
                            matchId: matchWithPlayers.match.id,
                            player: player(from: matchWithPlayers),
                            state: cardPresentationState(
                                for: matchWithPlayers,
                                isExpired: isExpired,
                                showAsDeclined: false
                            ),
                            gameType: matchWithPlayers.match.gameType,
                            matchFormat: matchWithPlayers.match.matchFormat,
                            isProcessing: remoteMatchService.processingMatchId == matchWithPlayers.match.id,
                            expiresAt: matchWithPlayers.match.challengeExpiresAt,
                            onAccept: {
                                acceptChallenge(matchId: matchWithPlayers.match.id)
                            },
                            onDecline: { declineChallenge(matchId: matchWithPlayers.match.id) }
                        )
                        .id(matchWithPlayers.match.id)
                        .remoteCardHighlight(isHighlighted: highlightedMatchId == matchWithPlayers.match.id)
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
            .opacity(readyForUIStable.isEmpty ? 1.0 : 0.5)
        }
    }
    
    @ViewBuilder
    private var sentChallengesSection: some View {
        if !sentForUIWithDeclined.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Challenges sent", systemImage: "paperplane.fill", color: .blue)
                
                ForEach(sentForUIWithDeclined) { matchWithPlayers in
                    // CRITICAL GUARD: This section is ONLY for sent challenges
                    let _ = {
                        if let currentUserId = authService.currentUser?.id,
                           matchWithPlayers.match.receiverId == currentUserId {
                            print("❌ [UI-GUARD] Receiver match rendered in challenger section! matchId=\(matchWithPlayers.match.id.uuidString.prefix(8))")
                        }
                    }()
                    let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                    let showAsDeclined = showDeclinedForMatchIds.contains(matchWithPlayers.match.id)
                    
                    if !expiredMatchIds.contains(matchWithPlayers.id) &&
                       matchWithPlayers.id != remoteMatchService.activeMatch?.id {
                        
                        // Client-side expiry monitoring for sent challenges
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            let isExpiredNow = checkClientSideExpiry(for: matchWithPlayers, at: context.date)
                            let presentationState = cardPresentationState(
                                for: matchWithPlayers,
                                isExpired: isExpiredNow,
                                showAsDeclined: showAsDeclined
                            )
                            
                            PlayerChallengeCard(
                                matchId: matchWithPlayers.match.id,
                                player: player(from: matchWithPlayers),
                                state: presentationState,
                                gameType: matchWithPlayers.match.gameType,
                                matchFormat: matchWithPlayers.match.matchFormat,
                                isProcessing: remoteMatchService.processingMatchId == matchWithPlayers.match.id,
                                expiresAt: matchWithPlayers.match.joinWindowExpiresAt ?? matchWithPlayers.match.challengeExpiresAt,
                                onCancel: { cancelSentChallenge(matchId: matchWithPlayers.match.id) }
                            )
                            .id(matchWithPlayers.match.id)
                            .remoteCardHighlight(isHighlighted: highlightedMatchId == matchWithPlayers.match.id)
                            .opacity(isFading ? 0 : 1)
                            .animation(.easeOut(duration: 0.5), value: isFading)
                            .onChange(of: isExpiredNow) { _, newValue in
                                if newValue {
                                    handleExpiration(matchId: matchWithPlayers.id)
                                }
                            }
                        }
                    }
                }
            }
            .opacity(readyForUIStable.isEmpty ? 1.0 : 0.5)
        }
    }
    
    @ViewBuilder
    private var activeMatchSection: some View {
        if let activeMatch = remoteMatchService.activeMatch,
           remoteMatchService.processingMatchId == nil,
           !cancelledMatchIds.contains(activeMatch.match.id) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
                
                PlayerChallengeCard(
                    matchId: activeMatch.match.id,
                    player: player(from: activeMatch),
                    state: cardPresentationState(
                        for: activeMatch,
                        isExpired: false,
                        showAsDeclined: false
                    ),
                    gameType: activeMatch.match.gameType,
                    matchFormat: activeMatch.match.matchFormat,
                    expiresAt: nil
                )
                .id(activeMatch.match.id)
                .remoteCardHighlight(isHighlighted: highlightedMatchId == activeMatch.match.id)
            }
            .opacity(readyForUIStable.isEmpty ? 1.0 : 0.5)
        }
    }
    private var pendingForUI: [RemoteMatchWithPlayers] {
        listFrozen ? frozenPending : remoteMatchService.pendingChallenges
    }
    
    private var readyForUI: [RemoteMatchWithPlayers] {
        listFrozen ? frozenReady : remoteMatchService.readyMatches
    }
    
    private var sentForUI: [RemoteMatchWithPlayers] {
        listFrozen ? frozenSent : remoteMatchService.sentChallenges
    }
    
    // STABLE arrays: Hide matches during join/navigation flow
    // EXCLUSIVE: A match appears in only ONE section based on role
    private var readyForUIStable: [RemoteMatchWithPlayers] {
        readyForUI.filter { shouldShowInList(matchId: $0.match.id) }
    }
    
    private var pendingForUIStable: [RemoteMatchWithPlayers] {
        let filtered = pendingForUI.filter { shouldShowInList(matchId: $0.match.id) }
        
        // CRITICAL GUARD: Verify all matches are receiver-owned
        if let currentUserId = authService.currentUser?.id {
            for match in filtered {
                if match.match.receiverId != currentUserId {
                    print("❌ [SectionGuard] VIOLATION: Challenger match in receiver section! matchId=\(match.match.id.uuidString.prefix(8)) challengerId=\(match.match.challengerId.uuidString.prefix(8)) receiverId=\(match.match.receiverId.uuidString.prefix(8)) currentUserId=\(currentUserId.uuidString.prefix(8))")
                }
            }
        }
        
        return filtered
    }
    
    private var sentForUIStable: [RemoteMatchWithPlayers] {
        let filtered = sentForUI.filter { shouldShowInList(matchId: $0.match.id) }
        
        // CRITICAL GUARD: Verify all matches are challenger-owned
        if let currentUserId = authService.currentUser?.id {
            for match in filtered {
                if match.match.challengerId != currentUserId {
                    print("❌ [SectionGuard] VIOLATION: Receiver match in challenger section! matchId=\(match.match.id.uuidString.prefix(8)) challengerId=\(match.match.challengerId.uuidString.prefix(8)) receiverId=\(match.match.receiverId.uuidString.prefix(8)) currentUserId=\(currentUserId.uuidString.prefix(8))")
                }
            }
        }
        
        return filtered
    }
    
    /// Determine if a match should be shown in any list
    /// Only hide when the match is actively in remote flow (destination has taken over)
    /// Keep visible during pre-navigation work (processing, nav-in-flight, entering flow)
    private func shouldShowInList(matchId: UUID) -> Bool {
        // Only suppress once destination has taken over
        if remoteMatchService.isInRemoteFlow && remoteMatchService.flowMatchId == matchId {
            return false
        }
        
        // Keep visible during pre-navigation states:
        // - navInFlightMatchId: navigation starting
        // - pendingEnterFlowMatchIds: enter flow latch
        // - isEnteringFlow: async work before destination
        // - processingMatchId: processing/loading
        // These states show the card as locked/processing but keep it visible
        
        return true
    }
    
    // Helper to create Player from match data
    private func player(from matchWithPlayers: RemoteMatchWithPlayers) -> Player {
        Player(
            displayName: matchWithPlayers.opponent.displayName,
            nickname: matchWithPlayers.opponent.nickname,
            avatarURL: matchWithPlayers.opponent.avatarURL,
            isGuest: false,
            totalWins: matchWithPlayers.opponent.totalWins,
            totalLosses: matchWithPlayers.opponent.totalLosses,
            userId: matchWithPlayers.opponent.id
        )
    }
    
    // Freeze/unfreeze methods
    @MainActor
    private func freezeListSnapshot(reason: String, matchId: UUID?) {
        guard !listFrozen else { 
            FlowDebug.log("FREEZE: SKIP reason=alreadyFrozen", matchId: matchId)
            return 
        }
        // Capture ONCE from the service
        frozenPending = remoteMatchService.pendingChallenges
        frozenReady = remoteMatchService.readyMatches
        frozenSent = remoteMatchService.sentChallenges
        listFrozen = true
        
        let pendingIds = frozenPending.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        let readyIds = frozenReady.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        let sentIds = frozenSent.map { String($0.match.id.uuidString.prefix(8)) }.joined(separator: ",")
        FlowDebug.log("FREEZE: CAPTURE reason=\(reason) pending=[\(pendingIds)] ready=[\(readyIds)] sent=[\(sentIds)]", matchId: matchId)
    }
    
    @MainActor
    private func unfreezeListSnapshot(reason: String = "unknown", matchId: UUID? = nil) {
        guard listFrozen else {
            FlowDebug.log("FREEZE: SKIP CLEAR reason=notFrozen", matchId: matchId)
            return
        }
        listFrozen = false
        frozenPending = []
        frozenReady = []
        frozenSent = []
        FlowDebug.log("FREEZE: CLEAR reason=\(reason)", matchId: matchId)
    }

    // Delay unfreeze to avoid list/section churn during navigation push animations
    @MainActor
    private func unfreezeListSnapshotAfterTransition() {
        Task { @MainActor in
            // One or two frames is often enough, but use a small delay to cover push animations
            try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            unfreezeListSnapshot()
        }
    }
    
    private var matchListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 24) {
                    readyMatchesSection
                    receivedChallengesSection
                    sentChallengesSection
                    activeMatchSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .transaction { tx in
                // Disable animations during enter flow to prevent jarring section movements
                if remoteMatchService.processingMatchId != nil || !remoteMatchService.pendingEnterFlowMatchIds.isEmpty {
                    tx.animation = nil
                }
            }
            .onReceive(remoteMatchService.$sentChallenges) { newValue in
                detectDeclinedMatches(old: previousSentChallenges, new: newValue)
                previousSentChallenges = newValue
            }
            .onReceive(remoteMatchService.$pendingChallenges) { newValue in
                detectExpiredIncomingChallenges(old: previousPendingChallenges, new: newValue)
                previousPendingChallenges = newValue
            }
            .onReceive(remoteMatchService.$readyMatches) { newReadyMatches in
                // Clean up any cached declined matches that have become ready
                for readyMatch in newReadyMatches {
                    let matchId = readyMatch.match.id
                    if declinedMatchesCache[matchId] != nil {
                        declinedMatchesCache.removeValue(forKey: matchId)
                        showDeclinedForMatchIds.remove(matchId)
                        declineHandledMatchIds.remove(matchId)
                        fadingMatchIds.remove(matchId)
                        expiredMatchIds.remove(matchId)
                    }
                }
            }
            .onChange(of: remoteMatchService.activeMatch?.match.id) { _, newActiveMatchId in
                // Clean up any cached declined matches that have become active
                if let matchId = newActiveMatchId, declinedMatchesCache[matchId] != nil {
                    declinedMatchesCache.removeValue(forKey: matchId)
                    showDeclinedForMatchIds.remove(matchId)
                    declineHandledMatchIds.remove(matchId)
                    fadingMatchIds.remove(matchId)
                    expiredMatchIds.remove(matchId)
                }
            }
            .onChange(of: notificationService.pendingIntent?.matchId) { _, newValue in
                guard let matchId = newValue,
                      let intent = notificationService.pendingIntent,
                      intent.matchId == matchId else {
                    return
                }
                guard !isConsumingNotificationIntent else { return }

                isConsumingNotificationIntent = true
                Task { @MainActor in
                    await RemoteNotificationIntentConsumer.consume(
                        intent: intent,
                        loadMatches: {
                            await loadMatches()
                        },
                        listsSnapshot: {
                            RemoteNotificationIntentConsumer.ListsSnapshot(
                                ready: readyForUIStable,
                                pending: pendingForUIStable,
                                sent: sentForUIStable,
                                active: remoteMatchService.activeMatch
                            )
                        },
                        scrollTo: { targetId in
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        },
                        setHighlighted: { newValue in
                            highlightedMatchId = newValue
                        },
                        clearIntent: {
                            notificationService.clearIntent()
                            isConsumingNotificationIntent = false
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        EmptyState(
            imageName: "empty-remote",
            title: "No remote matches",
            message: "Challenge a friend to a remote 301 or 501",
            secondaryMessage: "Matches expire if not joined within 5 minutes",
            actionTitle: "Challenge a Friend",
            action: {
                showGameSelection = true
            }
        )
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
        remoteMatchService.activeMatch != nil ||
        !declinedMatchesCache.isEmpty
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
    
    // Note: Notification + microphone permissions are now requested during sign-up
    // via PermissionsOnboardingView. The Remote tab only retries token sync.
    private func requestVoicePermissionIfNeeded() async {
        let manager = VoicePermissionManager.shared
        manager.logState("remote tab voice permission check")
        
        guard !hasRequestedVoicePermission else {
            print("🎤 [RemoteGamesTab] Voice permission request skipped - already requested this session")
            return
        }
        
        guard manager.isVoiceEnabledInApp else {
            print("🎤 [RemoteGamesTab] Voice permission request skipped - app preference disabled")
            return
        }
        
        guard manager.microphoneAuthorizationStatus == .undetermined else {
            print("🎤 [RemoteGamesTab] Voice permission request skipped - permission already \(manager.microphoneAuthorizationStatus)")
            return
        }
        
        guard !manager.hasAttemptedInitialPrompt else {
            print("🎤 [RemoteGamesTab] Voice permission request skipped - initial prompt already attempted")
            return
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        print("🎤 [RemoteGamesTab] Requesting microphone permission for voice chat fallback")
        let granted = await manager.requestMicrophonePermissionIfNeeded()
        hasRequestedVoicePermission = true
        manager.logState("remote tab voice permission fallback completed granted=\(granted)")
        
        if granted {
            print("✅ [RemoteGamesTab] Microphone permission granted - voice chat available")
        } else {
            print("ℹ️ [RemoteGamesTab] Microphone permission not granted - remote matches continue without voice")
        }
    }
    
    // MARK: - Button Actions
    
    private func acceptChallenge(matchId: UUID) {
        // Guard: Skip if EndGameViewRemote owns this replay
        if let activeReplayId = remoteMatchService.activeReplayMatchId,
           activeReplayId == matchId {
            print("⏭️ [RemoteGamesTab] Suppressing accept - EndGameViewRemote owns replay \(matchId.uuidString.prefix(8))")
            return
        }
        
        print("🎮 [GENERIC NAV] acceptChallenge() called - generic flow for match \(matchId.uuidString.prefix(8))")
        
        let enteringFlow = remoteMatchService.isEnteringFlow
        let navInFlight = remoteMatchService.navInFlightMatchId != nil
        FlowDebug.log("ACCEPT: TAP enteringFlow=\(enteringFlow) navInFlight=\(navInFlight)", matchId: matchId)
        
        // Prevent double-accept
        guard remoteMatchService.processingMatchId == nil else {
            FlowDebug.log("ACCEPT: SKIP reason=alreadyProcessing", matchId: matchId)
            return
        }
        
        // CRITICAL: Capture opponent data NOW before state changes
        guard let matchWithPlayers = remoteMatchService.pendingChallenges.first(where: { $0.match.id == matchId }) else {
            FlowDebug.log("ACCEPT: ERROR match not found in pendingChallenges", matchId: matchId)
            return
        }
        let opponent = matchWithPlayers.opponent
        FlowDebug.log("ACCEPT: opponent captured name=\(opponent.displayName)", matchId: matchId)
        
        // BEGIN ACCEPT UI FREEZE - force pending state during receiver accept flow
        remoteMatchService.beginAcceptPresentationFreeze(matchId: matchId)
        
        // FREEZE LIST SNAPSHOT - capture BEFORE any state changes or network calls
        freezeListSnapshot(reason: "acceptTap", matchId: matchId)
        
        // BEGIN ENTER FLOW - sets processing, latch, and nav-in-flight all at once
        FlowDebug.log("ACCEPT: BEGIN ENTER FLOW", matchId: matchId)
        remoteMatchService.beginEnterFlow(matchId: matchId)
        
        Task {
            do {
                guard let currentUser = authService.currentUser else {
                    throw RemoteMatchError.notAuthenticated
                }
                
                FlowDebug.log("ACCEPT: acceptChallenge EDGE START", matchId: matchId)
                
                // Step 1: Accept challenge (pending → ready)
                try await remoteMatchService.acceptChallenge(matchId: matchId)
                
                FlowDebug.log("ACCEPT: acceptChallenge EDGE OK", matchId: matchId)
                
                // Step 1.5: Wait 1 second to avoid database lock contention
                FlowDebug.log("ACCEPT: DELAY 1s before enterLobby to avoid lock contention", matchId: matchId)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                FlowDebug.log("ACCEPT: DELAY complete", matchId: matchId)
                
                // Step 2: Enter lobby (receiver joins, ready → lobby)
                // Guard: Skip if match was cancelled
                let isCancelled = await MainActor.run { cancelledMatchIds.contains(matchId) }
                guard !isCancelled else {
                    print("🚫 [DEBUG] Skipping enter-lobby - match was cancelled")
                    await MainActor.run {
                        remoteMatchService.endEnterFlow(matchId: matchId)
                    }
                    return
                }
                // Step 2.1: TIMING INSTRUMENTATION - Start
                let enterLobbyStartTime = CFAbsoluteTimeGetCurrent()
                FlowDebug.log("ACCEPT: enterLobby TIMING_START timestamp=\(enterLobbyStartTime)", matchId: matchId)
                FlowDebug.log("ACCEPT: enterLobby EDGE START", matchId: matchId)
                // Refresh watchdog before potentially slow enterLobby call
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                // Step 2.2: Call enterLobby with timing
                let requestSentTime = CFAbsoluteTimeGetCurrent()
                let clientPrepDuration = requestSentTime - enterLobbyStartTime
                FlowDebug.log("ACCEPT: enterLobby REQUEST_SENT clientPrep=\(String(format: "%.3f", clientPrepDuration))s", matchId: matchId)
                
                try await remoteMatchService.enterLobby(matchId: matchId)
                
                // Step 2.3: TIMING INSTRUMENTATION - Complete
                let responseReceivedTime = CFAbsoluteTimeGetCurrent()
                let networkDuration = responseReceivedTime - requestSentTime
                let totalDuration = responseReceivedTime - enterLobbyStartTime
                FlowDebug.log("ACCEPT: enterLobby TIMING_COMPLETE network=\(String(format: "%.3f", networkDuration))s total=\(String(format: "%.3f", totalDuration))s", matchId: matchId)
                
                // Log warning if abnormally slow
                if totalDuration > 2.0 {
                    FlowDebug.log("ACCEPT: enterLobby SLOW_WARNING duration=\(String(format: "%.3f", totalDuration))s threshold=2.0s", matchId: matchId)
                }
                
                FlowDebug.log("ACCEPT: enterLobby EDGE OK", matchId: matchId)
                
                // Step 2.5: Fetch updated match with joinWindowExpiresAt
                FlowDebug.log("ACCEPT: fetchMatch START", matchId: matchId)
                
                guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    throw RemoteMatchError.databaseError("Failed to fetch updated match")
                }
                let statusStr = updatedMatch.status?.rawValue ?? "nil"
                let cpStr = updatedMatch.currentPlayerId?.uuidString.prefix(8) ?? "nil"
                FlowDebug.log("ACCEPT: fetchMatch OK status=\(statusStr) cp=\(cpStr)", matchId: matchId)
                
                // Step 2.6: AUTHORITATIVE REVALIDATION GATE
                // Validate match status before continuing to lobby navigation
                let status = updatedMatch.status
                FlowDebug.log("ACCEPT: REVALIDATE status=\(statusStr)", matchId: matchId)
                
                // Guard: Only continue for valid lobby states
                guard status == .lobby || status == .inProgress else {
                    let reason = "invalidStatus_\(statusStr)"
                    
                    await MainActor.run {
                        // Use centralized abort helper for consistent state cleanup
                        remoteMatchService.abortReceiverEntry(matchId: matchId, reason: reason)
                        
                        // View-level cleanup
                        unfreezeListSnapshotAfterTransition()
                        
                        // Show user-friendly error message
                        if status == .expired {
                            errorMessage = "This challenge has expired"
                        } else if status == .cancelled {
                            errorMessage = "This challenge was cancelled"
                        } else if status == .completed {
                            errorMessage = "This match has already been completed"
                        } else {
                            errorMessage = "This challenge is no longer available"
                        }
                        showError = true
                    }
                    
                    // Error haptic for invalid state
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    #endif
                    
                    return // STOP - do not continue to navigation
                }
                
                FlowDebug.log("ACCEPT: REVALIDATE OK - continuing to navigation", matchId: matchId)
                
                // Success haptic (only if validation passed)
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                // Step 3: Navigate to lobby with fresh match data (receiver flow)
                await MainActor.run {
                    // Guard: Don't navigate if match was cancelled
                    guard !cancelledMatchIds.contains(matchId) else {
                        print("🚫 [RECEIVER FLOW] Skipping navigation - match was cancelled")
                        remoteMatchService.endEnterFlow(matchId: matchId)
                        return
                    }
                    
                    let navInFlightId = remoteMatchService.navInFlightMatchId?.uuidString.prefix(8) ?? "none"
                    FlowDebug.log("ROUTER: REQUEST push remoteLobby navInFlight=\(navInFlightId)", matchId: matchId)
                    
                    // Capture token for guard
                    let token = remoteMatchService.navToken
                    let matchIdLocal = matchId
                    
                    // Guard: only push if we're still the active nav request
                    guard remoteMatchService.navInFlightMatchId == matchIdLocal else {
                        FlowDebug.log("ROUTER: SKIP push remoteLobby reason=navInFlightChanged", matchId: matchIdLocal)
                        return
                    }
                    guard token == remoteMatchService.navToken else {
                        FlowDebug.log("ROUTER: SKIP push remoteLobby reason=tokenChanged", matchId: matchIdLocal)
                        return
                    }
                    
                    // Guard: Skip if EndGameViewRemote owns this replay
                    if let activeReplayId = remoteMatchService.activeReplayMatchId,
                       activeReplayId == matchIdLocal {
                        print("⏭️ [RemoteGamesTab] Suppressing navigation - EndGameViewRemote owns replay")
                        remoteMatchService.endEnterFlow(matchId: matchIdLocal)
                        return
                    }
                    
                    print("🎮 [GENERIC NAV] Pushing to remoteLobby from RemoteGamesTab (accept flow)")
                    FlowDebug.log("ROUTER: PUSH remoteLobby", matchId: matchIdLocal)
                        
                    router.push(.remoteLobby(
                        match: updatedMatch,
                        opponent: opponent,
                        currentUser: currentUser,
                        cancelledMatchIds: $cancelledMatchIds,
                        onCancel: {
                            Task {
                                do {
                                    print("🟠 [RemoteTab] onCancel closure called (receiver flow)")
                                    
                                    // Fetch current match to determine status
                                    guard let currentMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                                        print("❌ [RemoteTab] Match not found, navigating back")
                                        await MainActor.run {
                                            router.popToRoot()
                                        }
                                        return
                                    }
                                    
                                    let matchStatus = currentMatch.status
                                    print("🟠 [RemoteTab] Current match status: \(matchStatus?.rawValue ?? "nil")")
                                    
                                    // Route to correct endpoint based on status
                                    if matchStatus == .lobby || matchStatus == .inProgress {
                                        print("🟠 [RemoteTab] Calling abortMatch")
                                        try await remoteMatchService.abortMatch(matchId: matchId)
                                    } else {
                                        print("🟠 [RemoteTab] Calling cancelChallenge")
                                        try await remoteMatchService.cancelChallenge(matchId: matchId)
                                    }
                                    
                                    print("✅ [RemoteTab] Cancel/abort successful")
                                    
                                    // Success haptic
                                    #if canImport(UIKit)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    #endif
                                    
                                    await MainActor.run {
                                        router.popToRoot()
                                    }
                                } catch {
                                    print("❌ [RemoteTab] Failed to cancel match: \(error)")
                                    
                                    // Error haptic
                                    #if canImport(UIKit)
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    #endif
                                    
                                    // Still navigate back even on error
                                    await MainActor.run {
                                        router.popToRoot()
                                    }
                                }
                            }
                        },
                        onUnfreeze: unfreezeListSnapshotAfterTransition
                    ))
                    
                    print("🟢 [RECEIVER FLOW] Pushed remoteLobby successfully")
                    
                    // DO NOT clear latch here - let it stay active until lobby appears
                    // Latch will be cleared by RemoteLobbyView.onAppear or failsafe timer
                    FlowDebug.log("PROCESSING KEEP (until Lobby onAppear)", matchId: matchId)
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
                    // Clear accept UI freeze on error
                    remoteMatchService.clearAcceptPresentationFreeze(matchId: matchId)
                    FlowDebug.log("ACCEPT_UI_FREEZE: CLEAR reason=acceptError", matchId: matchId)
                    
                    // Clear all enter-flow state on error
                    remoteMatchService.endEnterFlow(matchId: matchId)
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
        print("� [Decline] Decline button tapped - matchId: \(matchId.uuidString.prefix(8))...")
        
        // Guard 1: Not already processing
        guard remoteMatchService.processingMatchId == nil else {
            print("� [Decline] Already processing another match")
            return
        }
        
        // Guard 2: Match exists in pending challenges
        guard remoteMatchService.pendingChallenges
            .contains(where: { $0.match.id == matchId }) else {
            print("� [Decline] Match not found in pendingChallenges")
            return
        }
        
        print("� [Decline] Guards passed, setting processingMatchId")
        remoteMatchService.processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.cancelChallenge(matchId: matchId)
                print("✅ [Decline] Challenge declined successfully")
                
                // Light haptic
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                await MainActor.run {
                    remoteMatchService.processingMatchId = nil
                }
            } catch {
                print("❌ [Decline] Failed to decline: \(error)")
                await MainActor.run {
                    remoteMatchService.processingMatchId = nil
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
        guard remoteMatchService.processingMatchId == nil else {
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
        
        // Clear accept UI freeze on cancel
        remoteMatchService.clearAcceptPresentationFreeze(matchId: matchId)
        FlowDebug.log("ACCEPT_UI_FREEZE: CLEAR reason=cancel", matchId: matchId)
        
        // IMMEDIATELY mark as cancelled (before async call)
        cancelledMatchIds.insert(matchId)
        remoteMatchService.processingMatchId = matchId
        
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
                    remoteMatchService.processingMatchId = nil
                }
            } catch {
                print("❌ [RemoteTab] Failed to cancel/abort: \(error)")
                
                await MainActor.run {
                    // On error, remove from cancelled set to allow retry
                    cancelledMatchIds.remove(matchId)
                    remoteMatchService.processingMatchId = nil
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
    
    private func cancelSentChallenge(matchId: UUID) {
        print("🟠 [RemoteTab] cancelSentChallenge called with matchId: \(matchId)")
        
        // Guard: Not already processing
        guard remoteMatchService.processingMatchId == nil else {
            print("🟠 [RemoteTab] Already processing another match")
            return
        }
        
        // Guard: Match exists in sent challenges
        guard remoteMatchService.sentChallenges.contains(where: { $0.match.id == matchId }) else {
            print("🟠 [RemoteTab] Match not found in sentChallenges")
            return
        }
        
        // Set processing state immediately
        remoteMatchService.processingMatchId = matchId
        
        Task {
            do {
                try await remoteMatchService.cancelChallenge(matchId: matchId)
                print("✅ [RemoteTab] Cancel successful")
                
                // Light haptic
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                
                await MainActor.run {
                    remoteMatchService.processingMatchId = nil
                    // Card will fade/remove naturally via realtime update
                }
            } catch {
                print("❌ [RemoteTab] Failed to cancel: \(error)")
                
                await MainActor.run {
                    remoteMatchService.processingMatchId = nil
                    errorMessage = "Failed to cancel challenge: \(error.localizedDescription)"
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
        // Guard: Skip if EndGameViewRemote owns this replay
        if let activeReplayId = remoteMatchService.activeReplayMatchId,
           activeReplayId == matchId {
            print("⏭️ [RemoteGamesTab] Suppressing join - EndGameViewRemote owns replay \(matchId.uuidString.prefix(8))")
            return
        }
        
        print("🎮 [GENERIC NAV] joinMatch() called - generic flow for match \(matchId.uuidString.prefix(8))")
        
        let enteringFlow = remoteMatchService.isEnteringFlow
        let navInFlight = remoteMatchService.navInFlightMatchId != nil
        FlowDebug.log("JOIN: TAP enteringFlow=\(enteringFlow) navInFlight=\(navInFlight)", matchId: matchId)
        
        // Guard: Don't join if match was cancelled
        guard !cancelledMatchIds.contains(matchId) else {
            FlowDebug.log("JOIN: SKIP reason=matchCancelled", matchId: matchId)
            return
        }
        
        // CRITICAL: Capture opponent data NOW before state changes (similar to receiver flow)
        guard let matchWithPlayers = remoteMatchService.readyMatches.first(where: { $0.match.id == matchId }) else {
            FlowDebug.log("JOIN: ERROR match not found in readyMatches", matchId: matchId)
            return
        }
        let opponent = matchWithPlayers.opponent
        FlowDebug.log("JOIN: opponent captured name=\(opponent.displayName)", matchId: matchId)
        
        // FREEZE LIST SNAPSHOT - capture BEFORE any state changes or network calls
        freezeListSnapshot(reason: "joinTap", matchId: matchId)
        
        // BEGIN LATCH IMMEDIATELY - before realtime updates can arrive (challenger flow)
        FlowDebug.log("JOIN: BEGIN ENTER FLOW", matchId: matchId)
        remoteMatchService.beginEnterFlow(matchId: matchId)
        
        Task {
            do {
                guard let currentUser = authService.currentUser else {
                    throw RemoteMatchError.notAuthenticated
                }
                
                // Challenger enters lobby (sets challenger_lobby_joined_at, may start countdown)
                FlowDebug.log("JOIN: enterLobby EDGE START", matchId: matchId)
                try await remoteMatchService.enterLobby(matchId: matchId)
                FlowDebug.log("JOIN: enterLobby EDGE OK", matchId: matchId)
                
                // Fetch updated match to get latest lobby state
                FlowDebug.log("JOIN: fetchMatch START", matchId: matchId)
                guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    throw RemoteMatchError.databaseError("Failed to fetch updated match")
                }
                let statusStr = updatedMatch.status?.rawValue ?? "nil"
                let cpStr = updatedMatch.currentPlayerId?.uuidString.prefix(8) ?? "nil"
                FlowDebug.log("JOIN: fetchMatch OK status=\(statusStr) cp=\(cpStr)", matchId: matchId)
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                await MainActor.run {
                    // Guard: Don't navigate if match was cancelled
                    guard !cancelledMatchIds.contains(matchId) else {
                        FlowDebug.log("JOIN: SKIP navigation reason=matchCancelled", matchId: matchId)
                        remoteMatchService.endEnterFlow(matchId: matchId)
                        return
                    }
                    
                    let navInFlightId = remoteMatchService.navInFlightMatchId?.uuidString.prefix(8) ?? "none"
                    FlowDebug.log("ROUTER: REQUEST push remoteLobby navInFlight=\(navInFlightId)", matchId: matchId)
                    
                    // Guard: Skip if EndGameViewRemote owns this replay
                    if let activeReplayId = remoteMatchService.activeReplayMatchId,
                       activeReplayId == matchId {
                        print("⏭️ [RemoteGamesTab] Suppressing navigation - EndGameViewRemote owns replay")
                        remoteMatchService.endEnterFlow(matchId: matchId)
                        return
                    }
                    
                    print("🎮 [GENERIC NAV] Pushing to remoteLobby from RemoteGamesTab (join flow)")
                    FlowDebug.log("ROUTER: PUSH remoteLobby", matchId: matchId)
                    
                    router.push(.remoteLobby(
                        match: updatedMatch,
                        opponent: opponent,
                        currentUser: currentUser,
                        cancelledMatchIds: $cancelledMatchIds,
                        onCancel: {
                            Task {
                                do {
                                    FlowDebug.log("JOIN: onCancel called", matchId: matchId)
                                    
                                    // Fetch current match to determine status
                                    guard let currentMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                                        print("❌ [RemoteTab] Match not found, navigating back")
                                        await MainActor.run {
                                            router.popToRoot()
                                        }
                                        return
                                    }
                                    
                                    let matchStatus = currentMatch.status
                                    print("🟠 [RemoteTab] Current match status: \(matchStatus?.rawValue ?? "nil")")
                                    
                                    // Route to correct endpoint based on status
                                    if matchStatus == .lobby || matchStatus == .inProgress {
                                        print("🟠 [RemoteTab] Calling abortMatch")
                                        try await remoteMatchService.abortMatch(matchId: matchId)
                                    } else {
                                        print("🟠 [RemoteTab] Calling cancelChallenge")
                                        try await remoteMatchService.cancelChallenge(matchId: matchId)
                                    }
                                    
                                    print("✅ [RemoteTab] Cancel/abort successful")
                                    
                                    // Success haptic
                                    #if canImport(UIKit)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    #endif
                                    
                                    await MainActor.run {
                                        router.popToRoot()
                                    }
                                } catch {
                                    print("❌ [RemoteTab] Failed to cancel match: \(error)")
                                    
                                    // Error haptic
                                    #if canImport(UIKit)
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    #endif
                                    
                                    // Still navigate back even on error
                                    await MainActor.run {
                                        router.popToRoot()
                                    }
                                }
                            }
                        },
                        onUnfreeze: unfreezeListSnapshotAfterTransition
                    ))
                    
                    FlowDebug.log("JOIN: navigation complete", matchId: matchId)
                    
                    // DO NOT clear latch here - let it stay active until lobby appears
                    // Latch will be cleared by RemoteLobbyView.onAppear or failsafe timer
                }
            } catch {
                FlowDebug.log("JOIN: ERROR \(error.localizedDescription)", matchId: matchId)
                await MainActor.run {
                    // Clear all enter-flow state on error (challenger flow)
                    remoteMatchService.endEnterFlow(matchId: matchId)
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

        // === STAGE 1: Diagnostic logging only ===

        // Find the match to get context
        var foundMatch: RemoteMatchWithPlayers?
        var isIncomingChallenge = false
        var isReplayOrRematch = false

        // Check pending challenges (incoming) using frozen-aware stable snapshot
        if let match = self.pendingForUIStable.first(where: { $0.match.id == matchId }) {
            foundMatch = match
            isIncomingChallenge = true
            isReplayOrRematch = match.match.isReplay == true || match.match.replaySourceMatchId != nil
        }
        // Check ready matches (could be replay) using frozen-aware stable snapshot
        else if let match = self.readyForUIStable.first(where: { $0.match.id == matchId }) {
            foundMatch = match
            isIncomingChallenge = false
            isReplayOrRematch = match.match.isReplay == true || match.match.replaySourceMatchId != nil
        }

        // Determine if user is currently on Remote tab
        let isUserOnRemoteTab = isTabVisible

        // Log diagnostic information
        print("=== CHALLENGE EXPIRY DETECTED ===")
        print("matchId: \(matchId)")
        print("isReplayOrRematch: \(isReplayOrRematch)")
        print("isUserOnRemoteTab: \(isUserOnRemoteTab)")
        print("isIncomingChallenge: \(isIncomingChallenge)")

        if let match = foundMatch {
            print("challengeExpiresAt: \(match.match.challengeExpiresAt?.description ?? "nil")")
            print("joinWindowExpiresAt: \(match.match.joinWindowExpiresAt?.description ?? "nil")")
            print("status: \(match.match.status?.rawValue ?? "nil")")
            print("challengerId: \(match.match.challengerId)")
            print("receiverId: \(match.match.receiverId)")

            if let currentUser = authService.currentUser?.id {
                print("currentUserId: \(currentUser)")
                print("isReceiver: \(match.match.receiverId == currentUser)")
            } else {
                print("currentUserId: nil (not authenticated)")
            }
        } else {
            print("WARNING: Match not found in any array")
        }
        print("=== END EXPIRY DIAGNOSTICS ===")

        // === STAGE 2: Storage for expired unseen challenges ===
        // Only store when all preservation conditions are met
        if let match = foundMatch {
            expiredChallengeService.storeExpiredChallenge(
                matchWithPlayers: match,
                isReplayOrRematch: isReplayOrRematch,
                isUserOnRemoteTab: isUserOnRemoteTab,
                isIncomingChallenge: isIncomingChallenge
            )
        }

        print("Starting expiration timer for match: \(matchId)")

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
    
    // MARK: - Declined Challenge Presentation
    
    private func logDeclineDebugSnapshot(_ context: String) {
        let sentIds = sentForUIStable.map { String($0.match.id.uuidString.prefix(8)) }.sorted()
        let cachedIds = declinedMatchesCache.keys.map { String($0.uuidString.prefix(8)) }.sorted()
        let showingIds = showDeclinedForMatchIds.map { String($0.uuidString.prefix(8)) }.sorted()
        let handledIds = declineHandledMatchIds.map { String($0.uuidString.prefix(8)) }.sorted()
        let fadingIds = fadingMatchIds.map { String($0.uuidString.prefix(8)) }.sorted()
        let expiredIds = expiredMatchIds.map { String($0.uuidString.prefix(8)) }.sorted()
        let cancelledIds = cancelledMatchIds.map { String($0.uuidString.prefix(8)) }.sorted()

        print("🧪 [DeclineDebug] \(context)")
        print("   sentForUIStable=\(sentIds)")
        print("   declinedCache=\(cachedIds)")
        print("   showDeclined=\(showingIds)")
        print("   declineHandled=\(handledIds)")
        print("   fading=\(fadingIds)")
        print("   expired=\(expiredIds)")
        print("   cancelled=\(cancelledIds)")
    }
    
    /// Merged list of sent challenges including cached declined matches
    private var sentForUIWithDeclined: [RemoteMatchWithPlayers] {
        var merged = sentForUIStable  // From service (or frozen snapshot)
        
        // Add cached declined matches that aren't already in the list
        for (matchId, cachedMatch) in declinedMatchesCache {
            if !merged.contains(where: { $0.match.id == matchId }) {
                merged.append(cachedMatch)
            }
        }
        
        return merged
    }
    
    /// Map authoritative status to card presentation state
    /// Handles challenger-specific declined presentation
    private func cardPresentationState(
        for match: RemoteMatchWithPlayers,
        isExpired: Bool,
        showAsDeclined: Bool
    ) -> CardPresentationState {
        let matchId = match.match.id
        
        // ACCEPT UI FREEZE OVERRIDE: Force pending state during receiver accept flow
        if remoteMatchService.isAcceptPresentationFrozen(matchId: matchId) {
            let rawStatus = match.match.status?.rawValue ?? "nil"
            FlowDebug.log("ACCEPT_UI_FREEZE: USING pending override rawStatus=\(rawStatus)", matchId: matchId)
            return .pending
        }
        
        // Expired takes precedence (after freeze check)
        if isExpired {
            return .expired
        }
        
        // Declined presentation (local UI decision, not dependent on cached status)
        // The cached row was captured when status was .pending
        // The decision to show as declined has already been made by detectDeclinedMatches()
        if showAsDeclined {
            return .declined
        }
        
        // Map authoritative status to presentation
        switch match.match.status {
        case .pending:
            // Receiver sees pending, challenger sees sent
            return match.match.receiverId == authService.currentUser?.id
                ? .pending
                : .sent
        case .sent:
            return .sent  // Shouldn't come from DB, but handle it
        case .ready:
            return .ready
        case .lobby:
            // Keep showing .ready for users who haven't joined yet
            // This preserves the cancel button until they actually join
            return .ready
        case .inProgress:
            return .inProgress
        case .completed:
            return .completed
        case .expired:
            return .expired
        case .cancelled:
            return .cancelled  // Default (not showing as declined)
        case .none:
            // No status set - shouldn't happen, default to pending
            return .pending
        }
    }
    
    /// Detect expired incoming challenges when pending challenges list changes
    /// This handles server-side expiry for incoming challenges when user is ON Remote tab
    private func detectExpiredIncomingChallenges(
        old: [RemoteMatchWithPlayers],
        new: [RemoteMatchWithPlayers]
    ) {
        let oldIds = Set(old.map { $0.match.id })
        let newIds = Set(new.map { $0.match.id })
        let removedIds = oldIds.subtracting(newIds)
        
        print("ð [IncomingExpiryDetect] old=\(oldIds.map { String($0.uuidString.prefix(8)) }.sorted()) new=\(newIds.map { String($0.uuidString.prefix(8)) }.sorted()) removed=\(removedIds.map { String($0.uuidString.prefix(8)) }.sorted())")
        
        for removedId in removedIds {
            print("ð INCOMING REMOVAL DETECTED match=\(removedId.uuidString.prefix(8))")
            
            // Find the removed match in OLD snapshot
            guard let removedMatch = old.first(where: { $0.match.id == removedId }) else {
                continue
            }
            
            // GUARD: Previous status was .pending
            guard removedMatch.match.status == .pending else {
                print("â Skip - status was \(removedMatch.match.status?.rawValue ?? "nil"), not .pending")
                continue
            }
            
            // GUARD: Not expired locally
            guard !expiredMatchIds.contains(removedId) else {
                print("â Skip - match already expired")
                continue
            }
            
            // GUARD: Not already handled
            guard !declineHandledMatchIds.contains(removedId),
                  !showDeclinedForMatchIds.contains(removedId),
                  !fadingMatchIds.contains(removedId) else {
                print("â Skip - already handled")
                continue
            }
            
            // === EXPIRED CHALLENGE DIAGNOSTICS (Incoming server-side expiry) ===
            // This handles the case where user is ON Remote tab and server expires an incoming challenge
            print("=== CHALLENGE EXPIRY DETECTED (INCOMING SERVER-SIDE) ===")
            print("matchId: \(removedId)")
            print("isReplayOrRematch: \(removedMatch.match.isReplay == true || removedMatch.match.replaySourceMatchId != nil)")
            print("isUserOnRemoteTab: \(isTabVisible)")
            print("isIncomingChallenge: true")
            print("expiryPath: incoming server-side realtime update")
            print("challengeExpiresAt: \(removedMatch.match.challengeExpiresAt?.description ?? "nil")")
            print("joinWindowExpiresAt: \(removedMatch.match.joinWindowExpiresAt?.description ?? "nil")")
            print("status: \(removedMatch.match.status?.rawValue ?? "nil")")
            print("challengerId: \(removedMatch.match.challengerId)")
            print("receiverId: \(removedMatch.match.receiverId)")
            print("currentUserId: \(removedMatch.currentUserId)")
            print("isReceiver: \(removedMatch.match.receiverId == removedMatch.currentUserId)")
            print("=== END EXPIRY DIAGNOSTICS ===")
            
            // === STAGE 2: Storage for expired unseen challenges ===
            // Only store when all preservation conditions are met
            let isReplayOrRematch = removedMatch.match.isReplay == true || removedMatch.match.replaySourceMatchId != nil
            expiredChallengeService.storeExpiredChallenge(
                matchWithPlayers: removedMatch,
                isReplayOrRematch: isReplayOrRematch,
                isUserOnRemoteTab: isTabVisible,
                isIncomingChallenge: true
            )
            
            // Verify via network to determine if it was expired vs other terminal state
            Task {
                await classifyIncomingRemoval(matchId: removedId, removedMatch: removedMatch)
            }
        }
    }
    
    /// Classify an incoming challenge removal by fetching authoritative status
    private func classifyIncomingRemoval(
        matchId: UUID,
        removedMatch: RemoteMatchWithPlayers
    ) async {
        print("ð ð¸ VERIFYING INCOMING TERMINAL REASON match=\(matchId.uuidString.prefix(8))")
        
        // Fetch current authoritative status
        guard let currentMatch = try? await remoteMatchService.fetchMatch(matchId: matchId) else {
            print("â INCOMING EXPIRED SKIPPED - could not fetch match for verification")
            return
        }
        
        let status = currentMatch.status
        print("ð ð¸ INCOMING VERIFIED STATUS = \(status?.rawValue ?? "nil")")
        
        await MainActor.run {
            // Only show declined UI for truly terminal states
            switch status {
            case .expired:
                print("â INCOMING EXPIRED CONFIRMED - server status is expired")
                // Don't show declined UI for expired challenges - they should just disappear
                
            case .cancelled:
                print("â INCOMING CANCELLED CONFIRMED - server status is cancelled")
                // Don't show declined UI for cancelled challenges either
                
            case .ready, .lobby, .inProgress:
                print("â INCOMING TRANSITION - status became \(status?.rawValue ?? "nil")")
                // Normal transition, no expired UI needed
                
            case .completed:
                print("â INCOMING COMPLETED - status became completed")
                
            case .pending, .sent, .none:
                print("â INCOMING UNCLEAR - state was ambiguous: \(status?.rawValue ?? "nil")")
            }
        }
    }
    
    /// Detect declined matches when sent challenges list changes
    /// Uses verification-based approach instead of inference
    private func detectDeclinedMatches(
        old: [RemoteMatchWithPlayers],
        new: [RemoteMatchWithPlayers]
    ) {
        let oldIds = Set(old.map { $0.match.id })
        let newIds = Set(new.map { $0.match.id })
        let removedIds = oldIds.subtracting(newIds)
        
        print("🧪 [DeclineDetect] old=\(oldIds.map { String($0.uuidString.prefix(8)) }.sorted()) new=\(newIds.map { String($0.uuidString.prefix(8)) }.sorted()) removed=\(removedIds.map { String($0.uuidString.prefix(8)) }.sorted())")
        
        for removedId in removedIds {
            print("📤 SENT REMOVAL DETECTED match=\(removedId.uuidString.prefix(8))")
            
            // Find the removed match in OLD snapshot
            guard let removedMatch = old.first(where: { $0.match.id == removedId }) else {
                continue
            }
            
            // GUARD: Previous status was .pending
            guard removedMatch.match.status == .pending else {
                print("⚠️ Skip - status was \(removedMatch.match.status?.rawValue ?? "nil"), not .pending")
                continue
            }
            
            // GUARD: Not expired locally
            guard !expiredMatchIds.contains(removedId) else {
                print("⚠️ Skip - match already expired")
                continue
            }
            
            // GUARD: Not self-cancelled (CRITICAL: preserve this distinction)
            guard !cancelledMatchIds.contains(removedId) else {
                print("✅ DECLINED UI SKIPPED - this was self-cancel")
                continue
            }
            
            // GUARD: Not already handled
            guard !declineHandledMatchIds.contains(removedId),
                  !showDeclinedForMatchIds.contains(removedId),
                  !fadingMatchIds.contains(removedId) else {
                print("⚠️ Skip - already handled")
                continue
            }
            
            // PRIORITY 1: Check local authoritative buckets FIRST
            
            // Check if moved to readyMatches (normal accept flow)
            if remoteMatchService.readyMatches.contains(where: { $0.match.id == removedId }) {
                print("✅ VERIFIED VIA READY BUCKET match=\(removedId.uuidString.prefix(8))")
                continue  // Not declined, moved to ready section
            }
            
            // Check if became active
            if remoteMatchService.activeMatch?.match.id == removedId {
                print("✅ VERIFIED VIA ACTIVE MATCH match=\(removedId.uuidString.prefix(8))")
                continue
            }
            
            // Check if being processed (accept/join in flight)
            if remoteMatchService.processingMatchId == removedId {
                print("✅ VERIFIED VIA PROCESSING STATE match=\(removedId.uuidString.prefix(8))")
                continue
            }
            
            // PRIORITY 2: If local state unclear, verify via network
            Task {
                await classifySentRemoval(matchId: removedId, removedMatch: removedMatch)
            }
        }
    }
    
    /// Classify a sent challenge removal by fetching authoritative status
    /// Only shows declined UI for verified terminal decline-like states
    private func classifySentRemoval(
        matchId: UUID,
        removedMatch: RemoteMatchWithPlayers
    ) async {
        print("🔍 VERIFYING TERMINAL REASON match=\(matchId.uuidString.prefix(8))")
        
        // Fetch current authoritative status
        // Note: fetchMatch may mutate flow state, but we're only reading the status
        guard let currentMatch = try? await remoteMatchService.fetchMatch(matchId: matchId) else {
            print("⚠️ DECLINED UI SKIPPED - could not fetch match for verification")
            return
        }
        
        let status = currentMatch.status
        print("🔍 VERIFIED STATUS = \(status?.rawValue ?? "nil")")
        
        await MainActor.run {
            // Double-check self-cancel state hasn't changed
            if cancelledMatchIds.contains(matchId) {
                print("✅ DECLINED UI SKIPPED - this was self-cancel")
                return
            }
            
            // Only show declined UI for truly terminal decline-like states
            switch status {
            case .expired:
                print("✅ DECLINED UI SHOWN - verified terminal state: expired")
                handleDecline(match: removedMatch)
                
            case .cancelled:
                // CRITICAL: Only show decline if NOT self-cancelled
                // Self-cancel is already excluded above, but be explicit
                print("✅ DECLINED UI SHOWN - verified terminal state: cancelled (receiver-declined)")
                handleDecline(match: removedMatch)
                
            case .ready, .lobby, .inProgress:
                print("✅ DECLINED UI SKIPPED - status became \(status?.rawValue ?? "nil")")
                // Normal transition, no declined UI needed
                
            case .completed:
                print("✅ DECLINED UI SKIPPED - status became completed")
                
            case .pending, .sent, .none:
                print("⚠️ DECLINED UI SKIPPED - state was ambiguous: \(status?.rawValue ?? "nil")")
                // Unclear state, don't show declined
            }
        }
    }
    
    /// Client-side expiry check for sent challenges
    /// Returns true if the challenge has expired based on current time
    private func checkClientSideExpiry(for match: RemoteMatchWithPlayers, at currentTime: Date) -> Bool {
        // For sent challenges, check against challengeExpiresAt
        guard let expiresAt = match.match.challengeExpiresAt else {
            return false
        }
        
        let isExpired = currentTime > expiresAt
        
        // Only log when expiry state changes to avoid spam
        if isExpired && !expiredMatchIds.contains(match.id) {
            print("⏰ [ClientExpiry] Sent challenge expired - matchId=\(match.match.id.uuidString.prefix(8)) expiresAt=\(expiresAt) now=\(currentTime)")
        }
        
        return isExpired
    }
    
    /// Handle decline event - show declined state and schedule cleanup
    private func handleDecline(match: RemoteMatchWithPlayers) {
        let matchId = match.match.id
        
        // Primary guard: ensure toast/timer run only once
        guard !declineHandledMatchIds.contains(matchId) else {
            print("â ï¸ Decline already handled for: \(matchId)")
            return
        }
        
        // CRITICAL: Final confirmation that match is NOT transitioning to ready/active
        // This protects the challenger side during accept transitions
        let isNowReady = remoteMatchService.readyMatches.contains(where: { $0.match.id == matchId })
        let isNowActive = remoteMatchService.activeMatch?.match.id == matchId
        let isInEnterFlow = remoteMatchService.isPendingEnterFlow(matchId: matchId)
        
        guard !isNowReady && !isNowActive && !isInEnterFlow else {
            print("â ï¸ Abort decline - match is now ready/active/entering (challenger side protection)")
            return
        }
        
        // === EXPIRED CHALLENGE DIAGNOSTICS (Server-side expiry path) ===
        // This handles the case where user is ON Remote tab and server updates status to .expired
        if match.match.status == .expired {
            // Find the match context for diagnostics
            var isReplayOrRematch = false
            var isIncomingChallenge = false
            
            // Determine if this is an incoming challenge and if it's a replay
            if match.match.challengerId != match.currentUserId {
                // Current user is receiver - this is an incoming challenge
                isIncomingChallenge = true
                isReplayOrRematch = match.match.isReplay == true || match.match.replaySourceMatchId != nil
            } else {
                // Current user is challenger - this is an outgoing challenge
                isIncomingChallenge = false
                isReplayOrRematch = match.match.isReplay == true || match.match.replaySourceMatchId != nil
            }
            
            // Determine if user is currently on Remote tab (always true for this path)
            let isUserOnRemoteTab = isTabVisible
            
            // Log diagnostic information
            print("=== CHALLENGE EXPIRY DETECTED (SERVER-SIDE) ===")
            print("matchId: \(matchId)")
            print("isReplayOrRematch: \(isReplayOrRematch)")
            print("isUserOnRemoteTab: \(isUserOnRemoteTab)")
            print("isIncomingChallenge: \(isIncomingChallenge)")
            print("expiryPath: server-side realtime update")
            print("challengeExpiresAt: \(match.match.challengeExpiresAt?.description ?? "nil")")
            print("joinWindowExpiresAt: \(match.match.joinWindowExpiresAt?.description ?? "nil")")
            print("status: \(match.match.status?.rawValue ?? "nil")")
            print("challengerId: \(match.match.challengerId)")
            print("receiverId: \(match.match.receiverId)")
            print("currentUserId: \(match.currentUserId)")
            print("isReceiver: \(match.match.receiverId == match.currentUserId)")
            print("=== END EXPIRY DIAGNOSTICS ===")
            
            // === STAGE 2: Storage for expired unseen challenges ===
            // Only store when all preservation conditions are met
            expiredChallengeService.storeExpiredChallenge(
                matchWithPlayers: match,
                isReplayOrRematch: isReplayOrRematch,
                isUserOnRemoteTab: isUserOnRemoteTab,
                isIncomingChallenge: isIncomingChallenge
            )
        }
        
        print("ð « Starting decline display for match: \(matchId)")
        
        // Mark as handled IMMEDIATELY (before any async work)
        declineHandledMatchIds.insert(matchId)
        
        // Cache the match data
        declinedMatchesCache[matchId] = match
        
        // Mark as showing declined
        showDeclinedForMatchIds.insert(matchId)
        
        print("ð § [DeclineDebug] Cached declined match wrapperId=\(match.id.uuidString.prefix(8)) matchId=\(matchId.uuidString.prefix(8))")
        logDeclineDebugSnapshot("after inserting declined cache")
        
        // TODO: Show toast "Match declined"
        
        // Schedule cleanup after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Guard: Only proceed if match is still in declined cache
            // (it may have been cleaned up if it became ready/active)
            guard declinedMatchesCache[matchId] != nil else {
                print("⚠️ Skipping declined fade - match was cleaned up (became ready/active)")
                return
            }
            
            print("🌫️ Starting fade for declined match: \(matchId)")
            fadingMatchIds.insert(matchId)
            showDeclinedForMatchIds.remove(matchId)
            
            logDeclineDebugSnapshot("after starting declined fade")
            
            // Remove after fade completes (0.5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // Guard: Only proceed if match is still in declined cache
                guard declinedMatchesCache[matchId] != nil else {
                    print("⚠️ Skipping declined removal - match was cleaned up (became ready/active)")
                    fadingMatchIds.remove(matchId)  // Clean up fading state if it was set
                    return
                }
                
                print("🗑️ Removing declined match from cache: \(matchId)")
                expiredMatchIds.insert(matchId)
                fadingMatchIds.remove(matchId)
                declinedMatchesCache.removeValue(forKey: matchId)
                declineHandledMatchIds.remove(matchId)  // Clean up guard
                
                logDeclineDebugSnapshot("after removing declined cache")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var showGameSelection = false
        
        var body: some View {
            RemoteGamesTab(showGameSelection: $showGameSelection)
                .environmentObject(AuthService.shared)
                .environmentObject(RemoteMatchService())
                .environmentObject(Router.shared)
        }
    }
    
    return PreviewWrapper()
}
    
