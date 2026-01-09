//
//  MatchDetailView.swift
//  Dart Freak
//
//  Detailed view of a completed match with turn-by-turn breakdown
//

import SwiftUI

struct MatchDetailView: View {
    let match: MatchResult
    var isSheet: Bool = false  // Set to true when presented as sheet
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        // Route to game-specific detail view
        if match.gameName == "Halve It" {
            HalveItMatchDetailView(match: match, isSheet: isSheet)
        } else if match.gameName == "Sudden Death" {
            SuddenDeathMatchDetailView(match: match, isSheet: isSheet)
        } else if match.gameName == "Knockout" {
            KnockoutMatchDetailView(match: match, isSheet: isSheet)
        } else if match.gameName == "Killer" {
            KillerMatchDetailView(match: match, isSheet: isSheet)
        } else {
            // 301/501 matches use generic view
            if isSheet {
                // Sheet presentation
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
                            subtitle: match.formattedDate
                        ) {
                            TopBarCloseButton {
                                dismiss()
                            }
                        }
                    }
                }
            } else {
                // Navigation push - use standard ScrollView
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
                        subtitle: match.formattedDate
                    ) {
                        TopBarCloseButton {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // Shared content for both contexts
    private var contentView: some View {
        VStack(spacing: 24) {
            // Players and Scores
            playersSection
            
            // Stats Section (for all matches)
            if !match.players.isEmpty {
                statsComparisonSection
            }
            
            // Turn-by-Turn Breakdown
            if !match.players.isEmpty && !match.players[0].turns.isEmpty {
                turnBreakdownSection
            }
        }
    }
    
    // MARK: - Sub Views
    
    private var playersSection: some View {
        VStack(spacing: 16) {
            // Sort players: winner first, then by final score (lowest remaining)
            ForEach(Array(sortedPlayers.enumerated()), id: \.element.id) { index, player in
                MatchPlayerCard(
                    player: player,
                    isWinner: player.id == match.winnerId,
                    playerIndex: originalPlayerIndex(for: player),
                    placement: index + 1,
                    matchFormat: match.matchFormat,
                    gameType: match.gameName
                )
            }
        }
    }
    
    // Sorted players: winner first, then by final score
    private var sortedPlayers: [MatchPlayer] {
        match.players.sorted { player1, player2 in
            // Winner always comes first
            if player1.id == match.winnerId { return true }
            if player2.id == match.winnerId { return false }
            
            // Then sort by final score (lower is better - closer to winning)
            return player1.finalScore < player2.finalScore
        }
    }
    
    // Get original player index for color assignment
    private func originalPlayerIndex(for player: MatchPlayer) -> Int {
        match.players.firstIndex(where: { $0.id == player.id }) ?? 0
    }
    
    // Get player color based on index
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
    
    private var statsComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats title
            Text("Stats")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColor.textPrimary)
            
            // Color key legend (wraps to 2 rows if needed)
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
            
            VStack(spacing: 20) {
                // Number of turns
                StatCategorySection(
                    label: "Number of turns",
                    players: match.players,
                    getValue: { $0.turns.count }
                )
                
                // 3-dart average
                StatCategorySection(
                    label: "Average visit",
                    players: match.players,
                    getValue: { Int($0.averageScore) },
                    isDecimal: true,
                    getDecimalValue: { $0.averageScore }
                )
                
                // Highest visit
                StatCategorySection(
                    label: "Highest visit",
                    players: match.players,
                    getValue: { highestVisit(for: $0) }
                )
                
                // 100+ thrown
                StatCategorySection(
                    label: "100+ thrown",
                    players: match.players,
                    getValue: { count100Plus(for: $0) }
                )
                
                // 140+ thrown
                StatCategorySection(
                    label: "140+ thrown",
                    players: match.players,
                    getValue: { count140Plus(for: $0) }
                )
                
                // 180s thrown
                StatCategorySection(
                    label: "180s thrown",
                    players: match.players,
                    getValue: { count180s(for: $0) }
                )
            }
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Stats Helpers
    
    private func count180s(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal == 180 }.count
    }
    
    private func count140Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 140 }.count
    }
    
    private func count100Plus(for player: MatchPlayer) -> Int {
        player.turns.filter { $0.turnTotal >= 100 }.count
    }
    
    private func highestVisit(for player: MatchPlayer) -> Int {
        player.turns.map { $0.turnTotal }.max() ?? 0
    }
    
    private var turnBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Turn-by-Turn Breakdown")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)
            
            // Get max turns across all players
            let maxTurns = match.players.map { $0.turns.count }.max() ?? 0
            
            ForEach(0..<maxTurns, id: \.self) { roundIndex in
                let playerData = match.players.enumerated().map { playerIndex, player in
                    let turn = roundIndex < player.turns.count ? player.turns[roundIndex] : nil
                    let darts = turn?.darts.map { $0.displayText } ?? []
                    // If no turn, use previous turn's scoreAfter, or startingScore if first round
                    let scoreRemaining: Int
                    if let turn = turn {
                        scoreRemaining = turn.scoreAfter
                    } else if roundIndex > 0, let previousTurn = player.turns.last {
                        scoreRemaining = previousTurn.scoreAfter
                    } else {
                        scoreRemaining = player.startingScore
                    }
                    let isBust = turn?.isBust ?? false
                    
                    return ThrowBreakdownCard.PlayerTurnData(
                        darts: darts,
                        scoreRemaining: scoreRemaining,
                        color: playerColor(for: playerIndex),
                        isBust: isBust
                    )
                }
                
                ThrowBreakdownCard(
                    roundNumber: roundIndex + 1,
                    playerData: playerData
                )
            }
        }
    }
}

