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
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var remoteMatchService: RemoteMatchService
    
    @State private var currentTime = Date()
    @State private var showContent = false
    @State private var showMatchStarting = false
    @State private var hasNavigated = false
    
    private var timeRemaining: TimeInterval {
        guard let expiresAt = match.joinWindowExpiresAt else { return 0 }
        return max(0, expiresAt.timeIntervalSinceNow)
    }
    
    private var isExpired: Bool {
        timeRemaining <= 0
    }
    
    // Get current match status from service
    private var currentMatch: RemoteMatch? {
        if let activeMatch = remoteMatchService.activeMatch, activeMatch.match.id == match.id {
            return activeMatch.match
        }
        return nil
    }
    
    private var matchStatus: RemoteMatchStatus {
        currentMatch?.status ?? match.status ?? .lobby
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
                            
                            Text("Waiting for \(opponent.displayName) to join...")
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
                        onCancel()
                    } label: {
                        Text("Cancel Match")
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
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
            SoundManager.shared.playBoxingSound()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            currentTime = time
            
            // Check if match still exists in service
            let matchExists = remoteMatchService.activeMatch?.match.id == match.id ||
                             remoteMatchService.readyMatches.contains(where: { $0.match.id == match.id })
            
            if !matchExists && !hasNavigated {
                // Match was removed (cancelled or expired)
                print("🚨 Match no longer exists in service, navigating back")
                dismiss()
                router.popToRoot()
            }
        }
        .onChange(of: matchStatus) { oldStatus, newStatus in
            // Navigate to gameplay when both players ready
            if newStatus == .inProgress && !hasNavigated {
                hasNavigated = true
                startMatchStartingSequence()
            }
            
            // Navigate back if match cancelled
            if newStatus == .cancelled {
                print("🚨 Match cancelled, navigating back to Remote tab")
                dismiss()
                router.popToRoot()
            }
        }
        .background(AppColor.backgroundPrimary)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Animation Sequence
    
    private func startMatchStartingSequence() {
        // Start flashing animation immediately
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            showMatchStarting = true
        }
        
        // Navigate to gameplay after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Play sound before navigation
            SoundManager.shared.playBoxingSound()
            
            // Navigate to placeholder gameplay
            router.push(.remoteGameplay(
                match: currentMatch ?? match,
                opponent: opponent,
                currentUser: currentUser
            ))
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
    RemoteLobbyView(
        match: RemoteMatch.mockReady,
        opponent: User.mockUsers[0],
        currentUser: User.mockUsers[1],
        onCancel: {}
    )
}
