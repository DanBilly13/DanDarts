//
//  MatchCard.swift
//  DanDart
//
//  Match card component for displaying match history
//

import SwiftUI

struct MatchCard: View {
    let match: MatchResult
    
    var body: some View {
        HStack(spacing: 12) {
            // Game Type Badge
            gameBadge
            
            // Match Info
            VStack(alignment: .leading, spacing: 6) {
                // Players with scores
                playersRow
                
                // Date
                Text(relativeDate)
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary"))
            }
            
            Spacer()
        }
        .padding(12)
        .frame(minHeight: 100)
        .background(Color("InputBackground"))
        .cornerRadius(12)
    }
    
    // MARK: - Sub Views
    
    private var gameBadge: some View {
        VStack(spacing: 4) {
            Text(match.gameType)
                .font(.body.weight(.bold))
                .foregroundColor(Color("AccentPrimary"))
            
            Image(systemName: "target")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color("AccentPrimary"))
        }
        .frame(width: 60, height: 60)
        .background(Color("AccentPrimary").opacity(0.15))
        .cornerRadius(8)
    }
    
    private var playersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(match.players.prefix(2)) { player in
                HStack(spacing: 8) {
                    // Player name
                    Text(player.displayName)
                        .font(.subheadline.weight(player.id == match.winnerId ? .bold : .medium))
                        .foregroundColor(player.id == match.winnerId ? Color("AccentPrimary") : Color("TextPrimary"))
                    
                    // Winner indicator
                    if player.id == match.winnerId {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("AccentPrimary"))
                    }
                    
                    Spacer()
                    
                    // Score
                    Text("\(player.finalScore)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color("TextSecondary"))
                }
            }
            
            // Show "+X more" if more than 2 players
            if match.players.count > 2 {
                Text("+\(match.players.count - 2) more")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary"))
            }
        }
    }
    
    // MARK: - Computed Properties
    
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
                    finalScore: 127,
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
