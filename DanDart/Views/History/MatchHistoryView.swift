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
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // Filter options
    enum GameFilter: String, CaseIterable {
        case all = "All"
        case threeOhOne = "301"
        case fiveOhOne = "501"
        case halveIt = "Halve It"
        case knockout = "Knockout"
        case suddenDeath = "Sudden Death"
        case cricket = "Cricket"
        case killer = "Killer"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    // Filtered matches based on selected filter and search text
    var filteredMatches: [MatchResult] {
        var filtered = matches
        
        // Apply game type filter
        if selectedFilter != .all {
            filtered = filtered.filter { $0.gameName == selectedFilter.rawValue }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { match in
                // Search in game name
                if match.gameName.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search in player names
                if match.players.contains(where: { $0.displayName.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }
                
                // Search in date (formatted)
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                let dateString = dateFormatter.string(from: match.timestamp)
                if dateString.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                return false
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                VStack(spacing: 0) {
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
                    }
                    .padding(.horizontal, 16)
                    
                    contentView
                }
                .background(AppColor.backgroundPrimary)
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.editor)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        ToolbarTitle(title: "History")
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ToolbarSearchButton {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSearching = true
                            }
                        }
                    }
                }
                .toolbar(isSearching ? .hidden : .visible, for: .navigationBar)
                .customNavBar(title: "History")
                .blur(radius: isSearching ? 3 : 0)
                .opacity(isSearching ? 0 : 1.0)
                .allowsHitTesting(!isSearching)
                
                // Search mode overlay
                if isSearching {
                    searchOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(AppColor.backgroundPrimary).ignoresSafeArea()
        .onAppear {
            loadMatches()
        }
    }
    
    // MARK: - Sub Views
    
    private var syncStatusBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(AppColor.interactivePrimaryBackground)
            
            Text(isRefreshing ? "Syncing with cloud..." : "Loading from cloud...")
                .font(.caption.weight(.medium))
                .foregroundColor(AppColor.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColor.inputBackground)
        .cornerRadius(8)
        .padding(.bottom, 8)
    }
    
    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColor.textSecondary)
            
            Spacer()
            
            Button(action: {
                loadError = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColor.textSecondary)
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
            .padding(.horizontal, 1)
            .padding(.trailing, 16)
        }
        .scrollClipDisabled()
        .padding(.top, 12)
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
                .foregroundColor(AppColor.textSecondary)
            
            VStack(spacing: 8) {
                Text("No matches yet")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColor.textPrimary)
                
                Text(emptyStateMessage)
                    .font(.body.weight(.medium))
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateMessage: String {
        selectedFilter == .all ? "Play a game to see your match history" : "No \(selectedFilter.displayName) matches found"
    }
    
    private var matchListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMatches) { match in
                    NavigationLink(value: match) {
                        matchRowView(match)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .navigationDestination(for: MatchResult.self) { match in
            MatchDetailView(match: match)
        }
    }
    
    private func matchRowView(_ match: MatchResult) -> some View {
        MatchCard(match: match)
    }
    
    // MARK: - Search Overlay
    
    private var searchOverlay: some View {
        VStack(spacing: 0) {
            // Search results area (takes remaining space)
            if !searchText.isEmpty {
                if filteredMatches.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(AppColor.textSecondary)
                        
                        Text("No matches found")
                            .font(.headline)
                            .foregroundColor(AppColor.textPrimary)
                        
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundColor(AppColor.textSecondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Results list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredMatches.prefix(5)) { match in
                                Button(action: {
                                    // Navigate to match detail
                                }) {
                                    matchRowView(match)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                }
            } else {
                // Empty state - fill space
                Spacer()
            }
            
            // Search bar with close button (pinned to bottom, above keyboard)
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                    
                    TextField("Search", text: $searchText)
                        .font(.system(size: 17))
                        .foregroundColor(AppColor.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFieldFocused)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColor.inputBackground)
                .cornerRadius(10)
                
                Button(action: {
                    isSearchFieldFocused = false
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSearching = false
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColor.backgroundPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            // Auto-focus search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFieldFocused = true
            }
        }
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
                .font(.subheadline.weight(.semibold))
                .foregroundColor(isSelected ? AppColor.backgroundPrimary : AppColor.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColor.interactivePrimaryBackground : AppColor.inputBackground)
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
