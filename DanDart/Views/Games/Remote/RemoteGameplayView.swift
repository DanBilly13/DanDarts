//
//  CountdownGameplayView.swift
//  Dart Freak
//
//  Full-screen gameplay view for countdown games (301/501)
//  Design: Calculator-inspired scoring with dark theme
//

import SwiftUI

struct RemoteGameplayView: View {
    let matchId: UUID
    let challenger: User
    let receiver: User
    let currentUserId: UUID
    @Binding var selectedTab: Int
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: RemoteGameViewModel
    @StateObject private var syncManager: RemoteGameSyncManager
    @StateObject private var revealState: RemoteTurnRevealState
    @StateObject private var scoreAnimationHandler: RemoteScoreAnimationHandler
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var showUndoConfirmation: Bool = false
    @State private var showLegWinCelebration: Bool = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    @State private var isScoreboardExpanded: Bool = false
    @State private var isSaving: Bool = false
    @State private var isNavigatingToGameEnd: Bool = false
    @State private var completedMatchId: UUID?
    
    // Local score hold - prevents flash when override clears before server catches up
    @State private var localScoreHold: [UUID: Int] = [:]
    @State private var localScoreHoldExpiry: [UUID: Date] = [:]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    @EnvironmentObject var remoteMatchService: RemoteMatchService
    @EnvironmentObject var voiceChatService: VoiceChatService
    
    // MARK: - Live Match Data
    
    /// Live match - observe remoteMatchService directly for reactive updates
    private var liveMatch: RemoteMatch? {
        // Prefer flowMatch if present and matches our ID
        if let fm = remoteMatchService.flowMatch, fm.id == matchId {
            return fm
        }
        // Fallback to activeMatch
        if let am = remoteMatchService.activeMatch?.match, am.id == matchId {
            return am
        }
        return nil
    }
    
    private var adapter: RemoteGameStateAdapter? {
        guard let m = liveMatch else { return nil }
        return RemoteGameStateAdapter(
            match: m,
            challenger: challenger,
            receiver: receiver,
            currentUserId: currentUserId
        )
    }
    
    // MARK: - Unified Render Source (Server-Authoritative)
    
    /// Primary match data: prefer server, fallback to liveMatch
    private var renderMatch: RemoteMatch? {
        remoteMatchService.flowMatch ?? liveMatch
    }
    
    /// Server-authoritative scores from renderMatch
    private var serverScores: [UUID: Int]? {
        renderMatch?.playerScores
    }
    
    /// Scores for UI: prefer local override, then local hold, then server, then VM
    private var renderScores: [UUID: Int] {
        // Start with server or VM scores
        var mergedScores = serverScores ?? gameViewModel.playerScores
        
        // Overlay local holds (authoritative for display while server is catching up)
        for (playerId, score) in localScoreHold {
            mergedScores[playerId] = score
        }
        
        // Pass merged scores to animation handler (which applies override on top)
        return scoreAnimationHandler.renderScores(serverScores: mergedScores, vmScores: gameViewModel.playerScores)
    }
    
    /// Server-authoritative current player ID
    private var serverCurrentPlayerId: UUID? {
        renderMatch?.currentPlayerId
    }
    
    /// Current player index for UI: derive from display player ID (frozen during reveal)
    private var renderCurrentPlayerIndex: Int {
        // Use displayCurrentPlayerId when transition is locked (during reveal)
        let effectivePlayerId = revealState.turnTransitionLocked ? revealState.displayCurrentPlayerId : serverCurrentPlayerId
        
        guard let playerId = effectivePlayerId,
              let adapter = adapter else {
            return gameViewModel.currentPlayerIndex // Fallback before first turn
        }
        
        // Use adapter's playerIndex method (challenger=0, receiver=1)
        return adapter.playerIndex(for: playerId) ?? gameViewModel.currentPlayerIndex
    }
    
    /// Round number: server-authoritative (increments after both players complete their turns)
    /// Formula: ROUND = (turn_index_in_leg / 2) + 1
    private var renderVisitNumber: Int {
        syncManager.renderVisitNumber
    }
    
    /// Check if it's my turn (server-authoritative with fallback)
    private var isMyTurn: Bool {
        (serverCurrentPlayerId ?? liveMatch?.currentPlayerId) == currentUserId
    }
    
    /// Input gate: only enable when it's my turn AND UI gate is OFF AND not saving
    private var isInputEnabled: Bool {
        isMyTurn && !revealState.turnUIGateActive && !isSaving && !gameViewModel.isSaving
    }
    
    /// CurrentThrowDisplay should show:
    /// - Opponent's darts sequentially during reveal window - PRIORITY
    /// - My input when it's my turn
    /// - Otherwise empty []
    private var renderThrowForCurrentThrowDisplay: [ScoredThrow] {
        if revealState.preTurnRevealIsActive {
            // Show only revealed darts (sequential reveal)
            return Array(revealState.fullOpponentDarts.prefix(revealState.revealedDartCount))
        }
        if isMyTurn { return gameViewModel.currentThrow }
        return []
    }
    
    /// Combined score animation state: current player OR opponent
    /// In remote matches, we animate either:
    /// - Current player's score when they save (gameViewModel.showScoreAnimation)
    /// - Opponent's score during reveal (revealState.showOpponentScoreAnimation)
    private var showAnyScoreAnimation: Bool {
        gameViewModel.showScoreAnimation || revealState.showOpponentScoreAnimation
    }
    
