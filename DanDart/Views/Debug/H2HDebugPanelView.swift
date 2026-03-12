//
//  H2HDebugPanelView.swift
//  DanDart
//
//  Debug panel for inspecting head-to-head match data
//

import SwiftUI

#if DEBUG

struct H2HDebugPanelView: View {
    let data: H2HDebugData
    let currentUserName: String
    let friendName: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                    
                    Text("H2H DEBUG (temporary)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColor.player1)
                    
                    Spacer()
                    
                    Text("\(data.allMatchDetails.count) matches")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(12)
                .background(AppColor.inputBackground)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Section 1: Player Stats
                    debugSection(title: "1. PLAYER STATS") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current User: \(currentUserName)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppColor.justWhite)
                            Text("  Total Wins: \(data.currentUserWins)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                            Text("  Total Losses: \(data.currentUserLosses)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                            
                            Text("Friend: \(friendName)")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(AppColor.justWhite)
                                .padding(.top, 4)
                            Text("  Total Wins: \(data.friendWins)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                            Text("  Total Losses: \(data.friendLosses)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }
                    
                    // Section 2: H2H Summary
                    debugSection(title: "2. H2H SUMMARY (APP DISPLAY)") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(currentUserName) Wins: \(data.displayedCurrentUserWins)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                            Text("\(friendName) Wins: \(data.displayedFriendWins)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                            Text("Total Matches: \(data.displayedTotalMatches)")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }
                    
                    // Section 3: Match Details
                    debugSection(title: "3. MATCH DETAILS") {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(data.allMatchDetails) { match in
                                    matchDetailCard(match)
                                }
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                    
                    // Section 4: Category Breakdown
                    debugSection(title: "4. CATEGORY BREAKDOWN") {
                        VStack(alignment: .leading, spacing: 12) {
                            categoryStatsView(
                                title: "301 (Local Only)",
                                stats: data.local301Only,
                                currentUserName: currentUserName,
                                friendName: friendName
                            )
                            
                            categoryStatsView(
                                title: "301 (Remote Only)",
                                stats: data.remote301Only,
                                currentUserName: currentUserName,
                                friendName: friendName
                            )
                            
                            categoryStatsView(
                                title: "301 (Combined)",
                                stats: data.combined301,
                                currentUserName: currentUserName,
                                friendName: friendName
                            )
                        }
                    }
                    
                    // Section 5: Excluded Matches
                    if !data.excludedMatches.isEmpty {
                        debugSection(title: "5. EXCLUDED MATCHES (\(data.excludedMatches.count))") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(data.excludedMatches) { excluded in
                                    excludedMatchCard(excluded)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func debugSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(AppColor.player4)
            
            content()
                .padding(12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
        }
    }
    
    private func matchDetailCard(_ match: MatchDebugDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Status indicator
            HStack(spacing: 8) {
                Image(systemName: match.includedInH2H ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(match.includedInH2H ? .green : .red)
                    .font(.system(size: 14))
                
                Text(match.includedInH2H ? "INCLUDED" : "EXCLUDED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(match.includedInH2H ? .green : .red)
                
                Spacer()
                
                Text(match.source.rawValue)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Match details
            Group {
                Text("ID: \(match.matchId.uuidString.prefix(8))...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
                
                Text("Created: \(match.formattedCreatedAt)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
                
                Text("Game: \(match.gameName)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
                
                if let mode = match.matchMode {
                    Text("Mode: \(mode)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                }
                
                if let status = match.remoteStatus {
                    Text("Status: \(status)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                }
                
                if let winnerId = match.winnerId {
                    Text("Winner: \(winnerId.uuidString.prefix(8))...")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                } else {
                    Text("Winner: NULL")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                }
                
                if let duration = match.duration {
                    Text("Duration: \(duration)s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppColor.textSecondary)
                } else {
                    Text("Duration: NULL")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                }
                
                Text("Participants: \(match.participantNames.joined(separator: ", "))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            // Exclusion reason
            if let reason = match.exclusionReason {
                Text("Reason: \(reason)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding(10)
        .background(AppColor.inputBackground)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(match.includedInH2H ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func categoryStatsView(
        title: String,
        stats: CategoryStats,
        currentUserName: String,
        friendName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColor.justWhite)
            
            Text("\(currentUserName): \(stats.currentUserWins) wins | \(friendName): \(stats.friendWins) wins | Total: \(stats.totalMatches)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColor.textSecondary)
            
            if !stats.matchIds.isEmpty {
                Text("Match IDs: \(stats.matchIds.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(4)
    }
    
    private func excludedMatchCard(_ excluded: ExcludedMatchDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("ID: \(excluded.matchId.uuidString.prefix(8))...")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(excluded.source.rawValue)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Text("Reason: \(excluded.reason)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.red)
            
            if let gameName = excluded.gameName {
                Text("Game: \(gameName)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
            }
            
            if let createdAt = excluded.createdAt {
                Text("Created: \(excluded.formattedCreatedAt)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppColor.textSecondary)
            }
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#endif
