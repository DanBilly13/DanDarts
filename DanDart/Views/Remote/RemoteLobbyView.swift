//
//  RemoteLobbyView.swift
//  DanDart
//
//  Remote match lobby - waiting for opponent to join
//  Adapted from PreGameHypeView for remote matches
//

import SwiftUI

struct RemoteLobbyView: View {
    let match: RemoteMatch
    let opponent: User
    let currentUser: User
    let onCancel: () -> Void
    let onUnfreeze: () -> Void  // Callback to unfreeze list snapshot
    @Binding var cancelledMatchIds: Set<UUID>
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var remoteMatchService: RemoteMatchService
    @EnvironmentObject private var voiceChatService: VoiceChatService
    
    // Preview mode detection - skip side effects in previews
    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    @State private var instanceId = UUID()
    
    // Static set to track matches being started across ALL instances
    private static var matchesBeingStarted = Set<UUID>()
    private static let matchesLock = NSLock()
    
    @State private var currentTime = Date()
    @State private var showContent = false
    @State private var showMatchStarting = false
    @State private var isViewActive = false
    @State private var navigationTask: Task<Void, Never>?
    
    // Manual refresh state
    @State private var isRefreshInProgress = false
    @State private var isTransitioningToGameplay = false
    @State private var lastRefreshTime: CFTimeInterval = 0
    private let minRefreshInterval: CFTimeInterval = 0.5  // 500ms minimum between refreshes
    
    // Duplicate start guard - prevents multiple start-match-if-ready calls
    @State private var hasRequestedMatchStart = false
    
    private var timeRemaining: TimeInterval {
        guard let expiresAt = match.joinWindowExpiresAt else { return 0 }
        return max(0, expiresAt.timeIntervalSinceNow)
    }
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    // Get current match status from flowMatch (fixes stuck lobby bug)
    private var matchStatus: RemoteMatchStatus {
        if remoteMatchService.flowMatchId == match.id, let status = remoteMatchService.flowMatch?.status {
            return status
        }
        return match.status ?? .lobby
    }
    
    private var isBothPlayersReady: Bool {
        matchStatus == .inProgress || (matchStatus == .lobby && bothPlayersPresent)
    }
    
    // Lobby presence computed properties
    private var bothPlayersPresent: Bool {
        if let flowMatch = remoteMatchService.flowMatch, flowMatch.id == match.id {
            return flowMatch.bothPlayersInLobby
        }
        return match.bothPlayersInLobby
    }
    
    private var countdownActive: Bool {
        if let flowMatch = remoteMatchService.flowMatch, flowMatch.id == match.id {
            return flowMatch.countdownStarted
        }
        return match.countdownStarted
    }
    
    private var countdownRemaining: TimeInterval {
        if let flowMatch = remoteMatchService.flowMatch, flowMatch.id == match.id {
            return flowMatch.countdownRemaining ?? 0
        }
        return match.countdownRemaining ?? 0
    }
    
    private var countdownElapsed: Bool {
        if let flowMatch = remoteMatchService.flowMatch, flowMatch.id == match.id {
            return flowMatch.countdownElapsed
        }
        return match.countdownElapsed
    }
    
