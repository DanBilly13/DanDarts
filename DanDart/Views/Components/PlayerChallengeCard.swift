//
//  PlayerChallengeCard.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-02-19.
//
//  Challenge card component for remote matches
//  Uses RemoteMatchStatus from RemoteMatch.swift

import SwiftUI

struct PlayerChallengeCard: View {
    
    let player: Player
    let state: RemoteMatchStatus
    let isProcessing: Bool
    let expiresAt: Date?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    let onJoin: (() -> Void)?
    
    init(
        player: Player,
        state: RemoteMatchStatus,
        isProcessing: Bool = false,
        expiresAt: Date? = nil,
        onAccept: (() -> Void)? = nil,
        onDecline: (() -> Void)? = nil,
        onJoin: (() -> Void)? = nil
    ) {
        self.player = player
        self.state = state
        self.isProcessing = isProcessing
        self.expiresAt = expiresAt
        self.onAccept = onAccept
        self.onDecline = onDecline
        self.onJoin = onJoin
    }
    
    var body: some View {
        VStack (alignment: .leading, spacing:0 ){
            HStack(alignment: .center, spacing: 16){
                PlayerAvatarView(
                    avatarURL: player.avatarURL,
                    size: 44
                )
                .padding(.leading, 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text("301 First to 3")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.brandPrimary)
                    Text("VS \(player.displayName)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.justWhite)
                    Text("@\(player.nickname)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.justWhite)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 👈 keep content pinned left
                
                
                
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 0)
            PlayerChallengeCardFoot(
                player: player,
                state: state,
                isProcessing: isProcessing,
                expiresAt: expiresAt,
                onAccept: onAccept,
                onDecline: onDecline,
                onJoin: onJoin
            )
            
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}


struct PlayerChallengeCardFoot: View {
    let player: Player
    let state: RemoteMatchStatus
    let isProcessing: Bool
    let expiresAt: Date?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    let onJoin: (() -> Void)?
    
    private func formatTimeRemaining(from expiresAt: Date) -> String {
        let timeRemaining = max(0, expiresAt.timeIntervalSinceNow)
        let totalSeconds = max(0, Int(timeRemaining.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        Group {
            switch state {
                
            case .pending:
                HStack {
                    AppButton(role: .tertiaryOutline,
                              controlSize: .small,
                              compact: true) {
                        print("🟡 [DEBUG] Decline button tapped!")
                        print("🟡 [DEBUG] isProcessing: \(isProcessing)")
                        print("🟡 [DEBUG] onDecline closure exists: \(onDecline != nil)")
                        onDecline?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Decline")
                        }
                    }
                    .disabled(isProcessing)
                    
                    AppButton(role: .primary,
                              controlSize: .small,
                              compact: true) {
                        print("🟢 [DEBUG] Accept button tapped!")
                        print("🟢 [DEBUG] isProcessing: \(isProcessing)")
                        print("🟢 [DEBUG] onAccept closure exists: \(onAccept != nil)")
                        onAccept?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: 8) {
                                Text("Accept")
                                
                                if let expiresAt = expiresAt {
                                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                        Text(formatTimeRemaining(from: expiresAt))
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isProcessing)
                    .onAppear {
                        print("🟢 [DEBUG] Accept button appeared - isProcessing: \(isProcessing), onAccept exists: \(onAccept != nil)")
                    }
                }
                
            case .sent:
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundStyle(AppColor.textSecondary)
                    Text("Waiting for response")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    
                    if let expiresAt = expiresAt {
                        TimelineView(.periodic(from: .now, by: 1.0)) { context in
                            let timeString = formatTimeRemaining(from: expiresAt)
                            let _ = print("⏱️ TimelineView tick - expiresAt: \(expiresAt), now: \(context.date), timeRemaining: \(timeString)")
                            
                            Text(timeString)
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(AppColor.textPrimary)
                        }
                    } else {
                        Text("—")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                    }
                }
                
            case .ready:
                VStack (spacing: 16) {
                    HStack(spacing: 8) {
                        // Green dot indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Match ready - \(player.displayName) accepted")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                        
                        Spacer()
                    }
                    
                    AppButton(role: .primary,
                              controlSize: .small,
                              compact: true) {
                        onJoin?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack(spacing: 8) {
                                Text("Join now")
                                
                                if let expiresAt = expiresAt {
                                    TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                        Text(formatTimeRemaining(from: expiresAt))
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isProcessing)
                    
                    AppButton(role: .tertiaryOutline,
                              controlSize: .small,
                              compact: true) {
                        onDecline?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Cancel Match")
                        }
                    }
                    .disabled(isProcessing)
                }
                
            case .lobby:
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppColor.interactivePrimaryBackground)
                        Text("Opponent is ready!")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                        
                        Spacer()
                        
                        if let expiresAt = expiresAt {
                            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                                Text(formatTimeRemaining(from: expiresAt))
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppColor.interactivePrimaryBackground)
                            }
                        }
                    }
                    
                    AppButton(role: .primary,
                              controlSize: .small,
                              compact: true) {
                        onJoin?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join Match")
                        }
                    }
                    .disabled(isProcessing)
                }
                
            case .inProgress:
                AppButton(role: .primary,
                          controlSize: .small,
                          compact: true) {
                } label: {
                    Text("Resume Match")
                }
                
            case .completed:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Match completed")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textPrimary)
                }
                
            case .expired:
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Time out. Match expired")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.justWhite)
                    Spacer()
                    Text("00:00")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                
            case .cancelled:
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                    Text("Match cancelled")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.bottom, 16)
        .padding(.horizontal, 16)
    }
}


#Preview {
    PlayerChallengeCard(
        player: Player(
            displayName: "Alice Johnson",
            nickname: "alice",
            avatarURL: "avatar2",
            isGuest: false,
            totalWins: 15,
            totalLosses: 8
        ),
        state: .ready,
        expiresAt: Date().addingTimeInterval(300)
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
