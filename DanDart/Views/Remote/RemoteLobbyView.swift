//
//  RemoteLobbyView.swift
//  DanDart
//
//  Remote match lobby - waiting for opponent to join
//  Adapted from PreGameHypeView for remote matches
//

import SwiftUI

struct RemoteLobbyView: View {
    let matchId: UUID
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var remoteMatchService: RemoteMatchService
    @EnvironmentObject private var authService: AuthService
    
    private let instanceId = UUID()
    
    // Static set to track matches being started across ALL instances
    private static var matchesBeingStarted = Set<UUID>()
    private static let matchesLock = NSLock()
    
    @State private var currentTime = Date()
    @State private var showContent = false
    @State private var showMatchStarting = false
    @State private var isViewActive = false
    @State private var navigationTask: Task<Void, Never>?
    @State private var hasAttemptedInitialLoad = false
    
    // Computed from service's published state (DO NOT store in @State)
    private var matchWithPlayers: RemoteMatchWithPlayers? {
        if let active = remoteMatchService.activeMatch, active.match.id == matchId {
            return active
        }
        return remoteMatchService.readyMatches.first(where: { $0.match.id == matchId })
    }
    
    private var match: RemoteMatch? { matchWithPlayers?.match }
    private var opponent: User? { matchWithPlayers?.opponent }
    private var currentUser: User? { authService.currentUser }
    
    private var timeRemaining: TimeInterval {
        guard let expiresAt = match?.joinWindowExpiresAt else { return 0 }
        return max(0, expiresAt.timeIntervalSinceNow)
    }
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    // Get current match status from service
    private var currentMatch: RemoteMatch? {
        if let activeMatch = remoteMatchService.activeMatch, activeMatch.match.id == matchId {
            return activeMatch.match
        }
        return nil
    }
    
    private var matchStatus: RemoteMatchStatus {
        currentMatch?.status ?? match?.status ?? .lobby
    }
    
    private var isBothPlayersReady: Bool {
        matchStatus == .inProgress
    }
    
    private var formattedTime: String {
        let totalSeconds = max(0, Int(timeRemaining.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Group {
            if let match = match, let opponent = opponent, let currentUser = currentUser {
                lobbyContent(match: match, opponent: opponent, currentUser: currentUser)
            } else {
                loadingView
            }
        }
        .task {
            guard !hasAttemptedInitialLoad else { return }
            hasAttemptedInitialLoad = true
            
            if matchWithPlayers == nil, let userId = authService.currentUser?.id {
                try? await remoteMatchService.loadMatches(userId: userId)
            }
        }
    }
    
    private var loadingView: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            ProgressView("Loading match...")
                .foregroundColor(AppColor.textPrimary)
        }
    }
    