// MARK: - Compact Player Card (Side-by-Side)

struct CompactPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let alignment: HorizontalAlignment
    let playerIndex: Int
    
    // Get border color based on player index
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
        VStack(alignment: .center, spacing: 12) {
            // Avatar with crown
            ZStack {
                Circle()
                    .fill(AppColor.inputBackground)
                    .frame(width: 100, height: 100)
                
                if let avatarURL = player.avatarURL,
                   let uiImage = UIImage(named: avatarURL) ?? (avatarURL.hasPrefix("/") ? UIImage(contentsOfFile: avatarURL) : nil) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                }
                
                // Winner crown
                if isWinner {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColor.player1)
                        .offset(y: -55)
                }
            }
            
            // Player info - centered
            VStack(alignment: .center, spacing: 4) {
                Text(player.displayName)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                
                if !player.isGuest {
                    Text("@\(player.nickname)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColor.textPrimary.opacity(0.8))
                }
            }
            
            // Winner badge or remaining points
            if isWinner {
                VStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    
                    Text("WINNER")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColor.textPrimary)
                        .tracking(1)
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    Text("\(player.finalScore)")
                        .font(.title.weight(.bold))
                        .foregroundColor(AppColor.textPrimary)
                    
                    Text("Left on \(player.finalScore)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(AppColor.textPrimary)
                }
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppColor.inputBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
    }
}

// MARK: - Match Player Card

struct MatchPlayerCard: View {
    let player: MatchPlayer
    let isWinner: Bool
    let playerIndex: Int
    let placement: Int
    var matchFormat: Int = 1 // Total legs in match (1, 3, 5, or 7)
    var gameType: String = "301" // Game type to determine score display logic
    
    // Check if this is a multi-leg match
    private var isMultiLegMatch: Bool {
        matchFormat > 1
    }
    
    // Determine if this is a countdown game (301, 501) or accumulation game (Halve It, Cricket, etc.)
    private var isCountdownGame: Bool {
        gameType == "301" || gameType == "501"
    }
    
    // Get border color based on player index
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
            // Player identity (avatar + name + nickname)
            PlayerIdentity(
                matchPlayer: player,
                avatarSize: 48
            )
            
            Spacer()
            
