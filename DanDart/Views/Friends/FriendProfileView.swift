//
//  FriendProfileView.swift
//  Dart Freak
//
//  Profile view for viewing friend details and head-to-head stats
//

import SwiftUI

struct FriendProfileView: View {
    let friend: Player
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @StateObject private var matchesService = MatchesService()
    
    @State private var showRemoveConfirmation: Bool = false
    @State private var headToHeadMatches: [MatchResult] = []
    @State private var isLoadingMatches: Bool = false
    
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
                    // Header with title and avatars
                    HStack {
                        Text("Head to head")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.justWhite)
                        
                        Spacer()
                        
                        if isLoadingMatches {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if !headToHeadMatches.isEmpty {
                            // Show avatars when matches exist
                            HStack(spacing: 8) {
                                AsyncAvatarImage(
                                    avatarURL: friend.avatarURL,
                                    size: 28,
                                    placeholderIcon: "person.circle.fill"
                                )
                                
                                AsyncAvatarImage(
                                    avatarURL: authService.currentUser?.avatarURL,
                                    size: 28,
                                    placeholderIcon: "person.circle.fill"
                                )
                            }
                        }
                    }
                    .padding(.trailing, 16)
                    
                    if headToHeadMatches.isEmpty && !isLoadingMatches {
                        // Empty State
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(AppColor.textSecondary)
                            
                            Text("No matches yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColor.textPrimary)
                            
                            Text("Challenge \(friend.displayName) to start your rivalry!")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(AppColor.inputBackground)
                        .cornerRadius(12)
                    } else if !headToHeadMatches.isEmpty {
                        // Game-specific stats using existing StatCategorySection component
                        HeadToHeadStatsView(
                            matches: headToHeadMatches,
                            currentUserAvatar: authService.currentUser?.avatarURL,
                            friendAvatar: friend.avatarURL,
                            currentUserId: authService.currentUser?.id ?? UUID(),
                            friendId: friend.userId ?? friend.id
                        )
                    }
                }
                
                // Remove Friend Link at Bottom
                Button(action: {
                    showRemoveConfirmation = true
                }) {
                    Text("Remove Friend")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
        }
        .background(AppColor.backgroundPrimary)
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
            let friendId = friend.userId ?? friend.id
            
            // Check if we have cached data for this friend
            if let cachedMatches = HeadToHeadCache.shared.getMatches(for: friendId) {
                headToHeadMatches = cachedMatches
                isLoadingMatches = false
                return
            }
            
