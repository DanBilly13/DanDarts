//
//  MatchCard.swift
//  DanDart
//
//  Match card component for displaying match history
//

import SwiftUI
import UIKit

struct MatchCard: View {
    let match: MatchResult
    
    var body: some View {
        HStack(spacing: 16) {
            // Left side: game cover artwork (or gradient fallback)
            ZStack {
                Group {
                    if let imageName = resolvedCoverImageName {
                        Image(imageName)
                            .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(1.2)
                                .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                Color("AccentPrimary").opacity(0.6),
                                Color("AccentPrimary").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
            .background(Color("InputBackground").opacity(0.1))
            .frame(width: 52)
            .frame(maxHeight: .infinity, alignment: .center)
            .cornerRadius(0)
            
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
                    // Date
                    Text(relativeDate)
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary"))
                }
                .padding(.bottom, 4)
             
                
                // Players with scores
                playersRow
            }
            .padding(.vertical,16)
            .padding(.trailing,12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        .background(Color("InputBackground"))
        .cornerRadius(12)
        
        
    }
       
    
    // MARK: - Sub Views

    private var gameNameChip: some View {
        Chip(title: match.gameName)
    }
    
    private var playersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rankedPlayers) { player in
                HStack(spacing: 8) {
                    // Player name
                    Text(player.displayName)
                        .font(.system(.callout, design: .rounded))
                        .fontWeight(.semibold)
                        /*.font(.subheadline.weight(player.id == match.winnerId ? .bold : .medium))*/
                        .foregroundColor(Color("TextPrimary"))
                    
                    Spacer()
                    
                    // Score/Icon/Placement container
                    Group {
                        if isRankingBasedGame {
                            // Show placement for Sudden Death and Halve-It
                            placementView(for: playerPlacement(player))
                        } else {
                            // Show trophy for winner, score for others (301/501)
                            if player.id == match.winnerId {
                                Image(systemName: "crown")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("AccentTertiary"))
                            } else {
                                Text("\(player.finalScore)")
                                    .font(.system(.callout, design: .rounded))
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color("TextSecondary"))
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
            Image(systemName: "trophy.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("AccentTertiary"))
        } else {
            // Text-only for 2nd, 3rd, etc.
            Text("\(place)\(placementSuffix(place))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color("TextSecondary"))
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
    
    /// Check if this is a ranking-based game (Knockout, Sudden Death, Halve-It)
    private var isRankingBasedGame: Bool {
        let gameType = match.gameType.lowercased()
        return gameType == "knockout" ||
               gameType == "sudden death" || gameType == "sudden_death" ||
               gameType == "halve it" || gameType == "halve_it"
    }
    
    /// Players ranked by final score (highest to lowest for Halve-It/Knockout, lowest to highest for Sudden Death)
    private var rankedPlayers: [MatchPlayer] {
        let gameType = match.gameType.lowercased()
        
        if gameType == "knockout" {
            // For Knockout: higher lives = better placement
            return match.players.sorted { $0.finalScore > $1.finalScore }
        } else if gameType == "sudden death" || gameType == "sudden_death" {
            // For Sudden Death: higher lives = better placement
            return match.players.sorted { $0.finalScore > $1.finalScore }
        } else if gameType == "halve it" || gameType == "halve_it" {
            // For Halve-It: higher score = better placement
            return match.players.sorted { $0.finalScore > $1.finalScore }
        } else {
            // For other games: keep original order
            return match.players
        }
    }
    
    private var relativeDate: String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.day, .hour, .minute], from: match.timestamp, to: now)
        
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else {
            return "Just now"
        }
    }

    /// Resolve a cover image name for this match's game using common naming patterns
    private var resolvedCoverImageName: String? {
        let titleKey = match.gameName
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
    VStack(spacing: 16) {
        MatchCard(match: MatchResult.mock301)
        
        MatchCard(match: MatchResult(
            gameType: "501",
            gameName: "501",
            players: [
                MatchPlayer(
                    id: UUID(),
                    displayName: "Bob Smith",
                    nickname: "bobsmith",
                    avatarURL: "avatar2",
                    isGuest: false,
                    finalScore: 0,
                    startingScore: 501,
                    totalDartsThrown: 24,
                    turns: []
                ),
                MatchPlayer(
                    id: UUID(),
                    displayName: "Alice Jones",
                    nickname: "alicej",
                    avatarURL: "avatar3",
                    isGuest: false,
                    finalScore: 888,
                    startingScore: 501,
                    totalDartsThrown: 24,
                    turns: []
                )
            ],
            winnerId: UUID(),
            timestamp: Date().addingTimeInterval(-86400 * 2), // 2 days ago
            duration: 240
        ))
    }
    .padding()
    .background(Color("BackgroundPrimary"))
}