    private var formattedTime: String {
        let totalSeconds = max(0, Int(timeRemaining.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedCountdown: String {
        let seconds = max(0, Int(countdownRemaining.rounded(.up)))
        return "\(seconds)"
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Game name at top
                VStack(spacing: 8) {
                    Text(match.gameType.uppercased())
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("MATCH STARTING")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                        .tracking(2)
                }
                .padding(.top, 60)
                .opacity(showContent ? 1.0 : 0.0)
                
                Spacer()
                
                // Players section
                ZStack {
                    HStack(spacing: 0) {
                        playerCard(currentUser, isCurrentUser: true)
                            .frame(maxWidth: .infinity)
                        
                        playerCard(opponent, isCurrentUser: false)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // VS in center
                    VStack(spacing: 8) {
                        Text("VS")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .offset(y: -32)
                }
                .padding(.horizontal, 16)
                .scaleEffect(showContent ? 1.0 : 0.8)
                .opacity(showContent ? 1.0 : 0.0)
                
                Spacer()
                
                // Waiting section - conditional based on match status
                VStack(spacing: 24) {
                    if isExpired {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.red)
                            
                            Text("Match Expired")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColor.textPrimary)
                            
                            Text("The join window has closed")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                        }
                    } else if isBothPlayersReady {
                        // Both players ready - show "MATCH STARTING" with flashing animation
                        VStack(spacing: 16) {
                            Text("Players Ready")
                                .font(.system(.callout, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColor.interactiveSecondaryBackground)
                            
                            // Task 10: Voice status line
                            voiceStatusLine
                            
                            Text("MATCH STARTING")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                                .tracking(2)
                                .opacity(showMatchStarting ? 1.0 : 0.4)
                            
                            // Countdown timer when in lobby
                            if matchStatus == .lobby && countdownActive {
                                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                                    let remaining = countdownRemaining
                                    let elapsed = remaining <= 0
                                    
                                    Text(formattedCountdown)
                                        .font(.system(.title, design: .monospaced))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColor.interactivePrimaryBackground)
                                        .onChange(of: elapsed) { _, isElapsed in
                                            if isElapsed && matchStatus == .lobby && bothPlayersPresent {
                                                Task {
                                                    do {
                                                        print("⏰ [Lobby] Countdown elapsed, calling start-match-if-ready")
                                                        try await remoteMatchService.startMatchIfReady(matchId: match.id)
                                                        print("✅ [Lobby] start-match-if-ready succeeded")
                                                    } catch {
                                                        print("❌ [Lobby] start-match-if-ready failed: \(error)")
                                                    }
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    } else {
                        // Waiting for opponent
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(AppColor.interactivePrimaryBackground)
                                .scaleEffect(1.5)
                            
                            Text("Waiting for \(opponent.displayName) to join")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColor.textPrimary)
                            
                            // Countdown timer
                            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                Text(formattedTime)
                                    .font(.system(.title, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(timeRemaining < 60 ? .red : AppColor.interactivePrimaryBackground)
                            }
                        }
                    }
                    
                    // Cancel/Abort button - only show for valid states
                    // Hide for terminal states (expired, cancelled, completed)
                    if matchStatus == .lobby || matchStatus == .inProgress {
                        AppButton(role: .tertiaryOutline, controlSize: .regular) {
                            print("🟠 [Lobby] Cancel button tapped - matchId: \(match.id)")
                            
                            // CRITICAL: Capture status BEFORE any state changes
                            let currentStatus = matchStatus
                            print("🟠 [Lobby] Current status: \(currentStatus.rawValue)")
                            
                            // CRITICAL: Set cancellation flag FIRST (synchronous)
                            cancelledMatchIds.insert(match.id)
                            
                            // Cancel any pending navigation
                            navigationTask?.cancel()
                            navigationTask = nil
                            
                            // Call appropriate cancel method based on status
                            Task {
                                do {
                                    if currentStatus == .lobby || currentStatus == .inProgress {
                                        print("🟠 [Lobby] Calling abortMatch")
                                        try await remoteMatchService.abortMatch(matchId: match.id)
                                    } else {
                                        print("🟠 [Lobby] Calling cancelChallenge")
                                        try await remoteMatchService.cancelChallenge(matchId: match.id)
                                    }
                                    
                                    print("✅ [Lobby] Cancel/abort successful")
                                    
                                    // Light haptic
                                    #if canImport(UIKit)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    #endif
                                    
                                    await MainActor.run {
                                        router.popToRoot()
                                    }
                                } catch {
                                    print("❌ [Lobby] Failed to cancel/abort match: \(error)")
                                    
                                    // Error haptic
                                    #if canImport(UIKit)
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                    #endif
                                    
                                    await MainActor.run {
                                        router.popToRoot() // Still navigate back on error
                                    }
                                }
                            }
                        } label: {
                            Text("Abort Game")
                        }
                        .frame(maxWidth: 280)
                    } else if matchStatus == .expired || matchStatus == .cancelled || matchStatus == .completed {
                        // For terminal states, show a close/dismiss button instead
                        AppButton(role: .tertiaryOutline, controlSize: .regular) {
                            print("🟠 [Lobby] Close button tapped for terminal state - matchId: \(match.id)")
                            router.popToRoot()
                        } label: {
                            Text("Close")
                        }
                        .frame(maxWidth: 280)
                    }
                }
                .padding(.bottom, 60)
                .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            // Phase 13: Voice controls moved to gameplay view
            // Voice status line remains visible in lobby body
            // ToolbarItem(placement: .topBarLeading) {
            //     voiceControlButton
            // }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await requestRefresh(reason: "manual_button")
                    }
                } label: {
                    if isRefreshInProgress {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppColor.interactivePrimaryBackground)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
                .disabled(isRefreshInProgress)
            }
        }
        .onAppear {
            print("🧩 [Lobby] instance=\(instanceId) onAppear - match=\(match.id.uuidString.prefix(8))")
            
            // Determine role
            let isChallenger = currentUser.id == match.challengerId
            let role = isChallenger ? "challenger" : "receiver"
            FlowDebug.log("LOBBY: onAppear role=\(role)", matchId: match.id)
            
            // TERMINAL STATE GUARD: Exit immediately if match is already terminal
            // This provides defense-in-depth even if revalidation gate is bypassed
            let status = match.status
            let statusStr = status?.rawValue ?? "nil"
            FlowDebug.log("LOBBY: TERMINAL_GUARD status=\(statusStr)", matchId: match.id)
            
            guard status == .lobby || status == .inProgress else {
                FlowDebug.log("LOBBY: TERMINAL_GUARD ABORT reason=terminalStatus_\(statusStr)", matchId: match.id)
                
                // Clean up any entry-flow state that might still be set
                remoteMatchService.clearAcceptPresentationFreeze(matchId: match.id)
                remoteMatchService.endEnterFlow(matchId: match.id)
                
                // Unfreeze list snapshot
                onUnfreeze()
                
                // Exit lobby immediately - do not run side effects
                router.popToRoot()
                return
            }
            
            FlowDebug.log("LOBBY: TERMINAL_GUARD OK - continuing with side effects", matchId: match.id)
            
            // CLEAR ACCEPT UI FREEZE - handoff complete
            remoteMatchService.clearAcceptPresentationFreeze(matchId: match.id)
            FlowDebug.log("ACCEPT_UI_FREEZE: CLEAR reason=lobbyOnAppear", matchId: match.id)
            
            // Skip side effects in preview mode
            guard !isPreview else {
                print("🎨 [Lobby] Preview mode - skipping side effects")
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showContent = true
                }
                return
            }
            
            remoteMatchService.enterRemoteFlow(matchId: match.id, initialMatch: match)
            
            // Clear ALL enter-flow state (latch, nav-in-flight, processing)
            remoteMatchService.endEnterFlow(matchId: match.id)
            
            // Unfreeze list snapshot in RemoteGamesTab
            onUnfreeze()
            
            isViewActive = true
            
            // CRITICAL: Confirm lobby view entered and fetch fresh match state
            Task {
                do {
                    FlowDebug.log("LOBBY: confirmLobbyViewEntered START", matchId: match.id)
                    try await remoteMatchService.confirmLobbyViewEntered(matchId: match.id)
                    FlowDebug.log("LOBBY: confirmLobbyViewEntered OK", matchId: match.id)
                    
                    // Immediately fetch fresh match to get updated countdown state
                    FlowDebug.log("LOBBY: requestRefresh START reason=post-confirm", matchId: match.id)
                    await requestRefresh(reason: "post-confirm")
                    FlowDebug.log("LOBBY: requestRefresh OK", matchId: match.id)
                    
                    // Log countdown state after confirmation
                    if let flowMatch = remoteMatchService.flowMatch, flowMatch.id == match.id {
                        let countdownStarted = flowMatch.countdownStarted
                        let remaining = flowMatch.countdownRemaining ?? 0
                        FlowDebug.log("LOBBY: countdown state countdownStarted=\(countdownStarted) remaining=\(String(format: "%.1f", remaining))s", matchId: match.id)
                    }
                    
                    // Snapshot after confirm
                    await MainActor.run {
                        remoteMatchService.dumpStateSnapshot(reason: "lobbyOnAppear_afterConfirm", matchId: match.id)
                    }
                } catch {
                    FlowDebug.log("LOBBY: confirmLobbyViewEntered ERROR \(error.localizedDescription)", matchId: match.id)
                }
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            
            // Task 13: Start voice session for this match
            Task {
                do {
                    try await voiceChatService.startSession(
                        matchId: match.id,
                        localUserId: currentUser.id,
                        challengerId: match.challengerId,
                        receiverId: match.receiverId
                    )
                    print("✅ [Lobby] Voice session started for match: \(match.id.uuidString.prefix(8))")
                } catch {
                    print("⚠️ [Lobby] Failed to start voice session: \(error)")
                    // Non-blocking: voice failure doesn't prevent match
                }
            }
        }
        .onDisappear {
            FlowDebug.log("LOBBY: onDisappear", matchId: match.id)
            
            // Skip side effects in preview mode
            guard !isPreview else {
                print("🎨 [Lobby] Preview mode - skipping onDisappear side effects")
                return
            }
            
            // Voice session persists across navigation to gameplay
            // It will be ended by flow-level teardown, not screen lifecycle
            
            // Exit remote flow to maintain correct depth tracking
            // This ensures loadMatches() runs when the entire stack is popped
            remoteMatchService.exitRemoteFlow()
            
            Self.matchesLock.lock()
            Self.matchesBeingStarted.remove(match.id)
            Self.matchesLock.unlock()
            isViewActive = false
            navigationTask?.cancel()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            currentTime = time
            
            // Check if match still exists in service (including flowMatch for in-flow state)
            let matchExists = remoteMatchService.activeMatch?.match.id == match.id ||
                             remoteMatchService.readyMatches.contains(where: { $0.match.id == match.id }) ||
                             remoteMatchService.flowMatch?.id == match.id
            
            // Check if match is being started (thread-safe)
            Self.matchesLock.lock()
            let isStarting = Self.matchesBeingStarted.contains(match.id)
            Self.matchesLock.unlock()
            
            if !matchExists && !isStarting {
                // Match was removed (cancelled or expired)
                let flowMatchExists = remoteMatchService.flowMatch?.id == match.id
                let flowMatchStatus = remoteMatchService.flowMatch?.status?.rawValue ?? "nil"
                FlowDebug.log("LOBBY_EXIT: TRIGGER reason=matchNotInService matchExists=\(matchExists) isStarting=\(isStarting) flowMatchExists=\(flowMatchExists) flowMatchStatus=\(flowMatchStatus)", matchId: match.id)
                remoteMatchService.dumpStateSnapshot(reason: "lobbyExit_matchNotInService", matchId: match.id)
                router.popToRoot()
            }
        }
        .onChange(of: countdownElapsed) { _, elapsed in
            guard elapsed, matchStatus == .lobby, bothPlayersPresent else { return }
            
            // Guard against duplicate calls
            guard !hasRequestedMatchStart else {
                print("⏰ [Lobby] Countdown elapsed but start already requested - skipping")
                return
            }
            
            hasRequestedMatchStart = true
            print("⏰ [Lobby] Countdown elapsed - requesting match start (first time)")
            
            Task {
                do {
                    try await remoteMatchService.startMatchIfReady(matchId: match.id)
                    print("✅ [Lobby] start-match-if-ready succeeded")
                } catch {
                    print("❌ [Lobby] start-match-if-ready failed: \(error)")
                    // Reset flag on error to allow retry
                    await MainActor.run {
                        hasRequestedMatchStart = false
                    }
                }
            }
        }
        .onChange(of: matchStatus) { oldStatus, newStatus in
            print("🧩 [Lobby] instance=\(instanceId) match=\(match.id)")
            print("🔔 [Lobby] onChange fired - old: \(oldStatus.rawValue), new: \(newStatus.rawValue)")
            
            // Guard 0: Cheap dedupe - filter identical transitions
            guard oldStatus != newStatus else {
                print("🚫 [Lobby] Guard 0: Duplicate transition, ignoring")
                return
            }
            
            // Guard 1: Cancelled match
            guard !cancelledMatchIds.contains(match.id) else {
                print("🚫 [Lobby] Guard 1: Match in cancelled set")
                return
            }
            
            // BRANCH 1: Handle cancelled status (mutually exclusive with start)
            if newStatus == .cancelled {
                print("🚨 [Lobby] Status is CANCELLED")
                abortAndNavigateBack()
                return
            }
            
            // BRANCH 2: Handle non-inProgress status (reset and exit)
            guard newStatus == .inProgress else {
                print("⚠️ [Lobby] Status not inProgress (\(newStatus.rawValue)), resetting")
                resetMatchStart()
                return
            }
            
            // BRANCH 3: Handle inProgress - ATOMIC latch across ALL instances
            Self.matchesLock.lock()
            let alreadyStarting = Self.matchesBeingStarted.contains(match.id)
            if !alreadyStarting {
                Self.matchesBeingStarted.insert(match.id)
            }
            Self.matchesLock.unlock()
            
            guard !alreadyStarting else {
                print("🚫 [Lobby] instance=\(instanceId) Match already being started by another instance, ignoring")
                return
            }
            
            print("🔒 [Lobby] instance=\(instanceId) Acquired GLOBAL latch, starting match sequence")
            
            // Cancel any existing task (defensive)
            navigationTask?.cancel()
            
            // Start sequence
            startMatchStartingSequence()
        }
        .background(AppColor.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Helper Methods
    
    private func resetMatchStart() {
        Self.matchesLock.lock()
        Self.matchesBeingStarted.remove(match.id)
        Self.matchesLock.unlock()
        navigationTask?.cancel()
        navigationTask = nil
    }
    
    private func abortAndNavigateBack() {
        cancelledMatchIds.insert(match.id)
        resetMatchStart()
        router.popToRoot()
    }
    
    // MARK: - Animation Sequence
    
    private func startMatchStartingSequence() {
        // Guard: Don't start if match cancelled
        guard !cancelledMatchIds.contains(match.id) else {
            print("🚫 [Lobby] Match cancelled before sequence start")
            resetMatchStart()
            return
        }
        
        // Start flashing animation immediately
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            showMatchStarting = true
        }
        
        // Create cancellable Task for navigation with authoritative checks
        navigationTask = Task { @MainActor in
            // Set transition gate to prevent competing refreshes
            isTransitioningToGameplay = true
            defer { isTransitioningToGameplay = false }
            
            do {
                // CRITICAL: Fetch fresh match status from database BEFORE scheduling delay
                print("🔍 [Lobby] Authoritative check 1...")
                await requestRefresh(reason: "authoritative_check_1")
                
                // Check flowMatch status (updated by requestRefresh)
                guard let flowMatch = remoteMatchService.flowMatch else {
                    print("🚫 [Lobby] flowMatch not available")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                // Guard: Check authoritative status is inProgress
                guard flowMatch.status == .inProgress else {
                    print("🚫 [Lobby] Status not inProgress: \(flowMatch.status?.rawValue ?? "nil")")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                print("✅ [Lobby] Authoritative check 1 passed")
                
                // Wait 1 second (cancellable)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    print("🚫 [Lobby] Task cancelled during countdown")
                    await MainActor.run {
                        resetMatchStart()
                    }
                    return
                }
                
                // Check if match was cancelled (local set)
                guard !cancelledMatchIds.contains(match.id) else {
                    print("🚫 [Lobby] Match in cancelled set")
                    await MainActor.run {
                        resetMatchStart()
                    }
                    return
                }
                
                // SECOND authoritative check - verify status still inProgress
                print("🔍 [Lobby] Authoritative check 2...")
                
                // Small delay to allow realtime update propagation
                try? await Task.sleep(nanoseconds: 150_000_000)  // 150ms
                
                await requestRefresh(reason: "authoritative_check_2")
                
                // Check flowMatch status again
                guard let finalMatch = remoteMatchService.flowMatch else {
                    print("🚫 [Lobby] flowMatch not available after check 2")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                guard finalMatch.status == .inProgress else {
                    print("🚫 [Lobby] Status changed after countdown: \(finalMatch.status?.rawValue ?? "nil")")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                // Final check: Not cancelled
                guard !Task.isCancelled else {
                    print("🚫 [Lobby] Task cancelled before navigation")
                    await MainActor.run {
                        resetMatchStart()
                    }
                    return
                }
                
                // All checks passed - navigate
                print("✅ [Lobby] All checks passed, navigating to gameplay")
                SoundManager.shared.playBoxingSound()
                
                // Determine challenger and receiver from match IDs
                let challenger = (finalMatch.challengerId == currentUser.id) ? currentUser : opponent
                let receiver = (finalMatch.receiverId == currentUser.id) ? currentUser : opponent
                
                router.push(.remoteGameplay(
                    matchId: finalMatch.id,
                    challenger: challenger,
                    receiver: receiver,
                    currentUserId: currentUser.id
                ))
            } catch is CancellationError {
                print("🚫 [Lobby] Task cancelled (CancellationError)")
                await MainActor.run {
                    resetMatchStart()
                }
            } catch {
                print("❌ [Lobby] Error in match sequence: \(error)")
                await MainActor.run {
                    resetMatchStart()
                }
            }
        }
    }
    
    // MARK: - Player Card
    
    private func playerCard(_ user: User, isCurrentUser: Bool) -> some View {
        VStack(spacing: 0) {
            // Avatar
            PlayerAvatarView(
                avatarURL: user.avatarURL,
                size: 96,
                /*borderColor: isCurrentUser ? AppColor.interactiveSecondaryBackground : AppColor.interactivePrimaryBackground*/
            )
            
            Spacer()
                .frame(height: 8)
            
            // Name and nickname
            VStack(spacing: 0) {
                Text(user.displayName)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("@\(user.nickname)")
                    .font(.system(. subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
                .frame(height: 2)
            
            // Stats
            HStack(spacing: 0) {
                Text("W\(user.totalWins)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.interactiveSecondaryBackground)
                Text("L\(user.totalLosses)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.interactivePrimaryBackground)
            }
        }
    }
    
    // MARK: - Voice UI Components (Task 10-11)
    
    /// Voice status line - shows underneath "Players Ready"
    private var voiceStatusLine: some View {
        Group {
            switch voiceChatService.connectionState {
            case .connecting:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(AppColor.textSecondary)
                    Text("Connecting voice...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                .opacity(0.7)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .connected:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                    Text("Voice ready")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.interactiveSecondaryBackground)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .failed, .disconnected:
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.textSecondary)
                    Text("Voice not available")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textSecondary)
                }
                .opacity(0.6)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                
            case .idle, .ended:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: voiceChatService.connectionState)
    }
    
    /// Voice control button - top-left toolbar
    private var voiceControlButton: some View {
        Button {
            // Task 11: Toggle mute
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
            .contentTransition(.symbolEffect(.replace))
        }
        .disabled(voiceChatService.connectionState != VoiceSessionState.connected)
        .animation(.easeInOut(duration: 0.2), value: voiceChatService.connectionState)
        .animation(.easeInOut(duration: 0.2), value: voiceChatService.muteState)
    }
    
    // MARK: - Centralized Refresh
    
    /// Single entry point for all refresh requests - prevents competing fetches
    private func requestRefresh(reason: String) async {
        // Gate 0: Skip network calls in preview mode
        guard !isPreview else {
            print("🎨 [Lobby] SKIP refresh (\(reason)) - preview mode")
            return
        }
        
        // Gate 1: Don't refresh if transitioning to gameplay
        guard !isTransitioningToGameplay else {
            print("⏭️ [Lobby] SKIP refresh (\(reason)) - transitioning to gameplay")
            return
        }
        
        // Gate 2: Don't refresh if already in progress
        guard !isRefreshInProgress else {
            print("⏭️ [Lobby] SKIP refresh (\(reason)) - already in progress")
            return
        }
        
        // Gate 3: Throttle - skip if called too soon after last refresh
        let now = CACurrentMediaTime()
        if (now - lastRefreshTime) < minRefreshInterval {
            print("⏭️ [Lobby] SKIP refresh (\(reason)) - throttled [\(String(format: "%.3f", now - lastRefreshTime))s ago]")
            return
        }
        
        lastRefreshTime = now
        isRefreshInProgress = true
        defer { isRefreshInProgress = false }
        
        print("🔄 [Lobby] requestRefresh(\(reason)) - matchId: \(match.id.uuidString.prefix(8))...")
        
        do {
            _ = try await remoteMatchService.fetchMatch(matchId: match.id)
            print("✅ [Lobby] Refresh complete (\(reason))")
        } catch {
            print("❌ [Lobby] Refresh failed (\(reason)): \(error)")
        }
    }
    
}

// MARK: - Preview

#Preview("Waiting for Opponent") {
    RemoteLobbyView(
        match: RemoteMatch.mockReady,
        opponent: User.mockUsers[0],
        currentUser: User.mockUsers[1],
        onCancel: {},
        onUnfreeze: {},
        cancelledMatchIds: .constant([])
    )
    .environmentObject(Router.shared)
    .environmentObject(RemoteMatchService())
    .environmentObject(VoiceChatService.shared)
}

#Preview("Both Players Ready - Countdown") {
    RemoteLobbyView(
        match: RemoteMatch.mockLobbyWithCountdown,
        opponent: User.mockUsers[0],
        currentUser: User.mockUsers[1],
        onCancel: {},
        onUnfreeze: {},
        cancelledMatchIds: .constant([])
    )
    .environmentObject(Router.shared)
    .environmentObject(RemoteMatchService())
    .environmentObject(VoiceChatService.shared)
}

#Preview("Match Starting") {
    RemoteLobbyView(
        match: RemoteMatch.mockInProgress,
        opponent: User.mockUsers[0],
        currentUser: User.mockUsers[1],
        onCancel: {},
        onUnfreeze: {},
        cancelledMatchIds: .constant([])
    )
    .environmentObject(Router.shared)
    .environmentObject(RemoteMatchService())
    .environmentObject(VoiceChatService.shared)
}