            // Right side - Score display (type depends on game)
            scoreDisplayView
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(AppColor.inputBackground)
        .clipShape(.capsule)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 2)
        )
    }
    
    // Score display component based on game type
    @ViewBuilder
    private var scoreDisplayView: some View {
        if isCountdownGame {
            // Countdown games: 301, 501 (lower is better, winner = 0)
            CountdownScoreDisplay(
                isWinner: isWinner,
                placement: placement,
                finalScore: player.finalScore,
                borderColor: borderColor,
                isMultiLegMatch: isMultiLegMatch,
                legsWon: player.legsWon,
                totalLegs: matchFormat
            )
        } else {
            // Accumulation games: Halve It, Cricket, etc. (higher is better)
            AccumulationScoreDisplay(
                isWinner: isWinner,
                placement: placement,
                finalScore: player.finalScore,
                borderColor: borderColor,
                isMultiLegMatch: isMultiLegMatch,
                legsWon: player.legsWon,
                totalLegs: matchFormat
            )
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.interactivePrimaryBackground)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColor.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textPrimary)
        }
    }
}

// MARK: - Stat Category Section

struct StatCategorySection: View {
    let label: String
    let players: [MatchPlayer]
    let getValue: (MatchPlayer) -> Int
    var isDecimal: Bool = false
    var getDecimalValue: ((MatchPlayer) -> Double)?
    var forceMaxValue: Int? = nil  // Force specific max value (e.g., 100 for percentages)
    var getOriginalIndex: ((MatchPlayer) -> Int)?  // Get original player index for correct colors
    
    // Calculate max value for scaling bars
    private var maxValue: Int {
        if let forced = forceMaxValue {
            return forced
        }
        let values = players.map { getValue($0) }
        return max(values.max() ?? 1, 1) // Minimum 1 to avoid division by zero
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category label
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)
            
            // Individual stat bars for each player
            VStack(spacing: 6) {
                ForEach(0..<players.count, id: \.self) { index in
                    PlayerStatBar(
                        player: players[index],
                        playerIndex: getOriginalIndex?(players[index]) ?? index,
                        value: getValue(players[index]),
                        maxValue: maxValue,
                        isDecimal: isDecimal,
                        decimalValue: getDecimalValue?(players[index])
                    )
                }
            }
        }
    }
}

// MARK: - Player Stat Bar

struct PlayerStatBar: View {
    let player: MatchPlayer
    let playerIndex: Int
    let value: Int
    let maxValue: Int
    var isDecimal: Bool = false
    var decimalValue: Double?
    
    // Get player color based on index
    private var playerColor: Color {
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
    
    // Calculate percentage for bar width
    private var percentage: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress bar (no avatar)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar (gray)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColor.inputBackground)
                        .frame(height: 12)
                    
                    // Filled bar (player's color)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(playerColor)
                        .frame(width: geometry.size.width * percentage, height: 12)
                }
            }
            .frame(height: 12)
            
            // Value (right aligned, rounded up)
            Text(isDecimal && decimalValue != nil ? "\(Int(ceil(decimalValue!)))" : "\(value)")
                .font(.caption.weight(.bold))
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Player Turn Breakdown

struct PlayerTurnBreakdown: View {
    let player: MatchPlayer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player name header
            Text(player.displayName)
                .font(.headline)
                .foregroundColor(AppColor.textPrimary)
            
            // Turns
            VStack(spacing: 8) {
                ForEach(player.turns) { turn in
                    TurnRow(turn: turn)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(AppColor.inputBackground)
        .cornerRadius(12)
    }
}

// MARK: - Turn Row

struct TurnRow: View {
    let turn: MatchTurn
    
    var body: some View {
        HStack(spacing: 12) {
            // Turn number
            Text("Turn \(turn.turnNumber)")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 60, alignment: .leading)
            
            // Darts
            HStack(spacing: 4) {
                ForEach(turn.darts, id: \.value) { dart in
                    Text(dart.displayText)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColor.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(AppColor.backgroundPrimary)
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Turn total
            Text("\(turn.turnTotal)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(turn.isBust ? Color.red : AppColor.interactivePrimaryBackground)
            
            // Score after
            Text("→ \(turn.scoreAfter)")
                .font(.caption.weight(.medium))
                .foregroundColor(AppColor.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flexible Layout (for wrapping color key)

struct FlexibleLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlexResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlexResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlexResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MatchDetailView(match: MatchResult.mock301)
    }
}
