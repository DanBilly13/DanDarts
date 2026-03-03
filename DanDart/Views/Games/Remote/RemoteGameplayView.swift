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
    
    // Game state managed by ViewModel
    @StateObject private var gameViewModel: RemoteGameViewModel
    @StateObject private var menuCoordinator = MenuCoordinator.shared
    @State private var showInstructions: Bool = false
    @State private var showRestartAlert: Bool = false
    @State private var showExitAlert: Bool = false
    @State private var showUndoConfirmation: Bool = false
    @State private var navigateToGameEnd: Bool = false
    @State private var showLegWinCelebration: Bool = false
    @State private var showGameTip: Bool = false
    @State private var currentTip: GameTip? = nil
    @State private var isScoreboardExpanded: Bool = false
    @State private var isSaving: Bool = false
    
    // Pre-turn reveal state (sequential dart reveal when opponent saves)
    @State private var preTurnRevealThrow: [ScoredThrow] = []
    @State private var fullOpponentDarts: [ScoredThrow] = [] // Store all darts for sequential reveal
    @State private var revealedDartCount: Int = 0 // 0-3 for sequential dart appearance
    @State private var showRevealTotal: Bool = false // Show total as 4th item
    @State private var preTurnRevealIsActive: Bool = false
    @State private var lastSeenVisitTimestamp: String? = nil
    @State private var showOpponentScoreAnimation: Bool = false // Opponent's score animation
    
    // Local score override (for showing current player's score update during animation)
    @State private var localScoreOverride: [UUID: Int]? = nil // Temporary override during animation
    
    // Turn transition gating (freeze UI rotation during reveal)
    @State private var turnTransitionLocked: Bool = false
    @State private var displayCurrentPlayerId: UUID? = nil
    @State private var revealTask: Task<Void, Never>? = nil
    
    // UI gate: holds lock overlay through reveal + rotation + padding
    @State private var turnUIGateActive: Bool = false
    
    // Timing constants for turn transition phases
    private let revealHoldNs: UInt64 = 1_700_000_000         // 1.7s reveal duration (extended for sequential animation)
    private let rotateAnimNs: UInt64 = 350_000_000           // 0.35s card rotation animation
    private let postRotatePaddingNs: UInt64 = 150_000_000    // 0.15s extra padding after rotation
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var router: Router
    @EnvironmentObject var remoteMatchService: RemoteMatchService
    
    // MARK: - Live Match Data
    
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
    
    /// Server match (flowMatch from RemoteMatchService)
    private var serverMatch: RemoteMatch? {
        remoteMatchService.flowMatch
    }
    
    /// Primary match data: prefer server, fallback to liveMatch
    private var renderMatch: RemoteMatch? {
        serverMatch ?? liveMatch
    }
    
    /// Server-authoritative scores from renderMatch
    private var serverScores: [UUID: Int]? {
        renderMatch?.playerScores
    }
    
    /// Scores for UI: prefer local override, then server, then VM
    private var renderScores: [UUID: Int] {
        localScoreOverride ?? serverScores ?? gameViewModel.playerScores
    }
    
    /// Server-authoritative current player ID
    private var serverCurrentPlayerId: UUID? {
        renderMatch?.currentPlayerId
    }
    
    /// Current player index for UI: derive from display player ID (frozen during reveal)
    private var renderCurrentPlayerIndex: Int {
        // Use displayCurrentPlayerId when transition is locked (during reveal)
        let effectivePlayerId = turnTransitionLocked ? displayCurrentPlayerId : serverCurrentPlayerId
        
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
        let serverTurnIndex = renderMatch?.turnIndexInLeg
        let roundNumber = serverTurnIndex != nil ? ((serverTurnIndex! / 2) + 1) : gameViewModel.currentVisit
        print("🧮 [Round] serverTurnIndex=\(serverTurnIndex?.description ?? "nil") renderRound=\(roundNumber)")
        return roundNumber
    }
    
    /// Check if it's my turn (server-authoritative with fallback)
    private var isMyTurn: Bool {
        (serverCurrentPlayerId ?? liveMatch?.currentPlayerId) == currentUserId
    }
    
    /// Input gate: only enable when it's my turn AND UI gate is OFF AND not saving
    private var isInputEnabled: Bool {
        isMyTurn && !turnUIGateActive && !gameViewModel.isSaving
    }
    
    /// CurrentThrowDisplay should show:
    /// - Opponent's darts sequentially during reveal window - PRIORITY
    /// - My input when it's my turn
    /// - Otherwise empty []
    private var renderThrowForCurrentThrowDisplay: [ScoredThrow] {
        if preTurnRevealIsActive {
            // Show only revealed darts (sequential reveal)
            return Array(fullOpponentDarts.prefix(revealedDartCount))
        }
        if isMyTurn { return gameViewModel.currentThrow }
        return []
    }
    
    /// Combined score animation state: current player OR opponent
    /// In remote matches, we animate either:
    /// - Current player's score when they save (gameViewModel.showScoreAnimation)
    /// - Opponent's score during reveal (showOpponentScoreAnimation)
    private var showAnyScoreAnimation: Bool {
        gameViewModel.showScoreAnimation || showOpponentScoreAnimation
    }
    
    // MARK: - Local Score Override Methods
    
    /// Set local score override for current player during animation
    private func setLocalScoreOverride(playerId: UUID, score: Int) {
        var override = serverScores ?? gameViewModel.playerScores
        override[playerId] = score
        localScoreOverride = override
        print("🎬 [LocalOverride] Set score for \(playerId.uuidString.prefix(8)): \(score)")
    }
    
    /// Clear local score override (server scores will take over)
    private func clearLocalScoreOverride() {
        localScoreOverride = nil
        print("🎬 [LocalOverride] Cleared")
    }
    
    // MARK: - Debug Helpers
    
    private func dbg(_ msg: String) {
        print("🧪 [RTGD] \(msg)")
    }
    
    private func dbgMatchSnapshot(_ label: String) {
        let m = renderMatch
        let id = m?.id.uuidString.prefix(8) ?? "nil"
        let cp = (serverCurrentPlayerId ?? liveMatch?.currentPlayerId)?.uuidString.prefix(8) ?? "nil"
        let lvp = m?.lastVisitPayload
        let lvpPid = lvp?.playerId.uuidString.prefix(8) ?? "nil"
        let lvpTs = lvp?.timestamp ?? "nil"
        let darts = lvp?.darts ?? []
        dbg("\(label) match=\(id) cp=\(cp) lvp.pid=\(lvpPid) ts=\(lvpTs) darts=\(darts) isMyTurn=\(isMyTurn) preReveal=\(preTurnRevealIsActive)")
    }
    
    // MARK: - Turn Gate Logic
    
    /// Centralized turn gate evaluation - triggers on either serverCurrentPlayerId or lastVisitPayload.timestamp changes
    @MainActor
    private func evaluateTurnGate(reason: String) {
        let serverCP = serverCurrentPlayerId
        let lvp = renderMatch?.lastVisitPayload

        // If locked, do NOT auto-sync display id here
        if turnTransitionLocked {
            print("🎯 [TurnGate] evaluate(\(reason)) skipped: locked")
            return
        }

        // If we don't have a payload yet, normal sync
        guard let lvp else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) no LVP → sync displayCP=\(serverCP?.uuidString.prefix(8) ?? "nil")")
            return
        }

        // Ignore own visit
        guard lvp.playerId != currentUserId else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) own LVP → sync displayCP")
            return
        }

        // Only gate when it becomes MY turn
        guard serverCP == currentUserId else {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) not my turn → sync displayCP")
            return
        }

        // Avoid re-triggering for same timestamp
        if lastSeenVisitTimestamp == lvp.timestamp {
            displayCurrentPlayerId = serverCP
            print("🎯 [TurnGate] evaluate(\(reason)) same ts → sync displayCP")
            return
        }

        // 🔥 GATED TRANSITION
        print("🎯 [TURN_GATE] TRIGGER(\(reason)): serverCP=\(serverCP?.uuidString.prefix(8) ?? "nil") lvp.pid=\(lvp.playerId.uuidString.prefix(8)) ts=\(lvp.timestamp)")
        lastSeenVisitTimestamp = lvp.timestamp

        // Cancel existing task and reset all gates for safety
        revealTask?.cancel()
        preTurnRevealIsActive = false
        turnTransitionLocked = false
        turnUIGateActive = false
        revealedDartCount = 0
        showRevealTotal = false
        showOpponentScoreAnimation = false
        
        // Set gates ON
        turnTransitionLocked = true
        turnUIGateActive = true
        print("🎯 [TURN_GATE] LOCK ON")
        print("🎯 [TurnGate] UI GATE ON (lock overlay held)")

        // Store full opponent darts for sequential reveal
        fullOpponentDarts = lvp.darts.map { ScoredThrow(baseValue: $0, scoreType: .single) }
        preTurnRevealIsActive = true
        print("🎯 [PreTurnReveal] START sequential reveal darts=\(lvp.darts) ts=\(lvp.timestamp)")

        // Sequential reveal with score animation
        revealTask = Task { @MainActor in
            do {
                // Dart 1 appears immediately with Throw sound
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 1
                print("🎯 [PreTurnReveal] Dart 1")
                
                // Dart 2 (0.25s later)
                try await Task.sleep(nanoseconds: 250_000_000)
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 2
                print("🎯 [PreTurnReveal] Dart 2")
                
                // Dart 3 (0.25s later)
                try await Task.sleep(nanoseconds: 250_000_000)
                SoundManager.shared.playCountdownThud()
                revealedDartCount = 3
                print("🎯 [PreTurnReveal] Dart 3")
                
                // Total appears (0.25s later, no sound)
                try await Task.sleep(nanoseconds: 250_000_000)
                showRevealTotal = true
                print("🎯 [PreTurnReveal] Total shown")
                
                // Opponent score animation (0.5s later, like hitting save button)
                try await Task.sleep(nanoseconds: 500_000_000)
                SoundManager.shared.playCountdownSaveScore()
                showOpponentScoreAnimation = true
                print("🎯 [PreTurnReveal] Opponent score animation START")
                
                // Clear opponent score animation (0.25s later)
                try await Task.sleep(nanoseconds: 250_000_000)
                showOpponentScoreAnimation = false
                print("🎯 [PreTurnReveal] Opponent score animation END")
                
                // Brief pause after score animation (0.35s)
                try await Task.sleep(nanoseconds: 350_000_000)
                print("🎯 [PreTurnReveal] Pause complete, ready for rotation")
                
                // Rotate card AFTER all animations complete
                print("🎯 [TurnGate] ROTATE (after reveal hold)")
                displayCurrentPlayerId = serverCurrentPlayerId
                
                // Phase B: Keep overlay locked during rotation animation
                try await Task.sleep(nanoseconds: rotateAnimNs + postRotatePaddingNs)
                
                // Now unlock + clear reveal
                print("🎯 [TurnGate] UNLOCK UI (after rotate)")
                preTurnRevealIsActive = false
                turnTransitionLocked = false
                turnUIGateActive = false
                revealedDartCount = 0
                showRevealTotal = false
                print("🎯 [TurnGate] displayCP=\(displayCurrentPlayerId?.uuidString.prefix(8) ?? "nil") unlocked")
            } catch {
                print("🎯 [TURN_GATE] cancelled")
                // Clean up on cancellation
                revealedDartCount = 0
                showRevealTotal = false
                showOpponentScoreAnimation = false
            }
        }
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
                if let checkout = gameViewModel.suggestedCheckout {
                    CheckoutSuggestionView(checkout: checkout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 0)
                }
            }
            .frame(height: 40, alignment: .center)
            .padding(.bottom, 8)

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
                    if gameViewModel.isWinningThrow {
                        Label("Save Score", systemImage: "trophy.fill")
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

                VStack(spacing: 12) {
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
            if let total = serverLastVisitTotal {
                return "Scored: \(total)"
            }
            return "Visit saved"
        }
    }

    private func bottomOverlaySubtitle(for overlayState: RemoteGameStateAdapter.OverlayState, adapter: RemoteGameStateAdapter) -> String? {
        switch overlayState {
        case .none:
            return nil
        case .inactiveLockout:
            if let total = serverLastVisitTotal {
                return "Last visit: \(total)"
            }
            return "Waiting for opponent"
        case .saving:
            return "Please wait"
        case .revealing:
            // No subtitle during reveal
            return nil
        }
    }
    
    init(matchId: UUID, challenger: User, receiver: User, currentUserId: UUID) {
        self.matchId = matchId
        self.challenger = challenger
        self.receiver = receiver
        self.currentUserId = currentUserId
        
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
            if turnUIGateActive {
                return .inactiveLockout
            }
            return baseOverlayState
        }()
        
        return gameplayContent(overlayState, using: m, adapter: adapter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
                    .onAppear {
                        dbg("onAppear")
                        dbgMatchSnapshot("APPEAR")
                        print("👁️ [RemoteGameplayView] onAppear - matchId: \(matchId.uuidString.prefix(8))...")
                        
                        // Initialize displayCurrentPlayerId to current server state
                        displayCurrentPlayerId = serverCurrentPlayerId
                        print("🎯 [TurnGate] Initialized displayCurrentPlayerId=\(displayCurrentPlayerId?.uuidString.prefix(8) ?? "nil")...")
                        
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
                        
                        // Listen for score updates during animation
                        NotificationCenter.default.addObserver(
                            forName: NSNotification.Name("RemoteMatchScoreUpdated"),
                            object: nil,
                            queue: .main
                        ) { notification in
                            if let playerId = notification.userInfo?["playerId"] as? UUID,
                               let score = notification.userInfo?["score"] as? Int {
                                setLocalScoreOverride(playerId: playerId, score: score)
                            }
                        }
                        
                        // Note: Override is now cleared when server scores update (onChange)
                        // instead of on a timer, preventing score revert
                        
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
                        
                        // Show game-specific tip if available and not seen before
                        if TipManager.shared.shouldShowTip(for: m.gameName) {
                            currentTip = TipManager.shared.getTip(for: m.gameName)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation { showGameTip = true }
                            }
                        }
                    }
                    .onDisappear {
                        print("👋 [RemoteGameplayView] onDisappear - exiting remote flow")
                        
                        // Cancel reveal timer
                        revealTask?.cancel()
                        
                        remoteMatchService.exitRemoteFlow()
                    }
                    .onChange(of: serverScores) { oldValue, newValue in
                        // Sync VM scores from server when they update
                        if let newScores = newValue {
                            print("🔄 [Sync] Server scores updated, syncing to VM: \(newScores)")
                            gameViewModel.playerScores = newScores
                            
                            // Clear local override when server scores arrive (prevents revert)
                            if localScoreOverride != nil {
                                print("🎬 [LocalOverride] Cleared by server update")
                                clearLocalScoreOverride()
                            }
                        }
                    }
                    .onChange(of: serverCurrentPlayerId) { oldValue, newValue in
                        // Sync VM current player index from server when it updates
                        if let newPlayerId = newValue, let currentAdapter = self.adapter {
                            if let newIndex = currentAdapter.playerIndex(for: newPlayerId) {
                                print("🔄 [Sync] Server currentPlayerId updated to \(newPlayerId.uuidString.prefix(8))..., syncing VM index to \(newIndex)")
                                gameViewModel.currentPlayerIndex = newIndex
                            }
                        }
                        
                        // Evaluate turn gate (dual-trigger system)
                        evaluateTurnGate(reason: "serverCP change")
                    }
                    .onChange(of: renderMatch?.lastVisitPayload?.timestamp) { oldValue, newValue in
                        print("🔄 [Sync] lastVisitPayload.timestamp changed: \(oldValue ?? "nil") → \(newValue ?? "nil")")
                        evaluateTurnGate(reason: "lvp.ts change")
                    }
                    .onChange(of: (serverCurrentPlayerId ?? liveMatch?.currentPlayerId)) { oldId, newId in
                        dbg("onChange(currentPlayerId) old=\(oldId?.uuidString.prefix(8) ?? "nil") new=\(newId?.uuidString.prefix(8) ?? "nil")")
                        dbgMatchSnapshot("CP_CHANGE")
                    }
                    .onChange(of: preTurnRevealIsActive) { old, new in
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
                Button("Leave Game", role: .destructive) { router.popToRoot() }
            } message: {
                Text("Are you sure you want to leave the game? Your progress will be lost.")
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
                if newValue != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToGameEnd = true
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
            .navigationDestination(isPresented: $navigateToGameEnd) {
                gameEndDestinationView
            }
    }

    private var gameEndDestinationView: some View {
        Group {
            if let winner = gameViewModel.winner, let m = liveMatch {
                let tempGame = Game(
                    title: m.gameName,
                    subtitle: "Remote Match",
                    players: "2 Players",
                    instructions: ""
                )
                GameEndView(
                    game: tempGame,
                    winner: winner,
                    players: gameViewModel.players,
                    onPlayAgain: {
                        // Reset game with same players
                        gameViewModel.restartGame()
                        navigateToGameEnd = false
                    },
                    onChangePlayers: {
                        // Navigate back to game setup
                        navigateToGameEnd = false
                        dismiss()
                    },
                    onBackToGames: {
                        // Navigate back to games list
                        router.popToRoot()
                    },
                    matchFormat: gameViewModel.isMultiLegMatch ? gameViewModel.matchFormat : nil,
                    legsWon: gameViewModel.isMultiLegMatch ? gameViewModel.legsWon : nil,
                    matchId: gameViewModel.matchId,
                    matchResult: gameViewModel.savedMatchResult
                )
            } else {
                EmptyView()
            }
        }
    }

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

