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
    
    @State private var currentTime = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeRemaining: TimeInterval? {
        guard let expiresAt else { return nil }
        return max(0, expiresAt.timeIntervalSince(currentTime))
    }
    
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
                    Text("VS \(player.displayName)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)
                    Text("@\(player.nickname)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading) // 👈 keep content pinned left
                
                
                
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 0)
            PlayerChallengeCardFoot(
                state: state,
                isProcessing: isProcessing,
                timeRemaining: timeRemaining,
                onAccept: onAccept,
                onDecline: onDecline,
                onJoin: onJoin
            )
            
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .onReceive(timer) { time in
            currentTime = time
        }
    }
}


struct PlayerChallengeCardFoot: View {
    let state: RemoteMatchStatus
    let isProcessing: Bool
    let timeRemaining: TimeInterval?
    let onAccept: (() -> Void)?
    let onDecline: (() -> Void)?
    let onJoin: (() -> Void)?
    
    private var formattedTimeRemaining: String {
        guard let timeRemaining else { return "" }
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
                        onAccept?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Accept")
                        }
                    }
                    .disabled(isProcessing)
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
                    Text(formattedTimeRemaining.isEmpty ? "—" : formattedTimeRemaining)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColor.textPrimary)
                }
                
            case .ready:
                VStack (spacing: 16) {
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
                    
                    AppButton(role: .tertiaryOutline,
                              controlSize: .small,
                              compact: true) {
                        onDecline?()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Cancel")
                        }
                    }
                    .disabled(isProcessing)
                }
                
            case .lobby:
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(AppColor.interactivePrimaryBackground)
                        Text("Waiting for opponent...")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColor.textPrimary)
                    }
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
