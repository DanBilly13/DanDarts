//
//  RemoteGameplayPlaceholderView.swift
//  DanDart
//
//  Placeholder view for remote gameplay (coming soon)
//

import SwiftUI

struct RemoteGameplayPlaceholderView: View {
    let match: RemoteMatch
    let opponent: User
    let currentUser: User
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var remoteMatchService: RemoteMatchService
    
    @State private var instanceId = UUID()
    @State private var didExit = false
    
    // Manual refresh state
    @State private var isRefreshing = false
    @State private var pollingTask: Task<Void, Never>?
    
    // Debug counter state (Phase 2 testing)
    #if DEBUG
    @State private var isBumping = false
    #endif
    
    // Polling disabled by default (can be enabled for debugging)
    #if DEBUG
    private let enablePolling = false
    #else
    private let enablePolling = false
    #endif
    
    private enum RefreshReason {
        case initial, manual, poll
        
        var logPrefix: String {
            switch self {
            case .initial: return "Initial refresh"
            case .manual: return "Manual refresh"
            case .poll: return "Poll tick"
            }
        }
    }
    
    // Use flowMatch for real-time updates, fallback to route parameter
    private var effectiveMatch: RemoteMatch {
        if remoteMatchService.isInRemoteFlow,
           remoteMatchService.flowMatchId == match.id,
           let fm = remoteMatchService.flowMatch {
            return fm
        }
        return match
    }
    
    private var currentMatch: RemoteMatch {
        effectiveMatch
    }
    
    private var debugCounter: Int {
        effectiveMatch.debugCounter ?? 0
    }
    
    private var matchStatus: RemoteMatchStatus {
        effectiveMatch.status ?? .cancelled
    }
    
    private var matchIdFull: String {
        currentMatch.id.uuidString
    }
    
    private var matchIdShort: String {
        String(matchIdFull.prefix(8)) + "…"
    }
    
    var body: some View {
        ZStack {
            AppColor.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                
                // Title
                VStack(spacing: 16) {
                    Text("Remote Gameplay")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("Coming Soon")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                }
                
                // Match details
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        PlayerAvatarView(
                            avatarURL: currentUser.avatarURL,
                            size: 60
                        )
                        
                        Text("VS")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                        
                        PlayerAvatarView(
                            avatarURL: opponent.avatarURL,
                            size: 60
                        )
                    }
                    
                    Text("\(match.gameType) • First to \(match.matchFormat)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                
                // Match Diagnostics
                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("Match Diagnostics")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Match")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                            Spacer()
                            Text(matchIdShort)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColor.textPrimary)
                        }
                        
