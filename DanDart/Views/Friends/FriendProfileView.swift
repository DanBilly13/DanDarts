//
//  FriendProfileView.swift
//  DanDart
//
//  Profile view for viewing friend details and head-to-head stats
//

import SwiftUI

struct FriendProfileView: View {
    let friend: Player
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirmation: Bool = false
    @State private var headToHeadMatches: [MatchResult] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header (Reusable Component)
                ProfileHeaderView(player: friend)
                    .padding(.top, 24)
                
                // Action Button
                AppButton(role: .primary, controlSize: .regular) {
                    // TODO: Navigate to game selection with friend pre-selected
                } label: {
                    Label("Challenge to Game", systemImage: "gamecontroller.fill")
                }
                
                // Head-to-Head Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Head-to-Head")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Color("TextPrimary"))
                        
                        Spacer()
                        
                        if !headToHeadMatches.isEmpty {
                            Text("\(headToHeadMatches.count) matches")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    
                    if headToHeadMatches.isEmpty {
                        // Empty State
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(Color("TextSecondary"))
                            
                            Text("No matches yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("TextPrimary"))
                            
                            Text("Challenge \(friend.displayName) to start your rivalry!")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color("TextSecondary"))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color("InputBackground"))
                        .cornerRadius(12)
                    } else {
                        // Match History List
                        VStack(spacing: 12) {
                            ForEach(headToHeadMatches) { match in
                                // TODO: MatchCard component (Task 62)
                                Text("Match: \(match.gameName)")
                                    .padding()
                                    .background(Color("InputBackground"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Remove Friend Link at Bottom
                Button(action: {
                    showRemoveConfirmation = true
                }) {
                    Text("Remove Friend")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color("TextSecondary"))
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
        }
        .background(Color("BackgroundPrimary"))
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Remove Friend?", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                removeFriend()
            }
        } message: {
            Text("Are you sure you want to remove \(friend.displayName) from your friends?")
        }
        .onAppear {
            loadHeadToHeadMatches()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load head-to-head matches from storage
    private func loadHeadToHeadMatches() {
        let allMatches = MatchStorageManager.shared.loadMatches()
        
        // Filter matches that include this friend
        headToHeadMatches = allMatches.filter { match in
            match.players.contains(where: { $0.id == friend.id })
        }
    }
    
    /// Remove friend and dismiss view
    private func removeFriend() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Remove from storage
        FriendsStorageManager.shared.removeFriend(withId: friend.id)
        
        // Dismiss view
        dismiss()
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Color("AccentPrimary"))
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color("TextPrimary"))
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color("InputBackground"))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FriendProfileView(friend: Player.mockConnected1)
    }
}

#Preview("Guest Player") {
    NavigationStack {
        FriendProfileView(friend: Player.mockGuest1)
    }
}
