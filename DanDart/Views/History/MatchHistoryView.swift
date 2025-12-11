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
    @State private var loadError: String?
    @State private var searchText: String = ""
    @State private var filteredMatches: [MatchResult] = []
    @State private var isSearchPresented: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // Cached date formatter (expensive to create)
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
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
    
    // Update filtered matches based on current state
    private func updateFilteredMatches() {
        var filtered = matches
        
        // Apply game type filter (only when not searching)
        if !isSearchPresented && selectedFilter != .all {
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
                
                // Search in date (use cached formatter)
                let dateString = dateFormatter.string(from: match.timestamp)
                if dateString.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                return false
            }
        }
        
        filteredMatches = filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content with filters scrolling together
                if !isSearchPresented {
                    VStack(spacing: 0) {
                        // Error banner (pinned at top)
                        if let error = loadError {
                            errorBanner(message: error)
                                .padding(.horizontal, 16)
                        }
                        
                        contentView
                    }
                    .opacity(isSearchPresented ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isSearchPresented)
                }
                
                // Search overlay (Liquid Glass pattern)
                if isSearchPresented {
                    searchOverlay
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ToolbarTitle(title: "History")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isSearchPresented {
                        ToolbarSearchButton {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSearchPresented = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                isSearchFieldFocused = true
                            }
                        }
                    }
                }
            }
            .onChange(of: searchText) { _, _ in
                updateFilteredMatches()
            }
            .onChange(of: selectedFilter) { _, _ in
                updateFilteredMatches()
            }
            .onChange(of: matches) { _, _ in
                updateFilteredMatches()
            }
            .onChange(of: isSearchPresented) { _, _ in
                updateFilteredMatches()
            }
            .navigationDestination(for: MatchResult.self) { match in
                MatchDetailView(match: match)
            }
        }
        .background(AppColor.backgroundPrimary).ignoresSafeArea()
        .onAppear {
            loadMatches()
            updateFilteredMatches()
        }
    }
    
    // MARK: - Sub Views
    
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
            VStack(spacing: 0) {
                filterButtonsView
                    .padding(.horizontal, 16)
                emptyStateView
            }
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
        .padding(.top, 100)
    }
    
    private var emptyStateMessage: String {
        selectedFilter == .all ? "Play a game to see your match history" : "No \(selectedFilter.displayName) matches found"
    }
    
    private var matchListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Filters at top of scroll view
                filterButtonsView
                    .padding(.horizontal, 16)
                
                // Match list
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
                .padding(.bottom, 6)
            }
            .padding(.top, 16)
        }
        .refreshable {
            await refreshMatches()
        }
    }
    
    private func matchRowView(_ match: MatchResult) -> some View {
        MatchCard(match: match)
    }
    
    // Search overlay (Liquid Glass pattern)
    private var searchOverlay: some View {
        ZStack {
            // Dim background (covers everything including tab bar)
            Color.black.opacity(0.4)
                .ignoresSafeArea(edges: .all)
                .onTapGesture {
                    stopSearch()
                }
            
            // Results area (full height, scrolls behind search bar)
            if searchText.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(AppColor.textSecondary)
                    
                    Text("Start typing to search")
                        .font(.headline)
                        .foregroundColor(AppColor.textPrimary)
                    
                    Spacer()
                }
            } else {
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
                } else {
                    // Results list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredMatches) { match in
                                NavigationLink(value: match) {
                                    matchRowView(match)
                                }
                                .buttonStyle(.plain)
                                .simultaneousGesture(TapGesture().onEnded {
                                    stopSearch()
                                })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
            
            // Search bar pinned to bottom (overlays results in outer ZStack)
            VStack {
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        
                        TextField("Search matches", text: $searchText)
                            .font(.system(size: 17))
                            .foregroundColor(AppColor.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.search)
                        
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
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    
                    Button(action: { stopSearch() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            )
                            .accessibilityLabel("Close search")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private func stopSearch() {
        isSearchFieldFocused = false
        withAnimation(.easeInOut(duration: 0.3)) {
            isSearchPresented = false
        }
        searchText = ""
    }
    
    // MARK: - Helper Methods

    /// Load matches from both Supabase and local storage, merge and deduplicate
    /// Runs silently in background - only shows errors
    private func loadMatches() {
        // 1. Load local matches first (instant, no loading indicator)
        let localMatches = MatchStorageManager.shared.loadMatches()
        matches = localMatches.sorted { $0.timestamp > $1.timestamp }
        
        // 2. Silently sync from Supabase in background
        guard let currentUserId = authService.currentUser?.id else {
            print("⚠️ No current user, showing local matches only")
            return
        }
        
        Task {
            do {
                // Load matches from Supabase (silent)
                let supabaseMatches = try await matchesService.loadMatches(userId: currentUserId)
                
                // Merge with local matches and remove duplicates
                let allMatches = mergeMatches(local: localMatches, supabase: supabaseMatches)
                
                // Update UI with merged matches (silent)
                await MainActor.run {
                    matches = allMatches.sorted { $0.timestamp > $1.timestamp }
                }
                
                print("✅ Silently synced: \(supabaseMatches.count) from cloud, \(localMatches.count) local, \(matches.count) total")
                
            } catch {
                // Only show error banner on failure
                await MainActor.run {
                    loadError = "Couldn't sync with cloud"
                }
                print("❌ Background sync error: \(error)")
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