    /// Checkout to display: current player sees live updates, opponent sees frozen initial checkout
    private var renderCheckout: String? {
        if isMyTurn {
            return gameViewModel.suggestedCheckout // Live updates as darts are thrown
        } else {
            return nil // Opponent doesn't see checkout (they see opponent's darts)
        }
    }
    
    // MARK: - Local Score Override Methods (delegated to ScoreAnimationHandler)
    
    /// Set local score override for current player during animation
    private func setLocalScoreOverride(playerId: UUID, score: Int) {
        scoreAnimationHandler.setLocalScoreOverride(
            playerId: playerId,
            score: score,
            serverScores: serverScores,
            vmScores: gameViewModel.playerScores
        )
    }
    
    /// Clear local score override (server scores will take over)
    private func clearLocalScoreOverride() {
        scoreAnimationHandler.clearLocalScoreOverride()
    }
    
    // MARK: - Local Score Hold Methods
    
    /// Set local score hold for a player during animation (prevents flash when override clears)
    private func setLocalScoreHold(playerId: UUID, score: Int, holdSeconds: TimeInterval = 1.25) {
        localScoreHold[playerId] = score
        localScoreHoldExpiry[playerId] = Date().addingTimeInterval(holdSeconds)
        print("🔒 [ScoreHold] Set hold: player=\(playerId.uuidString.prefix(8)) score=\(score) expires in \(holdSeconds)s")
        
        // Cleanup after expiry (don't await; just schedule)
        DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds) {
            // Only clear if we're past expiry (avoid racing multiple holds)
            if let expiry = self.localScoreHoldExpiry[playerId], expiry <= Date() {
                self.localScoreHold[playerId] = nil
                self.localScoreHoldExpiry[playerId] = nil
                print("⏱️ [ScoreHold] Expired: player=\(playerId.uuidString.prefix(8))")
            }
        }
    }
    
    /// Clear local score hold if server has caught up to the held value
    private func clearLocalScoreHoldIfServerCaughtUp(serverScores: [UUID: Int]?) {
        guard let serverScores else { return }
        for (playerId, heldScore) in localScoreHold {
            if serverScores[playerId] == heldScore {
                localScoreHold[playerId] = nil
                localScoreHoldExpiry[playerId] = nil
                print("✅ [ScoreHold] Cleared early (server caught up): player=\(playerId.uuidString.prefix(8)) score=\(heldScore)")
            }
        }
    }
    
    // MARK: - Debug Helpers
    
    private func dbg(_ msg: String) {
        print("🧪 [RTGD] \(msg)")
    }
    
    // MARK: - Setup & Lifecycle Helpers
    
    private func setupGameplayView() {
        dbg("onAppear")
        dbgMatchSnapshot("APPEAR")
        print("👁️ [RemoteGameplayView] onAppear - matchId: \(matchId.uuidString.prefix(8))...")
        
        // Task 13: Validate voice session matches current match
        if !voiceChatService.isSessionValid(for: matchId) {
            print("⚠️ [RemoteGameplayView] Voice session mismatch, restarting for match: \(matchId.uuidString.prefix(8))")
            Task {
                do {
                    try await voiceChatService.startSession(for: matchId)
                    print("✅ [RemoteGameplayView] Voice session restarted")
                } catch {
                    print("⚠️ [RemoteGameplayView] Failed to restart voice session: \(error)")
                }
            }
        } else {
            print("✅ [RemoteGameplayView] Voice session valid for current match")
        }
        
        // Wire up syncManager dependencies
        syncManager.remoteMatchService = remoteMatchService
        syncManager.gameViewModel = gameViewModel
        syncManager.startSync()
        
        // Initialize displayCurrentPlayerId to current server state
        revealState.displayCurrentPlayerId = serverCurrentPlayerId
        print("🎯 [TurnGate] Initialized displayCurrentPlayerId=\(revealState.displayCurrentPlayerId?.uuidString.prefix(8) ?? "nil")...")
        
        // 🧪 DEBUG STEP 1: Confirm remoteMatchService exists in environment
        print("🧪 [RemoteGameplay] env remoteMatchService exists, flowMatchId=\(remoteMatchService.flowMatchId?.uuidString.prefix(8) ?? "nil")..., matchId=\(matchId.uuidString.prefix(8))...")
        print("🧪 [RemoteGameplay] remoteMatchService instance: \(ObjectIdentifier(remoteMatchService))")
        
        // Enter remote flow (FlowGate)
        remoteMatchService.enterRemoteFlow(matchId: matchId)
        print("✅ [RemoteGameplayView] Entered remote flow")
        
        // Inject authService into the ViewModel
        gameViewModel.setAuthService(authService)
        
        // Inject remoteMatchService into the ViewModel
        gameViewModel.setRemoteMatchService(remoteMatchService)
        
        // Fetch authoritative match state
        Task { @MainActor in
            _ = try? await remoteMatchService.fetchMatch(matchId: matchId)
        }
        
        // Evaluate turn gate on appear (in case state already present)
        evaluateTurnGate(reason: "onAppear")
        
        setupNotificationObservers()
        
        // Register score override callback (synchronous, prevents race condition)
        gameViewModel.registerScoreOverrideCallback { playerId, score in
            self.setLocalScoreOverride(playerId: playerId, score: score)
            self.setLocalScoreHold(playerId: playerId, score: score, holdSeconds: 1.25)
        }
        
        logTruthTable()
        showGameTipIfNeeded()
    }
    
    private func setupNotificationObservers() {
        scoreAnimationHandler.setupNotificationObservers(
            preTurnRevealIsActive: {
                self.revealState.preTurnRevealIsActive
            },
            onScoreUpdate: { playerId, score in
                self.setLocalScoreOverride(playerId: playerId, score: score)
            },
            onClearOverride: {
                self.clearLocalScoreOverride()
            }
        )
    }
    
    private func logTruthTable() {
        guard let m = liveMatch, let adapter = adapter else { return }
        
        // 🧪 TRUTH TABLE DEBUG
        Self.printTruthTable(
            matchId: matchId,
            liveMatch: liveMatch,
            currentUserId: currentUserId,
            authUserId: authService.currentUser?.id,
            challenger: challenger,
            receiver: receiver,
            adapter: adapter,
            overlayState: adapter.overlayState(isSaving: gameViewModel.isSaving, isRevealing: gameViewModel.isRevealingScore),
            context: "onAppear"
        )
    }
    
    private func showGameTipIfNeeded() {
        guard let m = liveMatch else { return }
        
        // Show game-specific tip if available and not seen before
        if TipManager.shared.shouldShowTip(for: m.gameName) {
            currentTip = TipManager.shared.getTip(for: m.gameName)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { self.showGameTip = true }
            }
        }
    }
    
    private func cleanupGameplayView() {
        // Skip exitRemoteFlow if navigating to GameEnd
        if isNavigatingToGameEnd {
            print("👋 [RemoteGameplayView] onDisappear - skip exitRemoteFlow (navigating to GameEnd)")
            // Cancel reveal timer
            revealState.cancelReveal()
            // Task 13: Voice session persists to GameEnd, don't end it here
            return
        }
        
        print("👋 [RemoteGameplayView] onDisappear - exiting remote flow")
        
        // Task 14: End voice session when exiting remote flow
        Task {
            await voiceChatService.endSession()
            print("✅ [RemoteGameplayView] Voice session ended on flow exit")
        }
        
        // Cancel reveal timer
        revealState.cancelReveal()
        
        // Exit remote flow
        remoteMatchService.exitRemoteFlow()
    }
    
    // MARK: - Server Sync Handlers (delegated to SyncManager)
    
    private func handleServerScoresChange(oldValue: [UUID: Int]?, newValue: [UUID: Int]?) {
        syncManager.handleServerScoresChange(oldValue: oldValue, newValue: newValue)
        
        // If server has caught up to any locally-held scores, release them early
        clearLocalScoreHoldIfServerCaughtUp(serverScores: newValue)
        
        // Don't clear override on server update - let animation complete notification handle it
        // This prevents score revert during animation when server update arrives early
    }
    
    private func handleCurrentPlayerChange(oldValue: UUID?, newValue: UUID?) {
        syncManager.handleCurrentPlayerChange(oldValue: oldValue, newValue: newValue)
        
        // Evaluate turn gate (dual-trigger system)
        evaluateTurnGate(reason: "serverCP change")
    }
    
    private func handleLastVisitTimestampChange(oldValue: String?, newValue: String?) {
        syncManager.handleLastVisitTimestampChange(oldValue: oldValue, newValue: newValue)
        evaluateTurnGate(reason: "lvp.ts change")
    }
    
    private func handleMatchStatusChange(oldStatus: RemoteMatchStatus?, newStatus: RemoteMatchStatus?) {
        syncManager.handleMatchStatusChange(oldStatus: oldStatus, newStatus: newStatus)
    }
    
    private func dbgMatchSnapshot(_ label: String) {
        let m = renderMatch
        let id = m?.id.uuidString.prefix(8) ?? "nil"
        let cp = (serverCurrentPlayerId ?? liveMatch?.currentPlayerId)?.uuidString.prefix(8) ?? "nil"
        let lvp = m?.lastVisitPayload
        let lvpPid = lvp?.playerId.uuidString.prefix(8) ?? "nil"
        let lvpTs = lvp?.timestamp ?? "nil"
        let darts = lvp?.darts ?? []
        dbg("\(label) match=\(id) cp=\(cp) lvp.pid=\(lvpPid) ts=\(lvpTs) darts=\(darts) isMyTurn=\(isMyTurn) preReveal=\(revealState.preTurnRevealIsActive)")
    }
    
    // MARK: - Turn Gate Logic (delegated to RevealState)
    
    /// Centralized turn gate evaluation - triggers on either serverCurrentPlayerId or lastVisitPayload.timestamp changes
    @MainActor
    private func evaluateTurnGate(reason: String) {
        revealState.evaluateTurnGate(
            serverCurrentPlayerId: serverCurrentPlayerId,
            lastVisitPayload: renderMatch?.lastVisitPayload,
            currentUserId: currentUserId,
            renderMatch: renderMatch,
            onScoreOverride: { playerId, score in
                self.setLocalScoreOverride(playerId: playerId, score: score)
            },
            onClearScoreOverride: {
                self.clearLocalScoreOverride()
            },
            onUpdateCheckout: {
                self.gameViewModel.updateCheckoutSuggestion()
            },
            reason: reason
        )
    }
    
    /// Server last visit timestamp (observes renderMatch for reactive updates)
    private var serverLastVisitTimestamp: String? {
        let ts = renderMatch?.lastVisitPayload?.timestamp
        // NOTE: don't log here, it may get called *a lot*. We'll log changes via onChange below.
        return ts
    }
    
    /// Server-authoritative last visit payload (for overlay display)
    private var serverLastVisitPayload: LastVisitPayload? {
        renderMatch?.lastVisitPayload
    }
    
    private var serverLastVisitDarts: [Int]? {
        serverLastVisitPayload?.darts
    }
    
    private var serverLastVisitTotal: Int? {
        guard let darts = serverLastVisitDarts else { return nil }
        return darts.reduce(0, +)
    }
    
    /// Check if the opponent just busted
    /// Only relevant when showing to the inactive player
    /// Note: currentPlayerId has already switched to us by the time we check,
    /// so we just check if the last visit (by opponent) was a bust
    private var didOpponentBust: Bool {
        guard let payload = serverLastVisitPayload else {
            print("🔍 [BustCheck] No serverLastVisitPayload")
            return false
        }
        
        // Check if last visit was by opponent (not us)
        guard payload.playerId != currentUserId else {
            print("🔍 [BustCheck] Last visit was by us, not opponent")
            return false
        }
        
        let isBust = payload.scoreBefore == payload.scoreAfter
        
        print("🔍 [BustCheck] opponent visit - playerId: \(payload.playerId.uuidString.prefix(8))..., scoreBefore: \(payload.scoreBefore), scoreAfter: \(payload.scoreAfter), isBust: \(isBust)")
        
        return isBust
    }
    
    /// Throw display for UI (as [ScoredThrow]):
    /// - If it's NOT my turn (inactiveLockout) OR we are revealing, show the server lastVisit darts.
    /// - Otherwise show my local in-progress input (gameViewModel.currentThrow).
    private var renderThrowForCards: [ScoredThrow] {
        guard let adapter = adapter else { return gameViewModel.currentThrow }
        
        let overlay = adapter.overlayState(
            isSaving: gameViewModel.isSaving,
            isRevealing: gameViewModel.isRevealingScore
        )
        
        let shouldShowServerThrow = (overlay == .inactiveLockout || overlay == .revealing)
        
        if shouldShowServerThrow, let darts = serverLastVisitDarts, darts.count == 3 {
            // Convert [Int] -> [ScoredThrow] for StackedPlayerCards
            // Assume single scores from server (baseValue = totalValue, scoreType = .single)
            return darts.map { ScoredThrow(baseValue: $0, scoreType: .single) }
        }
        
        return gameViewModel.currentThrow
    }

    // MARK: - Derived UI State
    private var flowOverlayState: RemoteGameStateAdapter.OverlayState {
        adapter?.overlayState(isSaving: gameViewModel.isSaving, isRevealing: gameViewModel.isRevealingScore) ?? .none
    }
    
    private var debugRenderProbe: some View {
        let _ = dbgMatchSnapshot("RENDER")
        return EmptyView()
    }

    // MARK: - View Extraction (helps the SwiftUI type-checker)
    private var backgroundLayer: some View {
        AppColor.backgroundPrimary
            .ignoresSafeArea()
    }

    @ViewBuilder
    private func gameplayContent(_ overlayState: RemoteGameStateAdapter.OverlayState, using m: RemoteMatch, adapter: RemoteGameStateAdapter) -> some View {
        // Core gameplay layout, optionally wrapped with a positioned tip overlay
        PositionedTip(
            xPercent: 0.5,
            yPercent: 0.55
        ) {
            if showGameTip, let tip = currentTip {
                TipBubble(
                    systemImageName: tip.icon,
                    title: tip.title,
                    message1: tip.message1,
                    message2: tip.message2,
                    onDismiss: {
                        showGameTip = false
                        TipManager.shared.markTipAsSeen(for: m.gameName)
                    }
                )
                .padding(.horizontal, 24)
            }
        } background: {
            gameplayStack(overlayState, adapter: adapter)
        }
    }

    @ViewBuilder
    private func gameplayStack(_ overlayState: RemoteGameStateAdapter.OverlayState, adapter: RemoteGameStateAdapter) -> some View {
        ZStack {
            VStack(spacing: 0) {
                topSection
                Spacer(minLength: 0)
                bottomSectionWithOverlay(overlayState, adapter: adapter)
            }

            // When expanded, swallow taps anywhere in the gameplay area
            // so the scoreboard behaves like a modal overlay. The
            // navigation bar (above this view) remains interactive.
            if isScoreboardExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea(.container, edges: .bottom)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isScoreboardExpanded = false
                        }
                    }
            }
        }
    }

    private var topSection: some View {
        VStack(spacing: 0) {
            // 🧪 Render Source Debug Logging
            let _ = {
                print("📊 [RenderSource] serverScores=\(serverScores?.description ?? "nil")")
                print("📊 [RenderSource] renderScores=\(renderScores)")
                print("📊 [RenderSource] serverCurrentPlayerId=\(serverCurrentPlayerId?.uuidString.prefix(8) ?? "nil")...")
                print("📊 [RenderSource] renderCurrentPlayerIndex=\(renderCurrentPlayerIndex)")
                print("📊 [RenderSource] renderVisitNumber=\(renderVisitNumber)")
                let source = serverScores != nil ? "SERVER ✅" : "VM fallback"
                print("📊 [RenderSource] UI using: \(source)")
            }()
            
            // Stacked player cards (current player in front / expandable into column)
            StackedPlayerCards(
                players: gameViewModel.players,
                currentPlayerIndex: renderCurrentPlayerIndex,
                playerScores: renderScores,
                currentThrow: renderThrowForCards,
                legsWon: gameViewModel.legsWon,
                matchFormat: gameViewModel.matchFormat,
                showScoreAnimation: showAnyScoreAnimation,
                isExpanded: isScoreboardExpanded,
                onTap: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isScoreboardExpanded = true
                    }
                },
                getOriginalIndex: { player in
                    gameViewModel.originalIndex(of: player)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 56)

            // Current throw display (always visible)
            CurrentThrowDisplay(
                currentThrow: renderThrowForCurrentThrowDisplay,
                selectedDartIndex: isInputEnabled ? gameViewModel.selectedDartIndex : nil,
                onDartTapped: { index in
                    guard isInputEnabled else { return }
                    gameViewModel.selectDart(at: index)
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Checkout suggestion slot
            VStack {
                if revealState.showCheckout, let checkout = renderCheckout {
                    CheckoutSuggestionView(checkout: checkout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 0)
                        .transition(.opacity)
                }
            }
            .frame(height: 40, alignment: .center)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.3), value: revealState.showCheckout)

            Spacer(minLength: 0)
        }
    }

    private var bottomSection: some View {
        VStack(spacing: 0) {
            // Scoring button grid (center)
            ScoringButtonGrid(
                onScoreSelected: { baseValue, scoreType in
                    gameViewModel.recordThrow(value: baseValue, multiplier: scoreType.multiplier)
                },
                showBustButton: gameViewModel.canBust,
                onDelete: {
                    gameViewModel.deleteThrow()
                },
                canDelete: gameViewModel.canDelete
            )
            .disabled(!isInputEnabled)
            .padding(.horizontal, 16)

            // Small breathing room between grid and button (replaces Spacer)
            Color.clear.frame(height: 24)

            // Save Score button container (fixed height to prevent layout shift)
            ZStack {
                // Invisible placeholder to maintain layout space
                AppButton(role: .primary, controlSize: .extraLarge, action: {}) {
                    Text("Save Score")
                }
                .opacity(0)
                .disabled(true)

                // Actual button that pops in/out
                AppButton(
                    role: gameViewModel.isWinningThrow ? .secondary : .primary,
                    controlSize: .extraLarge,
                    action: {
                        guard isInputEnabled else { return }
                        // View-local saving flag (remote RPC wiring comes in Phase 4)
                        isSaving = true
                        gameViewModel.saveScore()
                        // Reset quickly to avoid sticking UI in saving state for local logic
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isSaving = false
                        }
                    }
                ) {
                    if isSaving {
                        if gameViewModel.isWinningThrow {
                            Label("Game Over", systemImage: "trophy.fill")
                        } else {
                            Label("Save Score", systemImage: "checkmark.circle.fill")
                        }
                    } else if gameViewModel.isWinningThrow {
                        Label("Game Over", systemImage: "trophy.fill")
                    } else if gameViewModel.isBust {
                        Text("Bust")
                    } else {
                        Label("Save Score", systemImage: "checkmark.circle.fill")
                    }
                }
                .blur(radius: menuCoordinator.activeMenuId != nil ? 2 : 0)
                .opacity(menuCoordinator.activeMenuId != nil ? 0.4 : 1.0)
                // Reusable pop animation (applies to all button states)
                .popAnimation(
                    active: gameViewModel.isTurnComplete,
                    duration: gameViewModel.isWinningThrow ? 0.32 : 0.28,
                    bounce: gameViewModel.isWinningThrow ? 0.28 : 0.22
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 34)
        }
    }
    
    @ViewBuilder
    private func bottomSectionWithOverlay(
        _ overlayState: RemoteGameStateAdapter.OverlayState,
        adapter: RemoteGameStateAdapter
    ) -> some View {
        ZStack {
            bottomSection
                .allowsHitTesting(!overlayState.isVisible)

            if overlayState.isVisible {
                Color.black.opacity(0.70)
                    .ignoresSafeArea(.container, edges: .bottom)

                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: overlayIconName(for: overlayState))
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)

                    Text(bottomOverlayTitle(for: overlayState, adapter: adapter))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textPrimary)
                        .multilineTextAlignment(.center)

                    if let subtitle = bottomOverlaySubtitle(for: overlayState, adapter: adapter) {
                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
    }

    private func overlayIconName(for overlayState: RemoteGameStateAdapter.OverlayState) -> String {
        switch overlayState {
        case .none: return ""
        case .inactiveLockout: return "hourglass"
        case .saving: return "arrow.up.circle.fill"
        case .revealing: return "checkmark.circle.fill"
        }
    }

    private func bottomOverlayTitle(for overlayState: RemoteGameStateAdapter.OverlayState, adapter: RemoteGameStateAdapter) -> String {
        switch overlayState {
        case .none:
            return ""
        case .inactiveLockout:
            return "\(adapter.opponent.displayName) is throwing"
        case .saving:
            return "Saving visit..."
        case .revealing:
            return "Visit saved"
        }
    }

    private func bottomOverlaySubtitle(for overlayState: RemoteGameStateAdapter.OverlayState, adapter: RemoteGameStateAdapter) -> String? {
        let subtitle: String?
        
        switch overlayState {
        case .none:
            subtitle = nil
        case .inactiveLockout:
            // Only show "Bust" if opponent busted
            let bustCheck = didOpponentBust
            subtitle = bustCheck ? "Bust" : nil
            print("📝 [Subtitle] overlayState: .inactiveLockout, didOpponentBust: \(bustCheck), subtitle: \(subtitle ?? "nil")")
        case .saving:
            subtitle = "Please wait"
        case .revealing:
            subtitle = nil
        }
        
        return subtitle
    }
    
    init(matchId: UUID, challenger: User, receiver: User, currentUserId: UUID, selectedTab: Binding<Int>) {
        self.matchId = matchId
        self.challenger = challenger
        self.receiver = receiver
        self.currentUserId = currentUserId
        self._selectedTab = selectedTab
        
        print("🎯 [RemoteGameplayView] Init - matchId: \(matchId.uuidString.prefix(8))...")
        
        // Create temporary adapter for initialization (will use live match later)
        let tempAdapter = RemoteGameStateAdapter(
            match: RemoteMatch(
                id: matchId,
                matchMode: "remote",
                gameType: "301",
                gameName: "301",
                matchFormat: 1,
                challengerId: challenger.id,
                receiverId: receiver.id,
                status: .inProgress,
                currentPlayerId: nil,
                challengeExpiresAt: nil,
                joinWindowExpiresAt: nil,
                lastVisitPayload: nil,
                createdAt: Date(),
                updatedAt: Date(),
                endedBy: nil,
                endedReason: nil,
                winnerId: nil,
                debugCounter: nil
            ),
            challenger: challenger,
            receiver: receiver,
            currentUserId: currentUserId
        )
        
        // Create game (will be updated from live match)
        let game = Game(
            title: "301",
            subtitle: "Remote Match",
            players: "2 Players",
            instructions: ""
        )
        
        // Create players array
        let players = tempAdapter.createPlayersArray()
        
        // Initialize ViewModel
        _gameViewModel = StateObject(
            wrappedValue: RemoteGameViewModel(
                game: game,
                players: players,
                matchFormat: 1,
                authService: nil,
                remoteMatchId: matchId
            )
        )
        
        // Initialize SyncManager
        _syncManager = StateObject(
            wrappedValue: RemoteGameSyncManager(
                matchId: matchId,
                challenger: challenger,
                receiver: receiver,
                currentUserId: currentUserId
            )
        )
        
        // Initialize RevealState
        _revealState = StateObject(
            wrappedValue: RemoteTurnRevealState()
        )
        
        // Initialize ScoreAnimationHandler
        _scoreAnimationHandler = StateObject(
            wrappedValue: RemoteScoreAnimationHandler()
        )
    }
    
    // Helper function for navigation title using live match
    private func navigationTitle(using m: RemoteMatch) -> String {
        let gameTitle = m.gameName
        
        if gameViewModel.matchFormat > 1 {
            return "\(gameTitle)  LEG \(gameViewModel.currentLeg)/\(gameViewModel.matchFormat)  ROUND \(renderVisitNumber)"
        } else {
            return "\(gameTitle)  ROUND \(renderVisitNumber)"
        }
    }
    
    // MARK: - Body Extraction (helps the SwiftUI type-checker)

    private func contentWithNavigation(using m: RemoteMatch, adapter: RemoteGameStateAdapter) -> some View {
        let baseOverlayState = adapter.overlayState(
            isSaving: gameViewModel.isSaving,
            isRevealing: gameViewModel.isRevealingScore
        )
        
        // 🎯 UI GATE: keep the lock overlay up through reveal + rotate + padding
        let overlayState: RemoteGameStateAdapter.OverlayState = {
            if revealState.turnUIGateActive {
                return .inactiveLockout
            }
            return baseOverlayState
        }()
        
        return gameplayContent(overlayState, using: m, adapter: adapter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Task 12: Voice control button (top-left)
                ToolbarItem(placement: .topBarLeading) {
                    voiceControlButton
                }
                
                ToolbarItem(placement: .principal) {
                    Text(navigationTitle(using: m))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GameplayMenuButton(
                        onInstructions: { showInstructions = true },
                        onRestart: { showRestartAlert = true },
                        onExit: { showExitAlert = true },
                        onUndo: { showUndoConfirmation = true },
                        canUndo: gameViewModel.canUndo
                    )
                }
            }
            .toolbarBackground(AppColor.backgroundPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationBarBackButtonHidden(true)
            .interactiveDismissDisabled()
            .ignoresSafeArea(.container, edges: .bottom)
    }
    
    @ViewBuilder
    private var gameplayRootView: some View {
        Group {
            if let m = liveMatch, let adapter = adapter {
                contentWithNavigation(using: m, adapter: adapter)
                    .background(debugRenderProbe)
                    .onAppear { setupGameplayView() }
                    .onDisappear { cleanupGameplayView() }
                    .onChange(of: serverScores, handleServerScoresChange)
                    .onChange(of: serverCurrentPlayerId, handleCurrentPlayerChange)
                    .onChange(of: renderMatch?.lastVisitPayload?.timestamp, handleLastVisitTimestampChange)
                    .onChange(of: renderMatch?.status, handleMatchStatusChange)
                    .onChange(of: (serverCurrentPlayerId ?? liveMatch?.currentPlayerId)) { oldId, newId in
                        dbg("onChange(currentPlayerId) old=\(oldId?.uuidString.prefix(8) ?? "nil") new=\(newId?.uuidString.prefix(8) ?? "nil")")
                        dbgMatchSnapshot("CP_CHANGE")
                    }
                    .onChange(of: revealState.preTurnRevealIsActive) { old, new in
                        dbg("onChange(preTurnRevealIsActive) \(old) -> \(new)")
                        dbgMatchSnapshot("REVEAL_FLAG_CHANGE")
                    }
                    .onChange(of: renderThrowForCurrentThrowDisplay.count) { old, new in
                        dbg("onChange(renderThrowForCurrentThrowDisplay.count) \(old) -> \(new)")
                        dbgMatchSnapshot("THROW_COUNT_CHANGE")
                    }
            } else {
                // Loading state - show progress view until match loads
                ProgressView("Loading match…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.backgroundPrimary.ignoresSafeArea())
                    .onAppear {
                        print("⏳ [RemoteGameplayView] Waiting for live match...")
                        // Kick fetch if we arrived before flowMatch is set
                        Task { @MainActor in
                            _ = try? await remoteMatchService.fetchMatch(matchId: matchId)
                        }
                    }
            }
        }
            .alert("Exit Game", isPresented: $showExitAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Abort Game", role: .destructive) {
                    print("🟠 [ExitGame] Abort Game button tapped - matchId: \(matchId)")
                    Task {
                        do {
                            try await remoteMatchService.abortMatch(matchId: matchId)
                            print("✅ [ExitGame] Match aborted successfully")
                            await MainActor.run {
                                router.popToRoot()
                            }
                        } catch {
                            print("❌ [ExitGame] Failed to abort match: \(error)")
                            // Still navigate back even on error
                            await MainActor.run {
                                router.popToRoot()
                            }
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to abort the match? This will end the game for both players.")
            }
            .alert("Restart Game", isPresented: $showRestartAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restart", role: .destructive) { gameViewModel.restartGame() }
            } message: {
                Text("Are you sure you want to restart the game? All progress will be lost.")
            }
            .alert("Undo Last Visit", isPresented: $showUndoConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Undo", role: .destructive) { gameViewModel.undoLastVisit() }
            } message: {
                if let visit = gameViewModel.lastVisit {
                    Text("Undo visit by \(visit.playerName)?\n\nScore will revert from \(visit.newScore) to \(visit.previousScore).")
                } else {
                    Text("Undo the last visit?")
                }
            }
            .sheet(isPresented: $showInstructions) { EmptyView() }
            .onChange(of: gameViewModel.legWinner) { _, newValue in
                if newValue != nil && !gameViewModel.isMatchWon {
                    showLegWinCelebration = true
                }
            }
            .onChange(of: gameViewModel.winner) { _, newValue in
                if let winner = newValue, let m = liveMatch {
                    // ✅ Freeze the match ID immediately when game completes
                    // This prevents using a stale reference if liveMatch changes due to realtime updates
                    completedMatchId = m.id
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // Set flag to prevent exitRemoteFlow in onDisappear
                        isNavigatingToGameEnd = true
                        
                        let tempGame = Game(
                            title: m.gameName,
                            subtitle: "Remote Match",
                            players: "2 Players",
                            instructions: ""
                        )
                        
                        router.push(.gameEnd(
                            game: tempGame,
                            winner: winner,
                            players: gameViewModel.players,
                            onPlayAgain: {
                                // Exit remote flow before restarting
                                remoteMatchService.exitRemoteFlow()
                                
                                gameViewModel.restartGame()
                                router.pop()
                            },
                            onBackToGames: {
                                // CRITICAL: Exit remote flow to clear state and trigger list refresh
                                remoteMatchService.exitRemoteFlow()
                                
                                router.popToRoot()
                                selectedTab = 0  // Switch to main Games tab
                            },
                            matchFormat: gameViewModel.isMultiLegMatch ? gameViewModel.matchFormat : nil,
                            legsWon: gameViewModel.isMultiLegMatch ? gameViewModel.legsWon : nil,
                            matchId: completedMatchId,
                            matchResult: nil
                        ))
                    }
                }
            }
            .alert("Leg Won!", isPresented: $showLegWinCelebration) {
                Button("Next Leg") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        gameViewModel.resetLeg()
                    }
                }
            } message: {
                if let legWinner = gameViewModel.legWinner {
                    let winnerLegs = gameViewModel.legsWon[legWinner.id] ?? 0
                    Text("\(legWinner.displayName) wins the leg! (\(winnerLegs) legs won)")
                }
            }
    }


    // MARK: - Helper Methods
    
    // MARK: - Truth Table Debug Helper
    
    static func printTruthTable(
        matchId: UUID,
        liveMatch: RemoteMatch?,
        currentUserId: UUID,
        authUserId: UUID?,
        challenger: User,
        receiver: User,
        adapter: RemoteGameStateAdapter?,
        overlayState: RemoteGameStateAdapter.OverlayState?,
        context: String
    ) {
        print("🧩 [TurnDebug \(context)] ========================================")
        print("🧩 [TurnDebug] match=\(matchId.uuidString.prefix(8))... status=\(liveMatch?.status?.rawValue ?? "nil") currentPlayer=\(liveMatch?.currentPlayerId?.uuidString.prefix(8) ?? "nil")...")
        print("🧩 [TurnDebug] currentUser(param)=\(currentUserId.uuidString.prefix(8))... currentUser(auth)=\(authUserId?.uuidString.prefix(8) ?? "nil")...")
        print("🧩 [TurnDebug] challenger=\(challenger.id.uuidString.prefix(8))... receiver=\(receiver.id.uuidString.prefix(8))...")
        
        let amIChallenger = (currentUserId == challenger.id)
        let amIReceiver = (currentUserId == receiver.id)
        let isMyTurn = (liveMatch?.currentPlayerId == currentUserId)
        
        print("🧩 [TurnDebug] amIChallenger=\(amIChallenger) amIReceiver=\(amIReceiver) isMyTurn=\(isMyTurn)")
        
        if let adapter = adapter {
            let me = (currentUserId == adapter.challenger.id) ? adapter.challenger : adapter.receiver
            print("🧩 [TurnDebug] adapter.me.id=\(me.id.uuidString.prefix(8))... adapter.opponent.id=\(adapter.opponent.id.uuidString.prefix(8))...")
            print("🧩 [TurnDebug] adapter.myRole=\(adapter.myRole.displayName)")
        } else {
            print("🧩 [TurnDebug] adapter=nil")
        }
        
        print("🧩 [TurnDebug] overlayState=\(overlayState?.description ?? "nil")")
        print("🧩 [TurnDebug] ========================================")
        
        // VALIDATION CHECKS
        if currentUserId != authUserId {
            print("⚠️ [TurnDebug] WARNING: currentUserId != authUserId - WRONG USER ID PASSED!")
        }
        if !amIChallenger && !amIReceiver {
            print("⚠️ [TurnDebug] WARNING: Not challenger AND not receiver - WRONG USER ID!")
        }
    }
    
    var body: some View {
        ZStack {
            backgroundLayer
            gameplayRootView
        }
        .onChange(of: liveMatch?.currentPlayerId) { oldValue, newValue in
            print("🔄 [TurnDebug] currentPlayerId CHANGED: \(oldValue?.uuidString.prefix(8) ?? "nil")... → \(newValue?.uuidString.prefix(8) ?? "nil")...")
            
            // Re-print truth table on change
            if let currentAdapter = adapter {
                Self.printTruthTable(
                    matchId: matchId,
                    liveMatch: liveMatch,
                    currentUserId: currentUserId,
                    authUserId: authService.currentUser?.id,
                    challenger: challenger,
                    receiver: receiver,
                    adapter: currentAdapter,
                    overlayState: currentAdapter.overlayState(isSaving: gameViewModel.isSaving, isRevealing: gameViewModel.isRevealingScore),
                    context: "onChange"
                )
            }
        }
        .onChange(of: serverLastVisitPayload) { oldValue, newValue in
            if let payload = newValue {
                let isBust = payload.scoreBefore == payload.scoreAfter
                print("📦 [LastVisit] Received UPDATE - playerId: \(payload.playerId.uuidString.prefix(8))..., darts: \(payload.darts), scoreBefore: \(payload.scoreBefore), scoreAfter: \(payload.scoreAfter), isBust: \(isBust), currentPlayerId: \(renderMatch?.currentPlayerId?.uuidString.prefix(8) ?? "nil")..., isMyTurn: \(isMyTurn)")
            } else {
                print("📦 [LastVisit] Cleared (nil)")
            }
        }
    }
}

