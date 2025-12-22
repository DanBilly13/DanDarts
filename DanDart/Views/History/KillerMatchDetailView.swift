//
//  KillerMatchDetailView.swift
//  DanDart
//
//  Detailed view of a completed Killer match
//  Shows player rankings, round-by-round grid with icons, and hearts
//

import SwiftUI

struct KillerMatchDetailView: View {
    let match: MatchResult
    var isSheet: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        if isSheet {
            NavigationStack {
                ScrollView {
                    contentView
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                }
                .background(AppColor.backgroundPrimary)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbarRole(.editor)
                .toolbar {
                    TopBarSub(
                        title: match.gameName,
                        subtitle: formattedDate
                    ) {
                        TopBarCloseButton {
                            dismiss()
                        }
                    }
                }
            }
        } else {
            ScrollView {
                contentView
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            }
            .background(AppColor.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarRole(.editor)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                TopBarSub(
                    title: match.gameName,
                    subtitle: formattedDate
                ) {
                    TopBarCloseButton {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Formatted date for subtitle
    private var formattedDate: String {
        match.formattedDate
    }
    
    private var contentView: some View {
        VStack(spacing: 24) {
            // Player cards (winner first, then placement)
            playersSection
            
            // Player color key
            colorKeySection
            
            // Stats section
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                statsSection
            }
            
            // Round-by-round grid
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                roundByRoundSection
            }
            
            // Winner section
            winnerSection
        }
    }
    
    // MARK: - Sub Views
    
    private var playersSection: some View {
        VStack(spacing: 16) {
            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                KillerMatchPlayerCard(
                    player: player,
                    isWinner: player.id == match.winnerId,
                    playerIndex: originalPlayerIndex(for: player),
                    placement: index + 1
                )
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Stats")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppColor.justWhite)
            
            // Kill Stats - sorted by most kills
            StatCategorySection(
                label: "Kills",
                players: playersSortedByKills,
                getValue: { calculateKills(for: $0) }
            )
            
            // Most Suicidal - only show players who shot themselves
            let suicidalPlayers = match.players.filter { calculateSelfHits(for: $0) > 0 }
            if !suicidalPlayers.isEmpty {
                StatCategorySection(
                    label: "Most Suicidal",
                    players: suicidalPlayers.sorted { calculateSelfHits(for: $0) > calculateSelfHits(for: $1) },
                    getValue: { calculateSelfHits(for: $0) }
                )
            }
        }
        .padding(.vertical, 16)
        .onAppear {
            print("📊 Stats Section Appeared")
            for player in match.players {
                let kills = calculateKills(for: player)
                let selfHits = calculateSelfHits(for: player)
                print("   \(player.displayName): \(kills) kills, \(selfHits) self-hits")
                print("   Turns: \(player.turns.count)")
                for (turnIdx, turn) in player.turns.enumerated() {
                    print("     Turn \(turnIdx + 1): \(turn.darts.count) darts")
                    for (dartIdx, dart) in turn.darts.enumerated() {
                        print("       Dart \(dartIdx + 1): metadata=\(dart.killerMetadata?.outcome.rawValue ?? "nil")")
                    }
                }
            }
        }
    }
    
    private var colorKeySection: some View {
        FlexibleLayout(spacing: 12) {
            ForEach(0..<match.players.count, id: \.self) { index in
                HStack(spacing: 6) {
                    Circle()
                        .fill(playerColor(for: index))
                        .frame(width: 12, height: 12)
                    
                    Text(match.players[index].displayName)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    private var roundByRoundSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text("Round-by-Round Breakdown")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppColor.justWhite)
            
            // Get max rounds
            let maxRounds = match.players.map { $0.turns.count }.max() ?? 0
            
            ForEach(0..<maxRounds, id: \.self) { roundIndex in
                roundSection(roundNumber: roundIndex + 1, maxRounds: maxRounds)
            }
        }
    }
    
    private var winnerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Winner title
            Text("Winner")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
            
            // Winner player row - clean display with just avatar, X's, and full hearts
            if let winner = match.players.first(where: { $0.id == match.winnerId }),
               let winnerIndex = match.players.firstIndex(where: { $0.id == match.winnerId }) {
                HStack(spacing: 0) {
                    // Column 1: Player avatar (28px) with player color border
                    AsyncAvatarImage(
                        avatarURL: winner.avatarURL,
                        size: 28
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(playerColor(for: winnerIndex), lineWidth: 1)
                    )
                    .frame(width: 28, height: 28)
                    
                    // Spacer
                    Spacer()
                    
                    // Columns 2-4: Black X's for dart slots (unthrown)
                    HStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(AppColor.justBlack)
                                .frame(width: 52, alignment: .center)
                        }
                    }
                    
                    // Spacer
                    Spacer()
                    
                    // Columns 5+: Hearts showing actual remaining lives
                    HStack(spacing: 0) {
                        let finalLivesRemaining = finalLives(for: winner)
                        ForEach(0..<startingLives, id: \.self) { lifeIndex in
                            let isLost = lifeIndex < (startingLives - finalLivesRemaining)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18))
                                .foregroundColor(isLost ? AppColor.justBlack : AppColor.justWhite)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .padding(8)
                .background(AppColor.inputBackground)
                .frame(height: 44)
                .cornerRadius(8)
            }
        }
        
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func roundSection(roundNumber: Int, maxRounds: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round title
            Text("R\(roundNumber)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
            
            // Grid rows for each player
            VStack(spacing: 8) {
                ForEach(match.players.indices, id: \.self) { playerIndex in
                    let player = match.players[playerIndex]
                    
                    // Only show if player is still alive in this round
                    if isPlayerAliveInRound(player: player, roundNumber: roundNumber) {
                        playerRoundRow(
                            player: player,
                            playerIndex: playerIndex,
                            roundNumber: roundNumber
                        )
                    }
                }
            }
        }
        
        //.background(AppColor.inputBackground)
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func playerRoundRow(player: MatchPlayer, playerIndex: Int, roundNumber: Int) -> some View {
        let turnIndex = roundNumber - 1
        let turn = turnIndex < player.turns.count ? player.turns[turnIndex] : nil
        let darts = turn?.darts ?? []
        
        // Player was alive at start of round if they had lives left before this round
        let wasAliveAtRoundStart = isPlayerAliveInRound(player: player, roundNumber: roundNumber)
        // Player was eliminated before throwing if they were alive at start but have no turn data OR empty darts
        let wasEliminatedBeforeThrowing = wasAliveAtRoundStart && (turn == nil || darts.isEmpty)
        // Turn is incomplete if player has turn data but less than 3 darts OR any dart has nil metadata (game ended mid-turn)
        let isIncompleteTurn = turn != nil && (darts.count < 3 || darts.contains { $0.killerMetadata == nil })
        
        HStack(spacing: 0) {
            // Column 1: Player avatar (28px) with player color border
            AsyncAvatarImage(
                avatarURL: player.avatarURL,
                size: 28
            )
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(playerColor(for: playerIndex), lineWidth: 1)
            )
            .frame(width: 28, height: 28)
            
            // Spacer
            Spacer()
                
            
            // Columns 2-4: Round darts (44px each)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { dartIndex in
                    dartCell(
                        dart: dartIndex < darts.count ? darts[dartIndex] : nil,
                        playerNumber: playerNumber(for: player),
                        wasEliminatedBeforeThrowing: wasEliminatedBeforeThrowing,
                        isIncompleteTurn: isIncompleteTurn
                    )
                }
            }
            
            // Spacer
            Spacer()
               
            
            // Columns 5+: Hearts (28px each)
            HStack(spacing: 0) {
                ForEach(0..<startingLives, id: \.self) { lifeIndex in
                    heartCell(
                        player: player,
                        lifeIndex: lifeIndex,
                        roundNumber: roundNumber
                    )
                    .frame(width: 28, height: 28)
                }
            }
        }
        .padding(8)
        .background(AppColor.inputBackground)
        .frame(height: 44)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func dartCell(dart: MatchDart?, playerNumber: Int, wasEliminatedBeforeThrowing: Bool, isIncompleteTurn: Bool) -> some View {
        Group {
            if let dart = dart, let metadata = dart.killerMetadata {
                switch metadata.outcome {
                case .becameKiller:
                    // Gun icon (became killer - first time only)
                    Image("Gun")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 17)
                        .foregroundColor(AppColor.justWhite)
                    
                case .hitOwnNumber:
                    // Show player's own avatar (killer hit their own number)
                    if let playerId = metadata.affectedPlayerIds.first,
                       let player = match.players.first(where: { $0.id == playerId }),
                       let playerIndex = match.players.firstIndex(where: { $0.id == playerId }) {
                        AsyncAvatarImage(
                            avatarURL: player.avatarURL,
                            size: 28
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(playerColor(for: playerIndex), lineWidth: 1)
                        )
                    }
                    
                case .hitOpponent:
                    // Show victim avatar(s)
                    if metadata.affectedPlayerIds.count == 1 {
                        // Single hit - 1 avatar (28px) with victim's player color border
                        if let victimId = metadata.affectedPlayerIds.first,
                           let victim = match.players.first(where: { $0.id == victimId }),
                           let victimIndex = match.players.firstIndex(where: { $0.id == victimId }) {
                            AsyncAvatarImage(
                                avatarURL: victim.avatarURL,
                                size: 28
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(playerColor(for: victimIndex), lineWidth: 1)
                            )
                        }
                    } else {
                        // Multiple hits - overlapping avatars (same victim) with victim's player color border
                        // Get the victim (should be same player repeated)
                        if let victimId = metadata.affectedPlayerIds.first,
                           let victim = match.players.first(where: { $0.id == victimId }),
                           let victimIndex = match.players.firstIndex(where: { $0.id == victimId }) {
                            let hitCount = min(metadata.affectedPlayerIds.count, 3)
                            let totalWidth = CGFloat(28 + (hitCount - 1) * 8)
                            let startOffset = -totalWidth / 2 + 14 // Center the group (14 = half of avatar size)
                            
                            ZStack {
                                ForEach(0..<hitCount, id: \.self) { index in
                                    let opacity: Double = {
                                        if hitCount == 2 {
                                            // Double: 75%, 100%
                                            return index == 0 ? 0.75 : 1.0
                                        } else if hitCount == 3 {
                                            // Triple: 50%, 75%, 100%
                                            return index == 0 ? 0.5 : (index == 1 ? 0.75 : 1.0)
                                        }
                                        return 1.0
                                    }()
                                    
                                    AsyncAvatarImage(
                                        avatarURL: victim.avatarURL,
                                        size: 28
                                    )
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(playerColor(for: victimIndex), lineWidth: 1)
                                    )
                                    .opacity(opacity)
                                    .offset(x: startOffset + CGFloat(index * 8)) // Center group, then offset each avatar
                                }
                            }
                            .frame(width: totalWidth)
                        }
                    }
                    
                case .miss:
                    // Black X (didn't hit any player's number)
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColor.justWhite .opacity(0.25))
                }
            } else {
                // No dart data - could be eliminated before throwing OR incomplete turn (game ended)
                if wasEliminatedBeforeThrowing || isIncompleteTurn {
                    // Black X for unthrown darts
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColor.justBlack)
                } else {
                    // Empty cell (player alive but no dart data, or not their turn yet)
                    Color.clear
                }
            }
        }
        .frame(width: 52, alignment: .center) // 44px cell with centered content
    }
    
    @ViewBuilder
    private func heartCell(player: MatchPlayer, lifeIndex: Int, roundNumber: Int) -> some View {
        let livesLostUpToThisRound = countLivesLost(player: player, upToRound: roundNumber)
        let isLost = lifeIndex < livesLostUpToThisRound
        
        Image(systemName: "heart.fill")
            .font(.system(size: 18))
            .foregroundColor(isLost ? AppColor.justBlack : AppColor.justWhite)
    }
    
    // MARK: - Helper Methods
    
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            // Winner always first
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            
            // Then by lives remaining (more lives = better placement)
            let lives1 = finalLives(for: player1)
            let lives2 = finalLives(for: player2)
            return lives1 > lives2
        }
    }
    
    private var playersSortedByKills: [MatchPlayer] {
        match.players.sorted { calculateKills(for: $0) > calculateKills(for: $1) }
    }
    
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    private func playerColor(for index: Int) -> Color {
        switch index {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    private var startingLives: Int {
        guard let livesString = match.metadata?["starting_lives"],
              let lives = Int(livesString) else {
            return 3 // Default
        }
        return lives
    }
    
    private func playerNumber(for player: MatchPlayer) -> Int {
        guard let numberString = match.metadata?["player_\(player.id.uuidString)"],
              let number = Int(numberString) else {
            return 0
        }
        return number
    }
    
    private func countLivesLost(player: MatchPlayer, upToRound: Int) -> Int {
        var livesLost = 0
        
        // Check ALL players' turns to see if this player lost lives
        for matchPlayer in match.players {
            let turnsToCheck = min(upToRound, matchPlayer.turns.count)
            
            for turnIndex in 0..<turnsToCheck {
                let turn = matchPlayer.turns[turnIndex]
                for dart in turn.darts {
                    if let metadata = dart.killerMetadata {
                        // Count lives lost for this specific player
                        if metadata.affectedPlayerIds.contains(player.id) {
                            // This player was affected by this dart
                            if metadata.outcome == .hitOwnNumber {
                                // Player hit their own number (lost 1 life)
                                livesLost += 1
                            } else if metadata.outcome == .hitOpponent {
                                // Player was hit by opponent
                                // Count how many times this player appears in affectedPlayerIds
                                livesLost += metadata.affectedPlayerIds.filter { $0 == player.id }.count
                            }
                        }
                    }
                }
            }
        }
        
        return livesLost
    }
    
    private func finalLives(for player: MatchPlayer) -> Int {
        let livesLost = countLivesLost(player: player, upToRound: player.turns.count)
        return max(0, startingLives - livesLost)
    }
    
    private func isPlayerAliveInRound(player: MatchPlayer, roundNumber: Int) -> Bool {
        let livesLostBeforeThisRound = countLivesLost(player: player, upToRound: roundNumber - 1)
        return livesLostBeforeThisRound < startingLives
    }
    
    // Calculate total kills (opponent lives removed) for a player
    private func calculateKills(for player: MatchPlayer) -> Int {
        var kills = 0
        
        // Check all of this player's turns
        for turn in player.turns {
            for dart in turn.darts {
                if let metadata = dart.killerMetadata {
                    // Count opponent hits (each life removed = 1 kill)
                    if metadata.outcome == .hitOpponent {
                        kills += metadata.affectedPlayerIds.count
                    }
                }
            }
        }
        
        return kills
    }
    
    // Calculate self-hits (times player hit their own number) for a player
    private func calculateSelfHits(for player: MatchPlayer) -> Int {
        var selfHits = 0
        
        // Check all of this player's turns
        for turn in player.turns {
            for dart in turn.darts {
                if let metadata = dart.killerMetadata {
                    // Count times they hit their own number
                    if metadata.outcome == .hitOwnNumber {
                        selfHits += 1
                    }
                }
            }
        }
        
        return selfHits
    }
}

// MARK: - Killer Match Player Card

struct KillerMatchPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let playerIndex: Int
    let placement: Int
    
    var borderColor: Color {
        switch playerIndex {
        case 0: return AppColor.player1
        case 1: return AppColor.player2
        case 2: return AppColor.player3
        case 3: return AppColor.player4
        case 4: return AppColor.player5
        case 5: return AppColor.player6
        default: return AppColor.player1
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Player identity
            PlayerIdentity(
                matchPlayer: player,
                avatarSize: 48
            )
            
            Spacer()
            
            // Right side - placement
            VStack(spacing: 4) {
                // Top row: crown or placement
                Group {
                    if isWinner {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    } else {
                        Text(placementText)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .frame(height: 24, alignment: .bottom)
                
                // Bottom row: "WINNER" text
                Group {
                    if isWinner {
                        Text("WINNER")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                            .tracking(0.5)
                    }
                }
                .frame(height: 16, alignment: .center)
            }
            .frame(width: 60)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .cornerRadius(12)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    private var placementText: String {
        switch placement {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(placement)th"
        }
    }
}

// MARK: - Preview

#Preview("Killer Match") {
    NavigationStack {
        KillerMatchDetailView(match: MatchResult.mockKiller)
    }
}
