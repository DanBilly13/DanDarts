//
//  MatchCard.swift
//  Dart Freak
//
//  Match card component for displaying match history
//

import SwiftUI
import UIKit

struct MatchCard: View {
    let summary: MatchSummary
    var isSyncedToCloud: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side: game cover artwork (or gradient fallback)
            ZStack {
                Group {
                    if let imageName = resolvedCoverImageName {
                        Image(imageName)
                            .resizable()
                                .aspectRatio(contentMode: .fill)
                                
                                .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                AppColor.brandPrimary.opacity(0.6),
                                AppColor.brandPrimary.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
            .background(AppColor.inputBackground.opacity(0.1))
            .frame(width: 88)
            .frame(height: 88, alignment: .center)
            .cornerRadius(8)
            
            .clipped()
            /*.overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color("AccentTertiary").opacity(0.5), lineWidth: 1)
            )*/
            
            
            
            // Match Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Game name chip
                    gameNameChip
                    
                    // Practice badge for single-player matches
                    if summary.isPractice {
                        Text("Practice")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColor.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColor.inputBackground.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    
                       
                    
                    // Date with cloud icon
                    HStack(spacing: 4) {
                        Text(relativeDate)
                            .font(.caption)
                            .foregroundColor(AppColor.textSecondary)
                        
                        if isSyncedToCloud {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColor.interactivePrimaryBackground.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, 6)
             
                
                // Players with scores
                playersRow
            }
          
            .padding(.trailing,4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical,16)
        .padding(.horizontal,16)
        .background(AppColor.inputBackground)
        .cornerRadius(16)
        
        
    }
       
    
    // MARK: - Sub Views

    private var gameNameChip: some View {
        Chip(title: summary.gameName)
    }
    
    private var playersRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rankedPlayers) { player in
                HStack(alignment: .center) {
                    // Player name
                    Text(player.displayName)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.regular)
                        /*.font(.subheadline.weight(player.id == match.winnerId ? .bold : .medium))*/
                        .foregroundColor(AppColor.textPrimary)
                    
                    Spacer()
                    
                    // Score/Icon/Placement container
                    Group {
                        if isRankingBasedGame {
                            // Show placement for Sudden Death and Halve-It
                            placementView(for: playerPlacement(player))
                        } else {
                            // Show trophy for winner, hide scores for X01 non-winners
                            if player.id == summary.winnerId {
                                Image(systemName: "crown")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppColor.interactivePrimaryBackground)
                            } else if isX01Game {
                                // X01 games: hide non-winner scores
                                EmptyView()
                            } else {
                                // Other games: show scores as before
                                Text("\(player.finalScore)")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.regular)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }
                    .frame(width: 36)
                }
            }
        }
    }
    
    /// Get placement number for a player in ranked games
    private func playerPlacement(_ player: MatchPlayer) -> Int {
        guard let index = rankedPlayers.firstIndex(where: { $0.id == player.id }) else {
            return rankedPlayers.count
        }
        return index + 1
    }
    
    @ViewBuilder
    private func placementView(for place: Int) -> some View {
        if place == 1 {
            // Trophy for 1st place (consistent with 301/501)
            Image(systemName: "crown")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        } else {
            // Text-only for 2nd, 3rd, etc.
            Text("\(place)\(placementSuffix(place))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)
        }
    }
    
    private func placementSuffix(_ place: Int) -> String {
        switch place {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    // MARK: - Computed Properties
    
    /// Check if this is a ranking-based game (Knockout, Sudden Death, Halve-It, Killer)
    private var isRankingBasedGame: Bool {
        let gameType = summary.gameType.lowercased()
        return gameType == "knockout" ||
               gameType == "sudden death" || gameType == "sudden_death" ||
               gameType == "halve it" || gameType == "halve_it" ||
               (gameType == "killer" && hasValidKillerPlacement)
    }
    
    // Check if Killer match has valid placement data (forward-only)
    private var hasValidKillerPlacement: Bool {
        guard summary.gameType.lowercased() == "killer" else { return false }
        guard let metadata = summary.metadata else { return false }
        
        // Check if metadata contains placement keys (indicates new format)
        return metadata.keys.contains { $0.hasPrefix("placement_") }
    }
    
    // Check if Knockout match has valid placement data
    private var hasValidKnockoutPlacement: Bool {
        guard summary.gameType.lowercased() == "knockout" else { return false }
        guard let metadata = summary.metadata else { return false }
        
        // Check if metadata contains placement keys (indicates new format)
        return metadata.keys.contains { $0.hasPrefix("placement_") }
    }
    
    // Check if Sudden Death match has valid placement data
    private var hasValidSuddenDeathPlacement: Bool {
        let gameType = summary.gameType.lowercased()
        guard gameType == "sudden death" || gameType == "sudden_death" else { return false }
        guard let metadata = summary.metadata else { return false }
        
        // Check if metadata contains placement keys (indicates new format)
        return metadata.keys.contains { $0.hasPrefix("placement_") }
    }

    // Extract placement from metadata for a specific player
    private func placementForPlayer(_ player: MatchPlayer) -> Int {
        guard let metadata = summary.metadata else { return 0 }
        let key = "placement_\(player.id.uuidString)"
        return Int(metadata[key] ?? "") ?? 0
    }
    
    /// Check if this is an X01 game (301, 501)
    private var isX01Game: Bool {
        let gameType = summary.gameType.lowercased()
        return gameType.contains("301") || gameType.contains("501")
    }
    
    /// Players ranked by final score (highest to lowest for Halve-It/Knockout, lowest to highest for Sudden Death)
    private var rankedPlayers: [MatchPlayer] {
        let gameType = summary.gameType.lowercased()
        
        if gameType == "knockout" {
            if hasValidKnockoutPlacement {
                // For Knockout with valid placement: sort by placement from metadata
                return summary.players.sorted { placementForPlayer($0) < placementForPlayer($1) }
            } else {
                // For old Knockout matches: fallback to sorting by lives (higher = better)
                return summary.players.sorted { $0.finalScore > $1.finalScore }
            }
        } else if gameType == "sudden death" || gameType == "sudden_death" {
            if hasValidSuddenDeathPlacement {
                // For Sudden Death with valid placement: sort by placement from metadata
                return summary.players.sorted { placementForPlayer($0) < placementForPlayer($1) }
            } else {
                // For old Sudden Death matches: fallback to sorting by lives (higher = better)
                return summary.players.sorted { $0.finalScore > $1.finalScore }
            }
        } else if gameType == "halve it" || gameType == "halve_it" {
            // For Halve-It: higher score = better placement
            return summary.players.sorted { $0.finalScore > $1.finalScore }
        } else if gameType == "killer" && hasValidKillerPlacement {
            // For Killer with valid placement: sort by placement from metadata
            return summary.players.sorted { placementForPlayer($0) < placementForPlayer($1) }
        } else {
            // For old Killer matches without placement data: keep original order
            return summary.players
        }
    }
    
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if under 1 minute
        if calendar.isDate(summary.timestamp, inSameDayAs: now) {
            let components = calendar.dateComponents([.hour, .minute], from: summary.timestamp, to: now)
            
            if let minutes = components.minute, minutes < 1 {
                return "Just now"
            } else if let hours = components.hour, hours > 0 {
                return "\(hours)h"
            } else if let minutes = components.minute, minutes > 0 {
                return "\(minutes)m"
            }
        }
        
        // Check if yesterday
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(summary.timestamp, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        
        // Older dates: numeric format
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: summary.timestamp)
    }

    /// Resolve a cover image name for this match's game using common naming patterns
    private var resolvedCoverImageName: String? {
        let titleKey = summary.gameName
        let candidates: [String] = [
            "game-cover/\(titleKey)",
            titleKey,
            titleKey.lowercased(),
            titleKey.lowercased().replacingOccurrences(of: " ", with: "-")
        ]
        
        for candidate in candidates {
            if UIImage(named: candidate) != nil {
                return candidate
            }
        }
        
        return nil
    }
}

// MARK: - Preview

#Preview {
    let winnerId = UUID()
    
    VStack(spacing: 16) {
        MatchCard(summary: MatchSummary(
            gameType: "301",
            gameName: "301",
            players: [
                MatchPlayer.forSummary(
                    id: winnerId,
                    displayName: "John Doe",
                    nickname: "johndoe",
                    avatarURL: "avatar1",
                    isGuest: false,
                    finalScore: 0,
                    legsWon: 1
                ),
                MatchPlayer.forSummary(
                    id: UUID(),
                    displayName: "Jane Smith",
                    nickname: "janesmith",
                    avatarURL: "avatar2",
                    isGuest: false,
                    finalScore: 150,
                    legsWon: 0
                )
            ],
            winnerId: winnerId,
            timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
            duration: 180
        ))
        
        MatchCard(summary: MatchSummary(
            gameType: "501",
            gameName: "501",
            players: [
                MatchPlayer.forSummary(
                    id: UUID(),
                    displayName: "Bob Smith",
                    nickname: "bobsmith",
                    avatarURL: "avatar2",
                    isGuest: false,
                    finalScore: 0,
                    legsWon: 1
                ),
                MatchPlayer.forSummary(
                    id: UUID(),
                    displayName: "Alice Jones",
                    nickname: "alicej",
                    avatarURL: "avatar3",
                    isGuest: false,
                    finalScore: 888,
                    legsWon: 0
                )
            ],
            winnerId: UUID(),
            timestamp: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            duration: 240
        ))
    }
    .padding()
    .background(AppColor.backgroundPrimary)
}