// MARK: - Voice UI Components (Task 12)

extension RemoteGameplayView {
    /// Voice control button - top-left toolbar
    private var voiceControlButton: some View {
        Button {
            // Task 12: Toggle mute
            Task {
                await voiceChatService.toggleMute()
            }
        } label: {
            Group {
                switch voiceChatService.connectionState {
                case .idle, .connecting:
                    // Show microphone icon but disabled appearance
                    Image(systemName: "microphone")
                        .foregroundColor(AppColor.textSecondary)
                        .opacity(0.5)
                    
                case .connected:
                    // Show mute state
                    if voiceChatService.muteState == .muted {
                        Image(systemName: "microphone.slash")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    } else {
                        Image(systemName: "microphone")
                            .foregroundColor(AppColor.interactiveSecondaryBackground)
                    }
                    
                case .failed, .disconnected, .ended:
                    // Show unavailable state
                    Image(systemName: "microphone.slash")
                        .foregroundColor(AppColor.textSecondary)
                        .opacity(0.5)
                }
            }
            .font(.system(size: 20))
        }
        .disabled(voiceChatService.connectionState != VoiceSessionState.connected)
    }
}

// MARK: - Checkout Suggestion View

extension RemoteGameplayView {
    struct CheckoutSuggestionView: View {
        let checkout: String
        
        var body: some View {
            Text("Checkout: \(checkout)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColor.brandPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: checkout)
        }
    }
}

