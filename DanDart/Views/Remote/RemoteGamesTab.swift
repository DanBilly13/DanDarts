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
    
    @Binding var showGameSelection: Bool
    
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var expiredMatchIds: Set<UUID> = []
    @State private var fadingMatchIds: Set<UUID> = []
    @State private var cancelledMatchIds: Set<UUID> = []

    // Only show the full-screen loading view on the very first load.
    // For subsequent background refreshes, keep the list mounted to avoid row DISAPPEAR/APPEAR flashes.
    @State private var hasLoadedOnce = false
    
    // Track if we've requested permissions this session
    @State private var hasRequestedPermissions = false
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
            // Check and request notification permissions (Phase 8)
            await checkNotificationPermissions()
            
            // Request voice permission if needed (Phase 12.1)
            // This happens AFTER notifications, from stable top-level state
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
                        .onAppear {
                            let presentationState = cardPresentationState(for: matchWithPlayers, isExpired: isExpired, showAsDeclined: false)
                            print("🟢 [ReadyCard] APPEAR matchId=\(matchWithPlayers.match.id.uuidString.prefix(8)) state=\(presentationState.displayName) isProcessing=\(remoteMatchService.processingMatchId == matchWithPlayers.match.id) hasOnDecline=true")
                        }
                        .onDisappear {
                            print("🟢 [ReadyCard] DISAPPEAR matchId=\(matchWithPlayers.match.id.uuidString.prefix(8))")
                        }
                        .onChange(of: cardPresentationState(for: matchWithPlayers, isExpired: isExpired, showAsDeclined: false)) { oldState, newState in
                            print("🟢 [ReadyCard] STATE CHANGE matchId=\(matchWithPlayers.match.id.uuidString.prefix(8)) old=\(oldState.displayName) new=\(newState.displayName)")
                        }
                        .onChange(of: remoteMatchService.processingMatchId == matchWithPlayers.match.id) { oldValue, newValue in
                            print("🟢 [ReadyCard] isProcessing CHANGE matchId=\(matchWithPlayers.match.id.uuidString.prefix(8)) old=\(oldValue) new=\(newValue)")
                        }
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
                    let isExpired = matchWithPlayers.isExpired
                    let isFading = fadingMatchIds.contains(matchWithPlayers.id)
                    let showAsDeclined = showDeclinedForMatchIds.contains(matchWithPlayers.match.id)
                    let presentationState = cardPresentationState(
                        for: matchWithPlayers,
                        isExpired: isExpired,
                        showAsDeclined: showAsDeclined
                    )
                    if !expiredMatchIds.contains(matchWithPlayers.id) &&
                       matchWithPlayers.id != remoteMatchService.activeMatch?.id {
                        PlayerChallengeCard(
                            matchId: matchWithPlayers.match.id,
                            player: player(from: matchWithPlayers),
                            state: presentationState,
                            gameType: matchWithPlayers.match.gameType,
                            matchFormat: matchWithPlayers.match.matchFormat,
                            isProcessing: remoteMatchService.processingMatchId == matchWithPlayers.match.id,
                            expiresAt: matchWithPlayers.match.joinWindowExpiresAt ?? matchWithPlayers.match.challengeExpiresAt,
                            onDecline: { cancelMatch(matchId: matchWithPlayers.match.id) }
                        )
                        .id(matchWithPlayers.match.id)
                        .remoteCardHighlight(isHighlighted: highlightedMatchId == matchWithPlayers.match.id)
                        .onAppear {
                            print("🧪 [DeclineRow] APPEAR wrapperId=\(matchWithPlayers.id.uuidString.prefix(8)) matchId=\(matchWithPlayers.match.id.uuidString.prefix(8)) showAsDeclined=\(showAsDeclined) state=\(String(describing: presentationState))")
                        }
                        .onDisappear {
                            print("🧪 [DeclineRow] DISAPPEAR wrapperId=\(matchWithPlayers.id.uuidString.prefix(8)) matchId=\(matchWithPlayers.match.id.uuidString.prefix(8)) showAsDeclined=\(showAsDeclined) state=\(String(describing: presentationState))")
                        }
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
    
    // STABLE arrays: Prevent section migration during processing
    // While processingMatchId is set, keep the match in its original section
    private var readyForUIStable: [RemoteMatchWithPlayers] {
        guard let processingId = remoteMatchService.processingMatchId else {
            return readyForUI
        }
        // Exclude processing match from ready section
        return readyForUI.filter { $0.match.id != processingId }
    }
    
    private var pendingForUIStable: [RemoteMatchWithPlayers] {
        guard let processingId = remoteMatchService.processingMatchId else {
            return pendingForUI
        }
        
        // If processing match is already in pending, keep it there
        if pendingForUI.contains(where: { $0.match.id == processingId }) {
            return pendingForUI
        }
        
        // If processing match moved to ready, add it back to pending for display
        if let processingMatch = readyForUI.first(where: { $0.match.id == processingId }) {
            var stable = pendingForUI
            stable.append(processingMatch)
            return stable
        }
        
        // If processing match moved to sent, add it back to pending for display
        if let processingMatch = sentForUI.first(where: { $0.match.id == processingId }) {
            var stable = pendingForUI
            stable.append(processingMatch)
            return stable
        }
        
        return pendingForUI
    }
    
    private var sentForUIStable: [RemoteMatchWithPlayers] {
        guard let processingId = remoteMatchService.processingMatchId else {
            return sentForUI
        }
        // Exclude processing match from sent section
        return sentForUI.filter { $0.match.id != processingId }
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
    private func freezeListSnapshot() {
        guard !listFrozen else { return }
        // Capture ONCE from the service
        frozenPending = remoteMatchService.pendingChallenges
        frozenReady = remoteMatchService.readyMatches
        frozenSent = remoteMatchService.sentChallenges
        listFrozen = true
        print("🧊 [ListFreeze] Snapshot captured - pending: \(frozenPending.count), ready: \(frozenReady.count), sent: \(frozenSent.count)")
    }
    
    @MainActor
    private func unfreezeListSnapshot() {
        listFrozen = false
        frozenPending = []
        frozenReady = []
        frozenSent = []
        print("🧊 [ListFreeze] Snapshot cleared - list unfrozen")
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
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        print("🧪 [DeclineTopLevel] showing matchListView")
                    }
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
                let oldIds = previousSentChallenges.map { String($0.match.id.uuidString.prefix(8)) }.sorted()
                let newIds = newValue.map { String($0.match.id.uuidString.prefix(8)) }.sorted()
                print("🧪 [DeclineDebug] sentChallenges publisher old=\(oldIds) new=\(newIds)")

                detectDeclinedMatches(old: previousSentChallenges, new: newValue)
                previousSentChallenges = newValue

                logDeclineDebugSnapshot("after sentChallenges publisher update")
            }
            .onReceive(remoteMatchService.$readyMatches) { newReadyMatches in
                // Clean up any cached declined matches that have become ready
                for readyMatch in newReadyMatches {
                    let matchId = readyMatch.match.id
                    if declinedMatchesCache[matchId] != nil {
                        print("🧹 Cleaning up declined cache - match became ready: \(matchId.uuidString.prefix(8))")
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
                    print("🧹 Cleaning up declined cache - match became active: \(matchId.uuidString.prefix(8))")
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
        VStack(spacing: 24) {
            Color.clear
                .frame(height: 0)
                .onAppear {
                    print("🧪 [DeclineTopLevel] showing emptyStateView")
                }
            
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
    
    /// Check notification permissions and request if needed (Phase 8)
    private func checkNotificationPermissions() async {
        // DEBUG: Print JWT token for testing push notifications
        await authService.printCurrentUserToken()
        
        // Only request once per session
        guard !hasRequestedPermissions else {
            // Even if we already requested, retry token sync on subsequent visits
            await notificationService.retryTokenSyncIfNeeded()
            return
        }
        
        // Check current status
        await notificationService.checkAuthorizationStatus()
        
        // If not determined, request permissions
        if notificationService.authorizationStatus == .notDetermined {
            do {
                try await notificationService.requestPermissions()
                hasRequestedPermissions = true
            } catch {
                print("❌ Failed to request notification permissions: \(error)")
            }
        } else if notificationService.authorizationStatus == .authorized {
            // If already authorized, retry token sync in case it failed previously
            await notificationService.retryTokenSyncIfNeeded()
        }
    }
    
    /// Request microphone permission for voice chat (Phase 12.1)
    /// Only runs once per session, from stable top-level Remote Games context
    private func requestVoicePermissionIfNeeded() async {
        // Only request once per session
        guard !hasRequestedVoicePermission else {
            return
        }
        
        // Only request if not already determined
        guard VoicePermissionManager.shared.microphoneAuthorizationStatus == .undetermined else {
            return
        }
        
        // Only request if we haven't attempted the initial prompt before
        guard !VoicePermissionManager.shared.hasAttemptedInitialPrompt else {
            return
        }
        
        // Small delay to ensure screen is stable after notifications dialog
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("🎤 [RemoteGamesTab] Requesting microphone permission for voice chat...")
        
        // Request permission
        let granted = await VoicePermissionManager.shared.requestMicrophonePermissionIfNeeded()
        hasRequestedVoicePermission = true
        
        if granted {
            print("✅ [RemoteGamesTab] Microphone permission granted - voice chat available")
        } else {
            print("ℹ️ [RemoteGamesTab] Microphone permission denied - remote matches will work without voice")
        }
    }
    
    // MARK: - Button Actions
    
    private func acceptChallenge(matchId: UUID) {
        
        // Prevent double-accept
        guard remoteMatchService.processingMatchId == nil else {
            return
        }
        
        // CRITICAL: Capture opponent data NOW before state changes
        guard let matchWithPlayers = remoteMatchService.pendingChallenges.first(where: { $0.match.id == matchId }) else {
            print("❌ [RemoteGamesTab] acceptChallenge: match not found in pendingChallenges")
            return
        }
        let opponent = matchWithPlayers.opponent
        
        // FREEZE LIST SNAPSHOT - capture BEFORE any state changes or network calls
        FlowDebug.log("ACCEPT TAP", matchId: matchId)
        freezeListSnapshot()
        
        // BEGIN ENTER FLOW - sets processing, latch, and nav-in-flight all at once
        remoteMatchService.beginEnterFlow(matchId: matchId)
        
        Task {
            do {
                guard let currentUser = authService.currentUser else {
                    throw RemoteMatchError.notAuthenticated
                }
                
                FlowDebug.log("acceptChallenge START", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                // Step 1: Accept challenge (pending → ready)
                try await remoteMatchService.acceptChallenge(matchId: matchId)
                
                FlowDebug.log("acceptChallenge EDGE OK", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                // Step 2: Auto-join match (ready → lobby)
                // Guard: Skip auto-join if match was cancelled
                let isCancelled = await MainActor.run { cancelledMatchIds.contains(matchId) }
                guard !isCancelled else {
                    print("🚫 [DEBUG] Skipping auto-join - match was cancelled")
                    await MainActor.run {
                        remoteMatchService.endEnterFlow(matchId: matchId)
                    }
                    return
                }
                FlowDebug.log("joinMatch START", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
                
                FlowDebug.log("joinMatch OK", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                // Step 2.5: Fetch updated match with joinWindowExpiresAt
                FlowDebug.log("fetchMatch BEFORE", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                print("🔍 [DEBUG] Fetching updated match data...")
                guard let updatedMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    throw RemoteMatchError.databaseError("Failed to fetch updated match")
                }
                let statusStr = updatedMatch.status?.rawValue ?? "nil"
                let cpStr = updatedMatch.currentPlayerId?.uuidString.prefix(8) ?? "nil"
                FlowDebug.log("fetchMatch AFTER status=\(statusStr) cp=\(cpStr)", matchId: matchId)
                await MainActor.run { remoteMatchService.refreshPendingEnterFlow(matchId: matchId) }
                
                print("✅ [DEBUG] Updated match fetched")
                
                // Success haptic
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                
                // Step 3: Navigate to lobby with fresh match data (receiver flow)
                await MainActor.run {
                    print("🔵 [TIMING] MainActor.run START - processingMatchId: \(String(describing: remoteMatchService.processingMatchId))")
                    
                    // Guard: Don't navigate if match was cancelled
                    guard !cancelledMatchIds.contains(matchId) else {
                        print("🚫 [DEBUG] Skipping navigation - match was cancelled")
                        remoteMatchService.endEnterFlow(matchId: matchId)
                        return
                    }
                    
                    FlowDebug.log("NAV REQUEST remoteLobby", matchId: matchId)
                    
                    // Capture token for guard
                    let token = remoteMatchService.navToken
                    let matchIdLocal = matchId
                    
                    // Schedule navigation on next runloop to prevent multi-frame updates
                    Task { @MainActor in
                        // Let SwiftUI finish current frame
                        await Task.yield()
                        
                        // Guard: only push if we're still the active nav request
                        guard remoteMatchService.navInFlightMatchId == matchIdLocal else {
                            FlowDebug.log("NAV SKIP (navInFlight changed)", matchId: matchIdLocal)
                            return
                        }
                        guard token == remoteMatchService.navToken else {
                            FlowDebug.log("NAV SKIP (token changed)", matchId: matchIdLocal)
                            return
                        }
                        
                        FlowDebug.log("NAV PUSH remoteLobby (scheduled)", matchId: matchIdLocal)
                        FlowDebug.log("NAV PUSH .remoteLobby stack=\(Thread.callStackSymbols.prefix(12).joined(separator: "\n"))", matchId: matchIdLocal)
                        
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
                        
                        // DO NOT clear latch here - let it stay active until lobby appears
                        // Latch will be cleared by RemoteLobbyView.onAppear or failsafe timer
                        
                        print("🔵 [TIMING] router.push called - processingMatchId: \(String(describing: remoteMatchService.processingMatchId))")
                    }
                    
                    // Keep processing state active until Lobby.onAppear
                    FlowDebug.log("PROCESSING KEEP (until Lobby onAppear)", matchId: matchId)
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
    
    private func joinMatch(matchId: UUID) {
        // Guard: Don't join if match was cancelled
        guard !cancelledMatchIds.contains(matchId) else {
            print("🚫 [DEBUG] Ignoring join - match was cancelled")
            return
        }
        
        // BEGIN LATCH IMMEDIATELY - before realtime updates can arrive (challenger flow)
        remoteMatchService.beginEnterFlow(matchId: matchId)
        
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
                    // Guard: Don't navigate if match was cancelled
                    guard !cancelledMatchIds.contains(matchId) else {
                        print("🚫 [DEBUG] Skipping navigation - match was cancelled")
                        return
                    }
                    
                    // Navigate to lobby
                    // Find the match in either ready or lobby state
                    let match = remoteMatchService.readyMatches.first(where: { $0.match.id == matchId })
                        ?? remoteMatchService.activeMatch
                    
                    if let matchWithPlayers = match,
                       let currentUser = authService.currentUser {
                        // Latch already active from button tap - just push
                        FlowDebug.log("NAV PUSH .remoteLobby stack=\(Thread.callStackSymbols.prefix(12).joined(separator: "\n"))", matchId: matchId)
                        router.push(.remoteLobby(
                            match: matchWithPlayers.match,
                            opponent: matchWithPlayers.opponent,
                            currentUser: currentUser,
                            cancelledMatchIds: $cancelledMatchIds,
                            onCancel: {
                                Task {
                                    do {
                                        print("🟠 [RemoteTab] onCancel closure called (challenger flow)")
                                        
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
                        
                        // DO NOT clear latch here - let it stay active until lobby appears
                        // Latch will be cleared by RemoteLobbyView.onAppear or failsafe timer
                    }
                }
            } catch {
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
        // Expired takes precedence
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
    
    /// Detect declined matches when sent challenges list changes
    private func detectDeclinedMatches(
        old: [RemoteMatchWithPlayers],
        new: [RemoteMatchWithPlayers]
    ) {
        let oldIds = Set(old.map { $0.match.id })
        let newIds = Set(new.map { $0.match.id })
        let removedIds = oldIds.subtracting(newIds)
        
        print("🧪 [DeclineDetect] old=\(oldIds.map { String($0.uuidString.prefix(8)) }.sorted()) new=\(newIds.map { String($0.uuidString.prefix(8)) }.sorted()) removed=\(removedIds.map { String($0.uuidString.prefix(8)) }.sorted())")
        
        for removedId in removedIds {
            // Find the removed match in OLD snapshot
            guard let removedMatch = old.first(where: { $0.match.id == removedId }) else {
                continue
            }
            
            // 7-CONDITION RULE for showing as declined:
            
            // 1. It was previously visible in the sent section (implicit - we found it in old)
            
            // 2. Its previous authoritative status was .pending
            guard removedMatch.match.status == .pending else {
                print("⚠️ Skip decline - status was \(removedMatch.match.status?.rawValue ?? "nil"), not .pending")
                continue
            }
            
            // 3. It disappears from sent (implicit - we detected removal)
            
            // 4. It does not appear in ready/lobby/inProgress AND is not in an active enter/accept flow
            let movedToActive = remoteMatchService.readyMatches.contains(where: { $0.match.id == removedId }) ||
                               remoteMatchService.activeMatch?.match.id == removedId
            let isBeingProcessed = remoteMatchService.processingMatchId == removedId
            
            guard !movedToActive && !isBeingProcessed else {
                if isBeingProcessed {
                    print("⚠️ Skip decline - match is being processed by accept/join flow")
                } else {
                    print("⚠️ Skip decline - match moved to ready/active")
                }
                continue
            }
            
            // 5. It is not being removed by timeout/expiry
            guard !expiredMatchIds.contains(removedId) else {
                print("⚠️ Skip decline - match already expired")
                continue
            }
            
            // 6. It was not locally cancelled by the challenger
            guard !cancelledMatchIds.contains(removedId) else {
                print("⚠️ Skip decline - match was self-cancelled")
                continue
            }
            
            // 7. We have an authoritative cancel signal (check via realtime or fetch)
            // For now, we infer this from: match disappeared from sent + wasn't moved + wasn't self-cancelled
            // The service filters .cancelled matches, so disappearance after passing above checks = declined
            
            // Prevent duplicate handling
            guard !declineHandledMatchIds.contains(removedId),
                  !showDeclinedForMatchIds.contains(removedId),
                  !fadingMatchIds.contains(removedId) else {
                print("⚠️ Skip decline - already handled")
                continue
            }
            
            print("✅ All 7 conditions met - showing as declined: \(removedId)")
            
            // Preserve match data and trigger declined display
            handleDecline(match: removedMatch)
        }
    }
    
    /// Handle decline event - show declined state and schedule cleanup
    private func handleDecline(match: RemoteMatchWithPlayers) {
        let matchId = match.match.id
        
        // Primary guard: ensure toast/timer run only once
        guard !declineHandledMatchIds.contains(matchId) else {
            print("⚠️ Decline already handled for: \(matchId)")
            return
        }
        
        // CRITICAL: Final confirmation that match is NOT transitioning to ready/active
        // This protects the challenger side during accept transitions
        let isNowReady = remoteMatchService.readyMatches.contains(where: { $0.match.id == matchId })
        let isNowActive = remoteMatchService.activeMatch?.match.id == matchId
        let isInEnterFlow = remoteMatchService.isPendingEnterFlow(matchId: matchId)
        
        guard !isNowReady && !isNowActive && !isInEnterFlow else {
            print("⚠️ Abort decline - match is now ready/active/entering (challenger side protection)")
            return
        }
        
        print("🚫 Starting decline display for match: \(matchId)")
        
        // Mark as handled IMMEDIATELY (before any async work)
        declineHandledMatchIds.insert(matchId)
        
        // Cache the match data
        declinedMatchesCache[matchId] = match
        
        // Mark as showing declined
        showDeclinedForMatchIds.insert(matchId)
        
        print("🧪 [DeclineDebug] Cached declined match wrapperId=\(match.id.uuidString.prefix(8)) matchId=\(matchId.uuidString.prefix(8))")
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
    
