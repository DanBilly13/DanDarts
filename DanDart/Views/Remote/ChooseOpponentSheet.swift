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
    
    private var recentOpponents: [User] {
        guard let currentUser = authService.currentUser else { return [] }
        
        let recentMatchPlayers = MatchHistoryService.shared.summaries
            .recentOpponents(excludingUserId: currentUser.id, limit: 6)
        
        return recentMatchPlayers.compactMap { matchPlayer in
            guard !matchPlayer.isGuest else { return nil }
            return friendUsers.first { $0.id == matchPlayer.id }
        }
    }
    
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
                    if !recentOpponents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Opponents")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColor.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)
                            
                            ForEach(recentOpponents, id: \.id) { friend in
                                Button {
                                    selectedOpponent = friend
                                    
                                    #if canImport(UIKit)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    #endif
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        dismiss()
                                    }
                                } label: {
                                    PlayerCard(player: friend.toPlayer())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Rectangle()
                            .fill(AppColor.textSecondary.opacity(0.2))
                            .frame(height: 1)
                            .padding(.vertical, 12)
                    }
                    
                    let recentIds = Set(recentOpponents.map { $0.id })
                    let otherFriends = friendUsers.filter { !recentIds.contains($0.id) }
                    
                    ForEach(otherFriends, id: \.id) { friend in
                        Button {
                            selectedOpponent = friend
                            
                            #if canImport(UIKit)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            #endif
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        } label: {
                            PlayerCard(player: friend.toPlayer())
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
