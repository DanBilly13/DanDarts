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
    
    private var currentMatch: RemoteMatch? {
        remoteMatchService.activeMatch?.match
    }
    
    private var matchStatus: RemoteMatchStatus {
        currentMatch?.status ?? .cancelled
    }
    
    private var matchIdFull: String {
        match.id.uuidString
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
            print("[Gameplay] onAppear - instance: \(instanceId.uuidString.prefix(8))... match: \(match.id.uuidString.prefix(8))...")
            validateAndExitIfNeeded()
        }
        .onDisappear {
            print("[Gameplay] onDisappear - instance: \(instanceId.uuidString.prefix(8))...")
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
        
        // Check if match exists and ID matches
        guard let activeMatch = currentMatch,
              activeMatch.id == match.id else {
            print("🚨 [Gameplay] Match not found or ID mismatch - navigating back")
            print("🚨 [Gameplay] Expected ID: \(match.id)")
            print("🚨 [Gameplay] Current match: \(currentMatch?.id.uuidString ?? "nil")")
            didExit = true
            router.popToRoot()
            return
        }
        
        // Check if match was cancelled or is not playable
        if activeMatch.status == .cancelled {
            print("🚨 [Gameplay] Match cancelled - navigating back")
            didExit = true
            router.popToRoot()
            return
        }
        
        // Check if status is playable
        guard activeMatch.status == .inProgress else {
            print("🚨 [Gameplay] Match status not playable - navigating back")
            print("🚨 [Gameplay] Status: \(activeMatch.status?.rawValue ?? "nil")")
            didExit = true
            router.popToRoot()
            return
        }
        
        print("✅ [Gameplay] Match validation passed - status: \(activeMatch.status?.rawValue ?? "nil")")
    }
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