            // No cache or cache expired - load fresh data
            loadHeadToHeadMatches()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MatchCompleted"))) { _ in
            let friendId = friend.userId ?? friend.id
            HeadToHeadCache.shared.invalidate(for: friendId)
            loadHeadToHeadMatches()
        }
        .refreshable {
            // Manual pull-to-refresh - invalidate cache first
            let friendId = friend.userId ?? friend.id
            HeadToHeadCache.shared.invalidate(for: friendId)
            await loadHeadToHeadMatchesAsync()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load head-to-head matches from Supabase only (async version for refreshable)
    private func loadHeadToHeadMatchesAsync() async {
        isLoadingMatches = true
        
        guard let userId = authService.currentUser?.id else {
            await MainActor.run {
                isLoadingMatches = false
                headToHeadMatches = []
            }
            return
        }
        
        let friendUserId = friend.userId ?? friend.id
        
        do {
            let supabaseMatches = try await matchesService.loadMatches(userId: userId)
            
            let filteredMatches = supabaseMatches.filter { match in
                let connectedPlayerIds = match.players.filter { !$0.isGuest }.map { $0.id }
                return connectedPlayerIds.contains(friendUserId) && connectedPlayerIds.contains(userId)
            }
            
            await MainActor.run {
                headToHeadMatches = filteredMatches.sorted { $0.timestamp > $1.timestamp }
                isLoadingMatches = false
                
                let friendId = friend.userId ?? friend.id
                HeadToHeadCache.shared.setMatches(headToHeadMatches, for: friendId)
            }
            
        } catch {
            await MainActor.run {
                isLoadingMatches = false
            }
        }
    }
    
    /// Load head-to-head matches from Supabase only
    private func loadHeadToHeadMatches() {
        Task {
            await loadHeadToHeadMatchesAsync()
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


// MARK: - Preview

// MARK: - Head-to-Head Stats View

struct HeadToHeadStatsView: View {
    let matches: [MatchResult]
    let currentUserAvatar: String?
    let friendAvatar: String?
    let currentUserId: UUID
    let friendId: UUID
    
    // Calculate game-specific stats
    private var gameStats: [GameTypeStats] {
        let gameTypes = Set(matches.map { $0.gameName })
        
        return gameTypes.compactMap { gameName in
            let gameMatches = matches.filter { $0.gameName == gameName }
            
            // Count wins by checking if winner is current user or friend
            // Handle both local matches (winnerId = MatchPlayer.id) and Supabase matches (winnerId = user account ID)
            let currentUserWins = gameMatches.filter { match in
                // Check if winnerId matches current user's account ID
                if match.winnerId == currentUserId {
                    return true
                }
                // Also check if any connected player with current user's ID won
                if let winner = match.players.first(where: { $0.id == match.winnerId }),
                   !winner.isGuest,
                   winner.id == currentUserId {
                    return true
                }
                return false
            }.count
            
            let friendWins = gameMatches.filter { match in
                // Check if winnerId matches friend's account ID
                if match.winnerId == friendId {
                    return true
                }
                // Also check if any connected player with friend's ID won
                if let winner = match.players.first(where: { $0.id == match.winnerId }),
                   !winner.isGuest,
                   winner.id == friendId {
                    return true
                }
                return false
            }.count
            
            let totalMatches = gameMatches.count
            
            guard totalMatches > 0 else { return nil }
            
            return GameTypeStats(
                gameName: gameName,
                currentUserWins: currentUserWins,
                friendWins: friendWins,
                totalMatches: totalMatches
            )
        }.sorted { $0.gameName < $1.gameName }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(gameStats) { stat in
                // Scoreboard row for each game type
                HStack(spacing: 16) {
                    // Game name on left
                    Text(stat.gameName)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.justWhite)
                    
                    Spacer()
                    
                    // Score boxes on right
                    HStack(spacing: 8) {
                        // Friend's score (left box)
                        ScoreBox(score: stat.friendWins)
                        
                        // User's score (right box)
                        ScoreBox(score: stat.currentUserWins)
                    }
                }
                .padding(16)
                .background(AppColor.inputBackground)
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Score Box Component

struct ScoreBox: View {
    let score: Int
    
    var body: some View {
        Text("\(score)")
            .font(.system(.headline, design: .rounded))
            .fontWeight(.semibold)
            .foregroundColor(AppColor.justWhite)
            .frame(width: 28, height: 28)
            .background(Color.black)
            .cornerRadius(6)
    }
}

// MARK: - Game Type Stats Model

struct GameTypeStats: Identifiable {
    let id = UUID()
    let gameName: String
    let currentUserWins: Int
    let friendWins: Int
    let totalMatches: Int
}


// MARK: - Preview

#Preview("Single Game Type") {
    NavigationStack {
        FriendProfileView(friend: Player.mockConnected1)
            .environmentObject(AuthService.mockAuthenticated)
            .onAppear {
                // Mock single game type (301)
                let mockMatch = MatchResult(
                    id: UUID(),
                    gameType: "301",
                    gameName: "301",
                    players: [
                        MatchPlayer(
                            id: AuthService.mockAuthenticated.currentUser!.id,
                            displayName: "You",
                            nickname: "",
                            avatarURL: AuthService.mockAuthenticated.currentUser?.avatarURL,
                            isGuest: false,
                            finalScore: 0,
                            startingScore: 301,
                            totalDartsThrown: 45,
                            turns: [],
                            legsWon: 0
                        ),
                        MatchPlayer(
                            id: Player.mockConnected1.id,
                            displayName: Player.mockConnected1.displayName,
                            nickname: Player.mockConnected1.nickname,
                            avatarURL: Player.mockConnected1.avatarURL,
                            isGuest: false,
                            finalScore: 50,
                            startingScore: 301,
                            totalDartsThrown: 42,
                            turns: [],
                            legsWon: 0
                        )
                    ],
                    winnerId: AuthService.mockAuthenticated.currentUser!.id,
                    timestamp: Date(),
                    duration: 180,
                    matchFormat: 1,
                    totalLegsPlayed: 1,
                    metadata: [:]
                )
                MatchStorageManager.shared.saveMatch(mockMatch)
            }
    }
}

#Preview("Multiple Game Types") {
    NavigationStack {
        FriendProfileView(friend: Player.mockConnected1)
            .environmentObject(AuthService.mockAuthenticated)
            .onAppear {
                let currentUserId = AuthService.mockAuthenticated.currentUser!.id
                let friendId = Player.mockConnected1.id
                
                // Mock 301 match (friend wins)
                let match301 = MatchResult(
                    id: UUID(),
                    gameType: "301",
                    gameName: "301",
                    players: [
                        MatchPlayer(id: currentUserId, displayName: "You", nickname: "", avatarURL: nil, isGuest: false, finalScore: 50, startingScore: 301, totalDartsThrown: 45, turns: [], legsWon: 0),
                        MatchPlayer(id: friendId, displayName: "Friend", nickname: "", avatarURL: Player.mockConnected1.avatarURL, isGuest: false, finalScore: 0, startingScore: 301, totalDartsThrown: 42, turns: [], legsWon: 0)
                    ],
                    winnerId: friendId,
                    timestamp: Date(),
                    duration: 180,
                    matchFormat: 1,
                    totalLegsPlayed: 1,
                    metadata: [:]
                )
                
                // Mock 501 match (friend wins)
                let match501 = MatchResult(
                    id: UUID(),
                    gameType: "501",
                    gameName: "501",
                    players: [
                        MatchPlayer(id: currentUserId, displayName: "You", nickname: "", avatarURL: nil, isGuest: false, finalScore: 100, startingScore: 501, totalDartsThrown: 60, turns: [], legsWon: 0),
                        MatchPlayer(id: friendId, displayName: "Friend", nickname: "", avatarURL: Player.mockConnected1.avatarURL, isGuest: false, finalScore: 0, startingScore: 501, totalDartsThrown: 54, turns: [], legsWon: 0)
                    ],
                    winnerId: friendId,
                    timestamp: Date().addingTimeInterval(-3600),
                    duration: 240,
                    matchFormat: 1,
                    totalLegsPlayed: 1,
                    metadata: [:]
                )
                
                // Mock Sudden Death match (user wins)
                let matchSuddenDeath = MatchResult(
                    id: UUID(),
                    gameType: "Sudden Death",
                    gameName: "Sudden Death",
                    players: [
                        MatchPlayer(id: currentUserId, displayName: "You", nickname: "", avatarURL: nil, isGuest: false, finalScore: 0, startingScore: 0, totalDartsThrown: 15, turns: [], legsWon: 0),
                        MatchPlayer(id: friendId, displayName: "Friend", nickname: "", avatarURL: Player.mockConnected1.avatarURL, isGuest: false, finalScore: 0, startingScore: 0, totalDartsThrown: 15, turns: [], legsWon: 0)
                    ],
                    winnerId: currentUserId,
                    timestamp: Date().addingTimeInterval(-7200),
                    duration: 120,
                    matchFormat: 1,
                    totalLegsPlayed: 1,
                    metadata: [:]
                )
                
                MatchStorageManager.shared.saveMatch(match301)
                MatchStorageManager.shared.saveMatch(match501)
                MatchStorageManager.shared.saveMatch(matchSuddenDeath)
            }
    }
}