    @ViewBuilder
    private func lobbyContent(match matchParam: RemoteMatch, opponent opponentParam: User, currentUser currentUserParam: User) -> some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Game name at top
                VStack(spacing: 8) {
                    Text(matchParam.gameType.uppercased())
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
                        playerCard(currentUserParam, isCurrentUser: true)
                            .frame(maxWidth: .infinity)
                        
                        playerCard(opponentParam, isCurrentUser: false)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // VS in center
                    VStack(spacing: 8) {
                        Text("VS")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .offset(y: -40)
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
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColor.textPrimary)
                            
                            Text("The join window has closed")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                        }
                    } else if isBothPlayersReady {
                        // Both players ready - show "MATCH STARTING" with flashing animation
                        VStack(spacing: 16) {
                            Text("Players Ready")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColor.interactiveSecondaryBackground)
                            
                            Text("MATCH STARTING")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                                .tracking(2)
                                .opacity(showMatchStarting ? 1.0 : 0.4)
                        }
                    } else {
                        // Waiting for opponent
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(AppColor.interactivePrimaryBackground)
                                .scaleEffect(1.5)
                            
                            Text("Waiting for \(opponentParam.displayName) to join...")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.textPrimary)
                            
                            // Countdown timer
                            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                Text(formattedTime)
                                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                                    .foregroundColor(timeRemaining < 60 ? .red : AppColor.interactivePrimaryBackground)
                            }
                        }
                    }
                    
                    // Cancel button
                    AppButton(role: .tertiaryOutline, controlSize: .regular) {
                        print("🟠 [Lobby] Cancel button tapped - matchId: \(matchParam.id)")
                        
                        // CRITICAL: Capture status BEFORE any state changes
                        let currentStatus = matchStatus
                        print("🟠 [Lobby] Current status: \(currentStatus.rawValue)")
                        
                        // CRITICAL: Set cancellation flag FIRST (synchronous)
                        remoteMatchService.cancelledMatchIds.insert(matchParam.id)
                        
                        // Cancel any pending navigation
                        navigationTask?.cancel()
                        navigationTask = nil
                        
                        // Call appropriate cancel method based on status
                        Task {
                            do {
                                if currentStatus == .lobby || currentStatus == .inProgress {
                                    print("🟠 [Lobby] Calling abortMatch")
                                    try await remoteMatchService.abortMatch(matchId: matchParam.id)
                                } else {
                                    print("🟠 [Lobby] Calling cancelChallenge")
                                    try await remoteMatchService.cancelChallenge(matchId: matchParam.id)
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
                }
                .padding(.bottom, 60)
                .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            print("🧩 [Lobby] instance=\(instanceId) onAppear - match=\(matchId)")
            isViewActive = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            SoundManager.shared.playBoxingSound()
        }
        .onDisappear {
            print("🧩 [Lobby] instance=\(instanceId) onDisappear - match=\(matchId)")
            Self.matchesLock.lock()
            Self.matchesBeingStarted.remove(matchId)
            Self.matchesLock.unlock()
            isViewActive = false
            navigationTask?.cancel()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            currentTime = time
            
            // Check if match still exists in service
            let matchExists = remoteMatchService.activeMatch?.match.id == matchId ||
                             remoteMatchService.readyMatches.contains(where: { $0.match.id == matchId })
            
            // Check if match is being started (thread-safe)
            Self.matchesLock.lock()
            let isStarting = Self.matchesBeingStarted.contains(matchId)
            Self.matchesLock.unlock()
            
            if !matchExists && !isStarting {
                // Match was removed (cancelled or expired)
                print("🚨 Match no longer exists in service, navigating back")
                router.popToRoot()
            }
        }
        .onChange(of: matchStatus) { oldStatus, newStatus in
            print("🧩 [Lobby] instance=\(instanceId) match=\(matchId)")
            print("🔔 [Lobby] onChange fired - old: \(oldStatus.rawValue), new: \(newStatus.rawValue)")
            
            // Guard 0: Cheap dedupe - filter identical transitions
            guard oldStatus != newStatus else {
                print("🚫 [Lobby] Guard 0: Duplicate transition, ignoring")
                return
            }
            
            // Guard 1: Cancelled match
            guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
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
            let alreadyStarting = Self.matchesBeingStarted.contains(matchId)
            if !alreadyStarting {
                Self.matchesBeingStarted.insert(matchId)
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
        Self.matchesBeingStarted.remove(matchId)
        Self.matchesLock.unlock()
        navigationTask?.cancel()
        navigationTask = nil
    }
    
    private func abortAndNavigateBack() {
        remoteMatchService.cancelledMatchIds.insert(matchId)
        resetMatchStart()
        router.popToRoot()
    }
    
    // MARK: - Animation Sequence
    
    private func startMatchStartingSequence() {
        // Guard: Don't start if match cancelled
        guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
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
            do {
                // CRITICAL: Fetch fresh match status from database BEFORE scheduling delay
                print("🔍 [Lobby] Fetching authoritative match status before scheduling navigation...")
                guard let freshMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    print("🚫 [Lobby] Match not found")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                // Guard: Check authoritative status is inProgress
                guard freshMatch.status == .inProgress else {
                    print("🚫 [Lobby] Status not inProgress: \(freshMatch.status?.rawValue ?? "nil")")
                    await MainActor.run {
                        abortAndNavigateBack()
                    }
                    return
                }
                
                print("✅ [Lobby] Authoritative check 1 passed")
                
                // Wait 3 seconds (cancellable)
                try await Task.sleep(nanoseconds: 3_000_000_000)
                
                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    print("🚫 [Lobby] Task cancelled during countdown")
                    await MainActor.run {
                        resetMatchStart()
                    }
                    return
                }
                
                // Check if match was cancelled (local set)
                guard !remoteMatchService.cancelledMatchIds.contains(matchId) else {
                    print("🚫 [Lobby] Match in cancelled set")
                    await MainActor.run {
                        resetMatchStart()
                    }
                    return
                }
                
                // SECOND authoritative check - verify status still inProgress
                print("🔍 [Lobby] Authoritative check 2: Re-fetching match...")
                guard let finalMatch = try await remoteMatchService.fetchMatch(matchId: matchId) else {
                    print("🚫 [Lobby] Match not found after countdown")
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
                
                // Guard against duplicate navigation from this lobby instance
                // Guard against duplicate navigation (global per match)
                guard RemoteNavigationLatch.shared.tryNavigateToGameplay(matchId: matchId) else {
                    print("🚫 [Lobby] Already navigated to gameplay for this match")
                    return
                }
                
                print("✅ [Lobby] Navigating to gameplay (first time for this match)")
                
                SoundManager.shared.playBoxingSound()
                
                router.push(.remoteGameplay(matchId: matchId))
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
                borderColor: isCurrentUser ? AppColor.interactiveSecondaryBackground : AppColor.interactivePrimaryBackground
            )
            
            Spacer()
                .frame(height: 8)
            
            // Name and nickname
            VStack(spacing: 0) {
                Text(user.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                
                Text("@\(user.nickname)")
                    .font(.footnote)
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
}

// MARK: - Preview

#Preview {
    RemoteLobbyView(matchId: RemoteMatch.mockReady.id)
        .environmentObject(Router.shared)
        .environmentObject(RemoteMatchService())
        .environmentObject(AuthService.shared)
}
