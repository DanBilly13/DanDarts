//
//  ClubComponents.swift
//  Dart Freak
//
//  Pieces shared by the Clubs screens: the coloured initial tile, the Open / Invite chip,
//  and the rows for "My clubs" and search results.
//

import SwiftUI

// MARK: - Initial tile

/// Clubs have no picture, so each gets a tile with its first letter on a colour taken from its id.
enum ClubTileStyle {
    /// First letter or number of the name, upper-cased; "?" if there is none.
    static func letter(for name: String) -> String {
        guard let first = name.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
        return String(first).uppercased()
    }

    /// Same club, same colour, on every device.
    static func colorIndex(for id: UUID, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let sum = withUnsafeBytes(of: id.uuid) { $0.reduce(0) { $0 &+ Int($1) } }
        return sum % count
    }

    static let palette: [Color] = [AppColor.player1, AppColor.player2, AppColor.player3, AppColor.player4]

    static func color(for id: UUID) -> Color {
        palette[colorIndex(for: id, count: palette.count)]
    }
}

struct ClubTile: View {
    let id: UUID
    let name: String
    var size: CGFloat = 48

    var body: some View {
        Text(ClubTileStyle.letter(for: name))
            .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
            .foregroundColor(AppColor.justBlack)
            .frame(width: size, height: size)
            .background(Circle().fill(ClubTileStyle.color(for: id)))
            .accessibilityHidden(true)
    }
}

// MARK: - Open / Invite chip

struct ClubVisibilityChip: View {
    let visibility: ClubVisibility

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: visibility == .open ? "globe" : "lock.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(visibility == .open ? "Open" : "Invite")
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(visibility == .open ? AppColor.textPrimary : AppColor.textSecondary)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(AppColor.backgroundPrimary))
        .overlay(Capsule().stroke(AppColor.borderMuted, lineWidth: 1))
        .accessibilityLabel(visibility == .open ? "Open club" : "Invite-only club")
    }
}

// MARK: - Text helpers

enum ClubText {
    static func players(_ count: Int) -> String {
        count == 1 ? "1 player" : "\(count) players"
    }

    /// "Leeds · 14 players", or just "14 players" when the club has no town.
    static func subtitle(town: String?, memberCount: Int, extra: String? = nil) -> String {
        var parts: [String] = []
        if let town, !town.isEmpty { parts.append(town) }
        parts.append(players(memberCount))
        if let extra { parts.append(extra) }
        return parts.joined(separator: " · ")
    }

    /// What the confirmation says before someone leaves, since the club's future depends on who they are.
    static func leaveMessage(isAdmin: Bool, memberCount: Int) -> String {
        if memberCount <= 1 {
            return "You're the only member, so the club will be deleted."
        }
        if isAdmin {
            return "The longest-standing member will become the admin."
        }
        return "You can rejoin later if it's an Open club, or with its link or code."
    }

    /// "Oct 2026", for the Joined figure.
    static func joinedText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    /// How many of the listed members the caller is already friends with.
    static func friendCount(in members: [ClubMember]) -> Int {
        members.filter { $0.relationship == .friend }.count
    }
}

// MARK: - My clubs row

struct ClubRow: View {
    let club: Club

    var body: some View {
        HStack(spacing: 12) {
            ClubTile(id: club.id, name: club.name)

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(ClubText.subtitle(town: club.town, memberCount: club.memberCount, extra: club.isAdmin ? "You're admin" : nil))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ClubVisibilityChip(visibility: club.visibility)
        }
        .padding(.leading, 16)
        .padding(.trailing, 20)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.inputBackground)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Search result row

struct ClubSearchRow: View {
    let club: ClubSearchResult
    let isJoined: Bool
    let isJoining: Bool
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ClubTile(id: club.id, name: club.name, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(club.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColor.textPrimary)
                            .lineLimit(1)

                        Text(ClubText.subtitle(town: club.town, memberCount: club.memberCount))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                }

                if !club.avatars.isEmpty {
                    HStack(spacing: -8) {
                        ForEach(Array(club.avatars.prefix(3).enumerated()), id: \.offset) { _, url in
                            AsyncAvatarImage(avatarURL: url, size: 26)
                                .overlay(Circle().stroke(AppColor.inputBackground, lineWidth: 2))
                        }
                    }
                    .padding(.leading, 56)
                    .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 8)

            joinControl
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var joinControl: some View {
        if isJoined || club.isMember {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                Text("Joined")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(AppColor.textSecondary)
            .frame(width: 72, height: 36)
        } else {
            AppButton(role: .primary, controlSize: .small, isDisabled: isJoining, action: onJoin) {
                if isJoining {
                    ProgressView().tint(AppColor.justWhite)
                } else {
                    Text("Join")
                }
            }
            .frame(width: 72)
        }
    }
}
