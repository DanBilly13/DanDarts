//
//  ClubComponents.swift
//  Dart Freak
//
//  Pieces shared by the Clubs screens: the coloured initial tile, the Invite-only padlock,
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
    /// The club photo, if the admin set one. Until it loads (or if it fails) the letter tile shows.
    var imageURL: String? = nil

    var body: some View {
        letterTile
            .overlay {
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                }
            }
            .accessibilityHidden(true)
    }

    private var letterTile: some View {
        Text(ClubTileStyle.letter(for: name))
            .font(.system(size: size * 0.46, weight: .heavy, design: .rounded))
            .foregroundColor(AppColor.justBlack)
            .frame(width: size, height: size)
            .background(Circle().fill(ClubTileStyle.color(for: id)))
    }
}

// MARK: - Invite-only mark

/// A small grey padlock after an Invite-only club's name. Open is the normal kind, so it gets nothing.
/// (It used to be an "Open" / "Invite" chip, which sat where a button would and read like one.)
struct ClubInviteOnlyMark: View {
    var size: CGFloat = 13

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(AppColor.textSecondary)
            .accessibilityLabel("Invite-only")
    }
}

// MARK: - Opening a club after joining or creating

/// Why a club page was opened, so it can say a short hello at the top.
enum ClubWelcome: Hashable {
    case none
    /// "You're in The Crown"
    case joined
    /// "The Crown is ready", and the Invite sheet opens by itself.
    case created
}

enum ClubNavigation {
    /// After joining or creating, go straight to that club's page (Back goes to the Clubs tab,
    /// not the search screen). Falls back to the Clubs tab if the club can't be loaded.
    @MainActor
    static func open(clubId: UUID?, welcome: ClubWelcome, clubsService: ClubsService, router: Router) async {
        router.popToRoot()
        guard let clubId,
              let club = try? await clubsService.myClubs().first(where: { $0.id == clubId }) else { return }
        router.push(.clubDetail(club, welcome: welcome))
    }
}

// MARK: - Text helpers

enum ClubText {
    static func members(_ count: Int) -> String {
        count == 1 ? "1 member" : "\(count) members"
    }

    /// "Leeds · 14 members", or just "14 members" when the club has no town.
    static func subtitle(town: String?, memberCount: Int, extra: String? = nil) -> String {
        var parts: [String] = []
        if let town, !town.isEmpty { parts.append(town) }
        parts.append(members(memberCount))
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

    /// "The Crown", "The Crown +1" when they share more clubs with you, or a plain line if the club is unknown.
    static func suggestionSubtitle(clubName: String?, sharedCount: Int) -> String {
        guard let clubName, !clubName.isEmpty else { return "In a club with you" }
        return sharedCount > 1 ? "\(clubName) +\(sharedCount - 1)" : clubName
    }

    /// "Oct ’26", for the Joined / Started figure: short, so it sits like the other two numbers.
    static func joinedText(_ date: Date) -> String {
        let month = date.formatted(.dateTime.month(.abbreviated))
        let year = date.formatted(.dateTime.year(.twoDigits))
        return "\(month) \u{2019}\(year)"
    }

    /// How many of the listed members the caller is already friends with.
    static func friendCount(in members: [ClubMember]) -> Int {
        members.filter { $0.relationship == .friend }.count
    }

    /// True when someone in the list (not you) isn't your friend yet.
    static func hasNonFriends(in members: [ClubMember]) -> Bool {
        members.contains { $0.relationship != .selfUser && $0.relationship != .friend }
    }

    /// The club's rank: the average of its ranked members' ranks, turned back into a rank the same
    /// way a player's is. Members with no ranked wins yet don't count. None ranked = unranked.
    static func clubRank(of members: [ClubMember]) -> RankTier {
        let ranked = members.filter { $0.rankedWinsCount > 0 }
        guard !ranked.isEmpty else { return .unranked }
        let average = ranked
            .map { Double($0.rankedTierScoreTotal) / Double($0.rankedWinsCount) }
            .reduce(0, +) / Double(ranked.count)
        return RankingHelper.profileRankFromAverageTierScore(average)
    }
}

// MARK: - My clubs row

struct ClubRow: View {
    let club: Club

    var body: some View {
        HStack(spacing: 12) {
            ClubTile(id: club.id, name: club.name, imageURL: club.imageURL)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(club.name)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    if club.visibility == .invite { ClubInviteOnlyMark() }
                }

                Text(ClubText.subtitle(town: club.town, memberCount: club.memberCount, extra: club.isAdmin ? "You're admin" : nil))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
                .accessibilityHidden(true)
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

// MARK: - Invite card (Clubs tab)

/// "Dan invited you to The Crown" with Join and No thanks.
struct ClubInviteCard: View {
    let invite: ClubInvite
    let isBusy: Bool
    let onJoin: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ClubTile(id: invite.clubId, name: invite.clubName, size: 52, imageURL: invite.clubImageURL)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(invite.inviterName) invited you to")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                    Text(invite.clubName)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    Text(ClubText.subtitle(town: invite.clubTown, memberCount: invite.memberCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                AppButton(role: .tertiaryOutline, controlSize: .regular, isDisabled: isBusy, action: onDecline) {
                    Text("No thanks")
                }
                AppButton(role: .primary, controlSize: .regular, isDisabled: isBusy, action: onJoin) {
                    if isBusy {
                        ProgressView().tint(AppColor.justWhite)
                    } else {
                        Text("Join")
                    }
                }
            }
        }
        .padding(16)
        .background(AppColor.inputBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    ClubTile(id: club.id, name: club.name, size: 44, imageURL: club.imageURL)

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
