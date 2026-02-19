//
//  PlayerChallengeCard.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-02-19.
//

import SwiftUI

enum RemoteMatchStatus {
    case pending
    case ready
    case expired
}

struct PlayerChallengeCard: View {
    
    let player: Player
    let state: RemoteMatchStatus
    
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
            PlayerChallengeCardFoot(state: state)
            
        }
        .frame(maxWidth: .infinity)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}


struct PlayerChallengeCardFoot: View {
    let state: RemoteMatchStatus
    
    var body: some View {
        Group {
            switch state {
                
            case .pending:
                HStack {
                    AppButton(role: .tertiaryOutline,
                              controlSize: .small,
                              compact: true) {
                    } label: {
                        Text("Decline")
                    }
                    
                    AppButton(role: .primary,
                              controlSize: .small,
                              compact: true) {
                    } label: {
                        Text("Accept")
                    }
                }
                
            case .ready:
                VStack (spacing: 16) {
                    
                    
                    AppButton(role: .primary,
                              controlSize: .small,
                              compact: true) {
                    } label: {
                        Text("Accept")
                    }
                    AppButton(role: .tertiaryOutline,
                              controlSize: .small,
                              compact: true) {
                    } label: {
                        Text("Decline")
                    }
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
        state: .ready
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
