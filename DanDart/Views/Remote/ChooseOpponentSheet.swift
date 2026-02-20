//
//  ChooseOpponentSheet.swift
//  Dart Freak
//
//  Simple sheet for selecting a single friend as opponent for remote matches
//

import SwiftUI

struct ChooseOpponentSheet: View {
    @Binding var selectedOpponent: User?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var friendsService: FriendsService
    @State private var friendUsers: [User] = []
    @State private var isLoadingFriends = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoadingFriends {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if friendUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 48))
                            .foregroundColor(AppColor.textSecondary)
                        
                        Text("No friends yet")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Add friends to challenge them to remote matches")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(friendUsers, id: \.id) { friend in
                        Button {
                            selectedOpponent = friend
                            
                            // Success haptic
                            #if canImport(UIKit)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            #endif
                            
                            // Dismiss after brief delay to show selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } label: {
                            PlayerCard(
                                player: Player(
                                    displayName: friend.displayName,
                                    nickname: friend.nickname,
                                    avatarURL: friend.avatarURL,
                                    isGuest: false,
                                    totalWins: friend.totalWins,
                                    totalLosses: friend.totalLosses,
                                    userId: friend.id
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .background(AppColor.surfacePrimary)
        .task {
            await loadFriends()
        }
    }
    
    private func loadFriends() async {
        guard let currentUser = authService.currentUser else { return }
        guard friendUsers.isEmpty else { return }
        
        isLoadingFriends = true
        do {
            friendUsers = try await friendsService.loadFriends(userId: currentUser.id)
        } catch {
            print("❌ Error loading friends: \(error)")
        }
        isLoadingFriends = false
    }
}
