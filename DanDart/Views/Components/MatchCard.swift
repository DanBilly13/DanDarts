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
        HStack(spacing: 0) {
            // Left side: Placeholder for future game graphic
            VStack {
                Spacer()
            }
            .frame(width: 84)
            
            // Match Info
            VStack(alignment: .leading, spacing: 8) {
                // Game name chip
                gameNameChip
                
                // Players with scores
                playersRow
                
                // Date
                Text(relativeDate)
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary"))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color("InputBackground"))
        .overlay(alignment: .leading) {
            Color("AccentPrimary")
                .opacity(0.15)
                .frame(width: 84)
        }
        .cornerRadius(12)
    }
    
    // MARK: - Sub Views

    private var gameNameChip: some View {
        Text(match.gameName)
            .font(.caption.weight(.semibold))
            .foregroundColor(Color("AccentPrimary"))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color("AccentPrimary").opacity(0.15))
            )
    }
    
    private var playersRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(match.players) { player in
                HStack(spacing: 8) {
                    // Player name
                    Text(player.displayName)
                        .font(.subheadline.weight(player.id == match.winnerId ? .bold : .medium))
                        .foregroundColor(player.id == match.winnerId ? Color("TextPrimary") : Color("TextPrimary"))
                    
                    Spacer()
                    
                    // Score/Icon container
                    HStack {
                        if player.id == match.winnerId {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("AccentTertiary"))
                        } else {
                            Text("\(player.finalScore)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Color("TextSecondary"))
                        }
                    }
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
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
