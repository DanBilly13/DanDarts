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
                            HStack(spacing: 12) {
                                PlayerAvatarView(avatarURL: friend.avatarURL, size: 44)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColor.textPrimary)
                                    
                                    Text("@\(friend.nickname)")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundColor(AppColor.textSecondary)
                                }
                                
                                Spacer()
                                
                                // Show checkmark if selected
                                if selectedOpponent?.id == friend.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColor.interactivePrimaryBackground)
                                }
                            }
                            .padding(12)
                            .background(AppColor.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
