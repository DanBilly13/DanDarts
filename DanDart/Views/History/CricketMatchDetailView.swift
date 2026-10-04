//
//  CricketMatchDetailView.swift
//  Dart Freak
//
//  A completed Cricket match: final standings, then the final board (the same columns,
//  marks and points as the game screen, rebuilt from the saved darts).
//

import SwiftUI

struct CricketMatchDetailView: View {
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
                    TopBarSub(title: match.gameName, subtitle: match.formattedDate) {
                        TopBarCloseButton { dismiss() }
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
                TopBarSub(title: match.gameName, subtitle: match.formattedDate) {
                    TopBarCloseButton { dismiss() }
                }
            }
        }
    }

    // MARK: - Data

    private var boards: [UUID: CricketPlayerBoard] {
        CricketBoardBuilder.build(players: match.players)
    }

    private func playerIndex(of player: MatchPlayer) -> Int {
        match.players.firstIndex { $0.id == player.id } ?? 0
    }

    /// From the saved placements when present, otherwise winner first then most points.
    private var standings: [MatchPlayer] {
        let metadata = match.metadata ?? [:]
        let hasPlacements = metadata.keys.contains { $0.hasPrefix("placement_") }
        if hasPlacements {
            return match.players.sorted { placement(for: $0) < placement(for: $1) }
        }
        return match.players.sorted { lhs, rhs in
            if (lhs.id == match.winnerId) != (rhs.id == match.winnerId) { return lhs.id == match.winnerId }
            return (boards[lhs.id]?.points ?? 0) > (boards[rhs.id]?.points ?? 0)
        }
    }

    private func placement(for player: MatchPlayer) -> Int {
        Int(match.metadata?["placement_\(player.id.uuidString)"] ?? "") ?? Int.max
    }

    private var boardColumns: [CricketBoardColumn] {
        match.players.enumerated().map { index, player in
            CricketBoardColumn(
                id: player.id,
                name: CricketBoardColumn.firstName(of: player.displayName),
                avatarURL: player.avatarURL,
                color: CricketBoardColumn.color(forPlayerAt: index),
                markCounts: Dictionary(uniqueKeysWithValues: CricketTarget.allCases.map {
                    ($0, boards[player.id]?.marks(on: $0) ?? 0)
                }),
                points: boards[player.id]?.points ?? 0,
                isCurrent: false
            )
        }
    }

    private var deadTargets: Set<CricketTarget> {
        Set(CricketTarget.allCases.filter { target in
            match.players.allSatisfy { (boards[$0.id]?.marks(on: target) ?? 0) >= 3 }
        })
    }

    // MARK: - Views

    private var contentView: some View {
        VStack(spacing: 28) {
            standingsSection
            boardSection
        }
    }

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final standings")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppColor.justWhite)

            ForEach(Array(standings.enumerated()), id: \.element.id) { position, player in
                HStack(spacing: 12) {
                    Text("\(position + 1)")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 24)

                    AsyncAvatarImage(avatarURL: player.avatarURL, size: 40)

                    Text(player.displayName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(CricketBoardColumn.color(forPlayerAt: playerIndex(of: player)))
                        .lineLimit(1)

                    Spacer()

                    if player.id == match.winnerId {
                        Image(systemName: "crown")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColor.interactivePrimaryBackground)
                    }

                    Text("\(boards[player.id]?.points ?? 0) pts")
                        .font(.system(.callout, design: .rounded))
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
    }

    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Final board")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(AppColor.justWhite)

            CricketBoardView(columns: boardColumns, deadTargets: deadTargets)
        }
    }
}
