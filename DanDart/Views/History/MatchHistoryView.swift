//
//  MatchHistoryView.swift
//  DanDart
//
//  Match history view with filters and list of past matches
//

import SwiftUI

struct MatchHistoryView: View {
    @State private var selectedFilter: GameFilter = .all
    @State private var matches: [MatchResult] = []
    @State private var isRefreshing: Bool = false
    
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
    
    /// Load matches from local storage and sort by date (most recent first)
    private func loadMatches() {
        matches = MatchStorageManager.shared.loadMatches()
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Refresh matches (placeholder for future cloud sync)
    private func refreshMatches() async {
        isRefreshing = true
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Reload from local storage
        loadMatches()
        
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
}

#Preview("With Matches") {
    let view = MatchHistoryView()
    return view
}
