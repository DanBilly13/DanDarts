//
//  MatchHistoryView.swift
//  DanDart
//
//  Match history view with filters and list of past matches
//

import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var matchesService = MatchesService()
    
    @State private var selectedFilter: GameFilter = .all
    @State private var matches: [MatchResult] = []
    @State private var isRefreshing: Bool = false
    @State private var isLoadingFromSupabase: Bool = false
    @State private var loadError: String?
    
    // Filter options
    enum GameFilter: String, CaseIterable {
        case all = "All"
        case threeOhOne = "301"
        case fiveOhOne = "501"
        case halveIt = "Halve-It"
        case knockout = "Knockout"
        case suddenDeath = "Sudden Death"
        case cricket = "Cricket"
        case killer = "Killer"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    // Filtered matches based on selected filter
    var filteredMatches: [MatchResult] {
        if selectedFilter == .all {
            return matches
        } else {
            return matches.filter { $0.gameName == selectedFilter.rawValue }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sync status banner
                if isLoadingFromSupabase || isRefreshing {
                    syncStatusBanner
                }
                
                // Error banner
                if let error = loadError {
                    errorBanner(message: error)
                }
                
                filterButtonsView
                contentView
            }
            .padding(.horizontal, 16)
            .background(Color("BackgroundPrimary"))
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Test Data") {
                        MatchStorageManager.shared.seedTestMatches()
                        loadMatches()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("AccentPrimary"))
                }
            }
            .toolbarBackground(Color("BackgroundPrimary"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .background(Color("BackgroundPrimary")).ignoresSafeArea()
        .onAppear {
            loadMatches()
        }
    }
    
    // MARK: - Sub Views
    
    private var syncStatusBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(Color("AccentPrimary"))
            
            Text(isRefreshing ? "Syncing with cloud..." : "Loading from cloud...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color("InputBackground"))
        .cornerRadius(8)
        .padding(.bottom, 8)
    }
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color("TextSecondary"))
            
            Spacer()
            
            Button(action: {
                loadError = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("TextSecondary"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .padding(.bottom, 8)
    }
    
    private var filterButtonsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GameFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
        }
        .padding(.bottom, 16)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if filteredMatches.isEmpty {
            emptyStateView
        } else {
            matchListView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Color("TextSecondary"))
            
            VStack(spacing: 8) {
                Text("No matches yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color("TextPrimary"))
                
                Text(emptyStateMessage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary"))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private var emptyStateMessage: String {
        selectedFilter == .all ? "Play a game to see your match history" : "No \(selectedFilter.displayName) matches found"
    }
    
    private var matchListView: some View {
        List {
            ForEach(filteredMatches) { match in
                NavigationLink(destination: MatchDetailView(match: match)) {
                    matchRowView(match)
                }
                .listRowBackground(Color("BackgroundPrimary"))
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color("BackgroundPrimary"))
        .refreshable {
            await refreshMatches()
        }
    }
    
    private func matchRowView(_ match: MatchResult) -> some View {
        MatchCard(match: match)
    }
    
    // MARK: - Helper Methods
    
    /// Load matches from both Supabase and local storage, merge and deduplicate
    private func loadMatches() {
        // 1. Load local matches first (instant)
        let localMatches = MatchStorageManager.shared.loadMatches()
        matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        
        // 2. Load from Supabase in background
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ No current user, showing local matches only")
            return
        }
        
        isLoadingFromSupabase = true
        
        Task {
            do {
                // Load matches from Supabase
                let supabaseMatches = try await matchesService.loadMatches(userId: currentUserId)
                
                // Merge with local matches and remove duplicates
                let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
                
                // Update UI with merged matches
                matches = allMatches.sorted { $0.timestamp > $1.timestamp }
                
                isLoadingFromSupabase = false
                print("✅ Loaded \(supabaseMatches.count) from Supabase, \(localMatches.count) local, \(matches.count) total")
                
            } catch {
                isLoadingFromSupabase = false
                loadError = "Failed to load cloud matches"
                print("❌ Load matches error: \(error)")
                // Keep showing local matches on error
            }
        }
    }
    
    /// Merge local and Supabase matches, removing duplicates
    private func mergeMatches(local: [MatchResult], supabase: [MatchResult]) -> [MatchResult] {
        var matchesById: [UUID: MatchResult] = [:]
        
        // Add local matches first
        for match in local {
            matchesById[match.id] = match
        }
        
        // Add Supabase matches (will overwrite local if same ID)
        for match in supabase {
            matchesById[match.id] = match
        }
        
        return Array(matchesById.values)
    }
    
    /// Refresh matches from Supabase
    private func refreshMatches() async {
        isRefreshing = true
        
        guard let currentUserId = authService.currentUser?.id else {
            isRefreshing = false
            return
        }
        
        do {
            // Load from Supabase
            let supabaseMatches = try await matchesService.loadMatches(userId: currentUserId)
            
            // Load local matches
            let localMatches = MatchStorageManager.shared.loadMatches()
            
            // Merge and update
            let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
            matches = allMatches.sorted { $0.timestamp > $1.timestamp }
            
            print("✅ Refreshed: \(matches.count) total matches")
            
        } catch {
            print("❌ Refresh error: \(error)")
            loadError = "Failed to refresh matches"
        }
        
        isRefreshing = false
    }
}

// MARK: - Filter Button Component

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Color("BackgroundPrimary") : Color("TextPrimary"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color("AccentPrimary") : Color("InputBackground"))
                )
        }
    }
}

// MARK: - Preview

#Preview {
    MatchHistoryView()
        .environmentObject(AuthService.mockAuthenticated)
}

#Preview("With Matches") {
    MatchHistoryView()
        .environmentObject(AuthService.mockAuthenticated)
}