                        HStack {
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColor.textSecondary)
                            Spacer()
                            Text(matchStatus.displayName)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                        }
                    }
                    
                    Button {
                        UIPasteboard.general.string = matchIdFull
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Match ID")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                }
                .padding(16)
                .background(AppColor.inputBackground)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                
                #if DEBUG
                // Debug Counter Card (Phase 2 Testing)
                VStack(spacing: 12) {
                    Text("Debug Counter (Phase 2 Test)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                    
                    let _ = print("🎯 [Gameplay] render debugCounter=\(debugCounter) flow=\(remoteMatchService.flowMatch?.debugCounter ?? -1) matchId=\(currentMatch.id.uuidString.prefix(8))...")
                    
                    Text("\(debugCounter)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    
                    Button {
                        Task {
                            await bumpDebugCounter()
                        }
                    } label: {
                        HStack {
                            if isBumping {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isBumping ? "Bumping..." : "Bump Debug Counter")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColor.interactivePrimaryBackground)
                        .cornerRadius(8)
                    }
                    .disabled(isBumping)
                    
                    Text("Write to DB • Requires manual refresh to see on other device")
                        .font(.system(size: 12))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(AppColor.inputBackground)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                #endif
                
                // Refresh button
                Button {
                    Task {
                        await refreshMatch(reason: .manual)
                    }
                } label: {
                    HStack {
                        Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise.circle.fill")
                        Text(isRefreshing ? "Refreshing..." : "Refresh Match")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                }
                .disabled(isRefreshing)
                .padding(.top, 16)
                #endif
                
                Spacer()
                
                // Back button
                AppButton(role: .primary, controlSize: .regular) {
                    // Pop back to remote tab
                    router.popToRoot()
                } label: {
                    Text("Back to Remote")
                }
                .frame(maxWidth: 280)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .onAppear {
            print("[Gameplay] onAppear - instance: \(instanceId.uuidString.prefix(8))... match: \(currentMatch.id.uuidString.prefix(8))...")
            remoteMatchService.enterRemoteFlow(matchId: currentMatch.id)
            validateAndExitIfNeeded()
            
            // Fetch fresh match state on appear
            Task {
                await refreshMatch(reason: .initial)
                
                if enablePolling {
                    startPolling()
                }
            }
        }
        .onDisappear {
            print("[Gameplay] onDisappear - instance: \(instanceId.uuidString.prefix(8))...")
            remoteMatchService.exitRemoteFlow()
            stopPolling()
        }
        .onChange(of: matchStatus) { _, _ in
            validateAndExitIfNeeded()
        }
    }
    
    // MARK: - Validation
    
    private func validateAndExitIfNeeded() {
        guard !didExit else {
            print("🚫 [Gameplay] Already exited, ignoring validation")
            return
        }
        
        // Check if match ID matches (currentMatch is now non-optional)
        guard currentMatch.id == match.id else {
            print("🚨 [Gameplay] Match ID mismatch - navigating back")
            print("🚨 [Gameplay] Expected ID: \(match.id)")
            print("🚨 [Gameplay] Current match: \(currentMatch.id.uuidString)")
            didExit = true
            router.popToRoot()
            return
        }
        
        // Check if match was cancelled or is not playable
        if currentMatch.status == .cancelled {
            print("🚨 [Gameplay] Match cancelled - navigating back")
            didExit = true
            router.popToRoot()
            return
        }
        
        // Check if status is playable
        guard currentMatch.status == .inProgress else {
            print("🚨 [Gameplay] Match status not playable - navigating back")
            print("🚨 [Gameplay] Status: \(currentMatch.status?.rawValue ?? "nil")")
            didExit = true
            router.popToRoot()
            return
        }
        
        print("✅ [Gameplay] Match validation passed - status: \(currentMatch.status?.rawValue ?? "nil")")
    }
    
    // MARK: - Manual Refresh
    
    private func refreshMatch(reason: RefreshReason) async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        print("🔄 [Gameplay] \(reason.logPrefix) - matchId: \(currentMatch.id.uuidString.prefix(8))...")
        
        do {
            _ = try await remoteMatchService.fetchMatch(matchId: currentMatch.id)
            print("✅ [Gameplay] Refresh complete")
        } catch {
            // NSURLErrorDomain -999 is normal cancellation, not a failure
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                print("🔄 [Gameplay] Refresh cancelled")
            } else {
                print("❌ [Gameplay] Refresh failed: \(error)")
            }
        }
    }
    
    private func startPolling() {
        pollingTask?.cancel()
        
        print("🔄 [Gameplay] Starting polling (3s interval)")
        
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                
                if !Task.isCancelled {
                    await refreshMatch(reason: .poll)
                }
            }
        }
    }
    
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    // MARK: - Debug Counter (Phase 2 Testing)
    
    #if DEBUG
    private func bumpDebugCounter() async {
        guard !isBumping else { return }
        
        isBumping = true
        defer { isBumping = false }
        
        print("🔧 [DEBUG] Bumping debug counter...")
        
        do {
            try await remoteMatchService.bumpDebugCounter(matchId: currentMatch.id)
            print("✅ [DEBUG] Counter bumped successfully")
            print("ℹ️ [DEBUG] Tap Refresh to see updated value")
            
            // DO NOT auto-fetch - require manual refresh for Phase 2 proof
            
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == -999 {
                print("🔄 [DEBUG] Bump cancelled")
            } else {
                print("❌ [DEBUG] Failed to bump counter: \(error)")
            }
        }
    }
    #endif
}

// MARK: - Preview

#Preview {
    RemoteGameplayPlaceholderView(
        match: RemoteMatch.mockReady,
        opponent: User.mockUsers[0],
        currentUser: User.mockUsers[1]
    )
    .environmentObject(Router.shared)
}
