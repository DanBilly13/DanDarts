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
