//
//  MatchHistoryView.swift
//  Dart Freak
//
//  Match history view with filters and list of past matches
//

import SwiftUI

struct MatchHistoryView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var historyService = MatchHistoryService.shared
    private let analytics = AnalyticsService.shared
    
    @State private var selectedFilter: GameFilter = .all
    @State private var searchText: String = ""
    @State private var filteredMatches: [MatchResult] = []
    @State private var isSearchPresented: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // TEMPORARY: Toggle to hide local matches for testing
    @State private var showLocalMatches: Bool = true
    @State private var supabaseMatchIds: Set<UUID> = [] // Track which matches came from Supabase
    
    // Update status tracking
    @State private var updateStatusText: String = ""
    
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
        var filtered = historyService.matches
        
        // TEMPORARY: Filter out local matches if toggle is off
        if !showLocalMatches {
            // Hide matches that came from local storage (not from Supabase)
            let beforeCount = filtered.count
            filtered = filtered.filter { match in
                // Keep only matches that came from Supabase
                let isFromSupabase = supabaseMatchIds.contains(match.id)
                if !isFromSupabase {
                    print("  🔘 Hiding local match: \(match.id)")
                }
                return isFromSupabase
            }
            let afterCount = filtered.count
            print("🔘 Toggle OFF: \(beforeCount) → \(afterCount) matches (hid \(beforeCount - afterCount) local-only matches)")
        }
        
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
        navigationStackView
            .background(AppColor.backgroundPrimary)
            .ignoresSafeArea()
            .onAppear {
                // Check if data is stale and refresh if needed
                if historyService.isStale {
                    Task {
                        guard let userId = authService.currentUser?.id else { return }
                        await historyService.refreshMatches(userId: userId)
                    }
                }
                updateFilteredMatches()
                
                // Log match history viewed event
                analytics.logMatchHistoryViewed(totalMatches: historyService.matches.count)
            }
            .onChange(of: historyService.matches) { _, _ in
                updateFilteredMatches()
            }
            .onChange(of: historyService.lastLoadedTime) { _, _ in
                updateStatusText = formatUpdateStatus()
            }
    }
    
    private var navigationStackView: some View {
        NavigationStack {
            mainContentZStack
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColor.backgroundPrimary)
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarRole(.editor)
                .toolbar {
                    toolbarContent
                }
                .toolbar {
                    if #available(iOS 18.0, *) {
                        ToolbarItem(placement: .principal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("History")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColor.textPrimary)
                                if !updateStatusText.isEmpty {
                                    Text(updateStatusText)
                                        .font(.caption2)
                                        .foregroundColor(AppColor.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .onChange(of: searchText) { _, _ in
                    updateFilteredMatches()
                }
                .onChange(of: selectedFilter) { _, _ in
                    updateFilteredMatches()
                }
                .onChange(of: isSearchPresented) { _, _ in
                    updateFilteredMatches()
                }
                .onChange(of: showLocalMatches) { _, _ in
                    updateFilteredMatches()
                }
                .navigationDestination(for: MatchResult.self) { match in
                    MatchDetailView(match: match)
                }
        }
    }
    
    private var mainContentZStack: some View {
        ZStack {
            // Main content with filters scrolling together
            if !isSearchPresented {
                VStack(spacing: 0) {
                    // Error banner (pinned at top)
                    if let error = historyService.loadError {
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
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            ToolbarTitle(title: "History")
        }
        
        ToolbarItem(placement: .navigationBarLeading) {
            if !isSearchPresented {
                // TEMPORARY: Toggle for hiding local matches during testing
                Button(action: {
                    showLocalMatches.toggle()
                }) {
                    Image(systemName: showLocalMatches ? "iphone" : "iphone.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(showLocalMatches ? AppColor.interactivePrimaryBackground : AppColor.textSecondary)
                }
                .accessibilityLabel(showLocalMatches ? "Hide local matches" : "Show local matches")
            }
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
                historyService.loadError = nil
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
            .refreshable {
                guard let userId = authService.currentUser?.id else { return }
                await historyService.refreshMatches(userId: userId)
            }
        }
    }

    private func matchRowView(_ match: MatchResult) -> some View {
        MatchCard(match: match)
    }
    // Search overlay (Liquid Glass pattern)
    private var searchOverlay: some View {
        ZStack {
            // Dim background (covers everything including tab bar)
            AppColor.justBlack.opacity(0.4)
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
    
    /// Format update status text for subtitle
    private func formatUpdateStatus() -> String {
        if historyService.isLoading {
            return "Updating..."
        }
        
        guard let lastUpdate = historyService.lastLoadedTime else {
            return ""
        }
        
        let now = Date()
        let interval = now.timeIntervalSince(lastUpdate)
        
        if interval < 10 {
            return "Updated just now"
        } else if interval < 60 {
            return "Updated \(Int(interval))s ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "Updated \(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "Updated \(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "Updated \(days)d ago"
        }
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
