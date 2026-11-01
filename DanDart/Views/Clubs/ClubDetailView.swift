//
//  ClubDetailView.swift
//  Dart Freak
//
//  A club's page. Members see who is in it (with Add / Request sent / Friend on each row), can
//  share the club link, report the club or a person, and leave. The admin also gets the code
//  with Copy and Make a new code, the Open / Invite-only switch, and can remove members.
//

import SwiftUI
import UIKit

struct ClubDetailView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var clubsService: ClubsService
    @EnvironmentObject private var friendsService: FriendsService
    @EnvironmentObject private var authService: AuthService

    @State private var club: Club
    @State private var members: [ClubMember] = []
    @State private var membersLoaded = false
    @State private var membersFailed = false
    @State private var addingId: UUID?
    @State private var isBusy = false
    @State private var isReporting = false
    @State private var showShareSheet = false
    @State private var justCopied = false
    @State private var pending: Pending?
    @State private var notice: Notice?

    /// Something that needs a "Are you sure?" before it happens.
    private enum Pending {
        case leave
        case reportClub
        case newCode
        case reportMember(ClubMember)
        case removeMember(ClubMember)
    }

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var leavesScreen = false
    }

    init(club: Club) {
        _club = State(initialValue: club)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if club.isAdmin {
                    adminHeader
                    inviteCard
                    visibilityPicker
                } else {
                    memberHeader
                    statsRow
                    shareButton
                }

                membersSection
                footerActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .refreshable { await refresh() }
        .background(AppColor.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .sheet(isPresented: $showShareSheet) {
            if let url = club.shareURL {
                ShareSheet(activityItems: ["Join \(club.name) on Dart Freak:", url])
            }
        }
        .confirmationDialog(
            pending.map { dialog(for: $0).title } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { item in
            Button(dialog(for: item).button, role: dialog(for: item).isDestructive ? .destructive : nil) {
                perform(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(dialog(for: item).message)
        }
        .alert(item: $notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK")) {
                    if notice.leavesScreen { router.pop() }
                }
            )
        }
    }

    // MARK: - Headers

    private var memberHeader: some View {
        VStack(spacing: 12) {
            ClubTile(id: club.id, name: club.name, size: 96)

            VStack(spacing: 4) {
                Text(club.name)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(visibilityLine)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.interactivePrimaryBackground)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var adminHeader: some View {
        HStack(spacing: 16) {
            ClubTile(id: club.id, name: club.name, size: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(club.name)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: club.visibility == .open ? "globe" : "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(ClubText.subtitle(
                        town: club.town,
                        memberCount: club.memberCount,
                        extra: club.visibility == .open ? "Open" : "Invite-only"
                    ))
                    .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(AppColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Leeds · Open club", or "Invite-only club" when there is no town.
    private var visibilityLine: String {
        let kind = club.visibility == .open ? "Open club" : "Invite-only club"
        guard let town = club.town, !town.isEmpty else { return kind }
        return "\(town) · \(kind)"
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            stat(value: "\(club.memberCount)", label: "Players")
            stat(value: membersLoaded ? "\(ClubText.friendCount(in: members))" : "–", label: "Your friends")
            stat(value: ClubText.joinedText(club.joinedAt), label: "Joined")
        }
        .padding(.vertical, 8)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Sharing

    @ViewBuilder
    private var shareButton: some View {
        if club.shareURL != nil {
            AppButton(role: .primary, controlSize: .large) {
                showShareSheet = true
            } label: {
                Label("Share club link", systemImage: "square.and.arrow.up")
            }
            .padding(.horizontal, 16)
        }
    }

    /// Admin only: the link, the code, Make a new code and Share.
    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite link")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Text(ClubLink.shortLink(forCode: club.joinCode))
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 0)

                    AppButton(role: .secondaryOutline, controlSize: .small, action: copyLink) {
                        Text(justCopied ? "Copied" : "Copy")
                    }
                    .fixedSize()
                }

                Divider().overlay(AppColor.borderMuted)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Code")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColor.textSecondary)
                        Text(ClubLink.displayCode(club.joinCode))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(AppColor.textPrimary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    AppButton(role: .secondaryOutline, controlSize: .small, isDisabled: isBusy) {
                        pending = .newCode
                    } label: {
                        Text("Make a new code")
                    }
                    .fixedSize()
                }

                AppButton(role: .primary, controlSize: .regular) {
                    showShareSheet = true
                } label: {
                    Label("Share link", systemImage: "square.and.arrow.up")
                }
            }
            .padding(16)
            .background(AppColor.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func copyLink() {
        guard let url = club.shareURL else { return }
        UIPasteboard.general.string = url.absoluteString
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        justCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            justCopied = false
        }
    }

    // MARK: - Open / Invite-only (admin)

    private var visibilityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Who can join?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            HStack(spacing: 4) {
                visibilityOption(.open, title: "Open", icon: "globe")
                visibilityOption(.invite, title: "Invite-only", icon: "lock.fill")
            }
            .padding(4)
            .frame(height: 44)
            .background(AppColor.inputBackground)
            .clipShape(Capsule())

            Text(club.visibility == .open
                 ? "Anyone can find this club in search and join with one tap."
                 : "Invite-only clubs don't show up in search.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    private func visibilityOption(_ option: ClubVisibility, title: String, icon: String) -> some View {
        let selected = club.visibility == option
        return Button {
            setVisibility(option)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(selected ? AppColor.justWhite : AppColor.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Capsule().fill(selected ? AppColor.interactivePrimaryBackground : Color.clear))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Members

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Members")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                Text("\(club.memberCount)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.trailing, 8)
            }

            if !membersLoaded && !membersFailed {
                ProgressView()
                    .tint(AppColor.interactivePrimaryBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if membersFailed && members.isEmpty {
                VStack(spacing: 12) {
                    Text("Couldn't load the members")
                        .font(.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                    AppButton(role: .secondaryOutline, controlSize: .small) {
                        Task { await loadMembers() }
                    } label: {
                        Text("Try again")
                    }
                    .fixedSize()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(members) { member in
                        memberRow(member)
                    }
                }
            }
        }
    }

    private func memberRow(_ member: ClubMember) -> some View {
        let isSelf = member.relationship == .selfUser
        return HStack(spacing: 12) {
            AsyncAvatarImage(avatarURL: member.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(isSelf ? "You" : member.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                if let detail = memberDetail(member, isSelf: isSelf) {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            relationshipControl(member)

            if !isSelf {
                memberMenu(member)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, isSelf ? 20 : 12)
        .frame(height: 68)
        .frame(maxWidth: .infinity)
        .background(AppColor.inputBackground)
        .clipShape(Capsule())
    }

    /// "@nickname", with "Admin" added for the club's admin.
    private func memberDetail(_ member: ClubMember, isSelf: Bool) -> String? {
        var parts: [String] = []
        if !isSelf, let nickname = member.nickname, !nickname.isEmpty { parts.append("@\(nickname)") }
        if member.role == .admin { parts.append("Admin") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func relationshipControl(_ member: ClubMember) -> some View {
        switch member.relationship {
        case .none:
            AppButton(role: .primary, controlSize: .small, isDisabled: addingId != nil) {
                addFriend(member)
            } label: {
                if addingId == member.id {
                    ProgressView().tint(AppColor.justWhite)
                } else {
                    Text("Add")
                }
            }
            .frame(width: 72)
            .accessibilityLabel("Add \(member.displayName) as a friend")
        case .requestSent:
            statusLabel("Request sent")
        case .requestReceived:
            statusLabel("Wants to add you")
        case .friend:
            statusLabel("Friend")
        case .selfUser, .blocked:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColor.textSecondary)
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .frame(maxWidth: 84, alignment: .trailing)
    }

    /// Report for everyone; Remove for the admin.
    private func memberMenu(_ member: ClubMember) -> some View {
        Menu {
            Button {
                pending = .reportMember(member)
            } label: {
                Label("Report \(member.displayName)", systemImage: "flag")
            }
            if club.isAdmin {
                Button(role: .destructive) {
                    pending = .removeMember(member)
                } label: {
                    Label("Remove from club", systemImage: "person.fill.xmark")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More options for \(member.displayName)")
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 28) {
            if !club.isAdmin {
                Button("Report club") { pending = .reportClub }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            Button("Leave club") { pending = .leave }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColor.interactivePrimaryBackground)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.top, 8)
        .disabled(isBusy)
    }

    // MARK: - Confirmations

    private struct DialogText {
        let title: String
        let message: String
        let button: String
        let isDestructive: Bool
    }

    private func dialog(for item: Pending) -> DialogText {
        switch item {
        case .leave:
            return DialogText(
                title: "Leave \(club.name)?",
                message: ClubText.leaveMessage(isAdmin: club.isAdmin, memberCount: club.memberCount),
                button: "Leave club",
                isDestructive: true
            )
        case .reportClub:
            return DialogText(
                title: "Report this club?",
                message: "We'll look at it and remove anything that breaks the rules.",
                button: "Report club",
                isDestructive: true
            )
        case .newCode:
            return DialogText(
                title: "Make a new code?",
                message: "The current link and code stop working straight away. Anyone who already joined stays in.",
                button: "Make a new code",
                isDestructive: true
            )
        case .reportMember(let member):
            return DialogText(
                title: "Report \(member.displayName)?",
                message: "We'll look at it and take action if they've broken the rules.",
                button: "Report",
                isDestructive: true
            )
        case .removeMember(let member):
            return DialogText(
                title: "Remove \(member.displayName)?",
                message: club.visibility == .open
                    ? "They can join again unless you switch the club to Invite-only."
                    : "They'll need the link or code to join again. Make a new code to keep them out.",
                button: "Remove",
                isDestructive: true
            )
        }
    }

    private func perform(_ item: Pending) {
        switch item {
        case .leave: leave()
        case .reportClub: report(.club, id: club.id, title: "Club reported")
        case .newCode: regenerateCode()
        case .reportMember(let member): report(.user, id: member.id, title: "Reported")
        case .removeMember(let member): remove(member)
        }
    }

    // MARK: - Loading

    private func refresh() async {
        // The member list doesn't depend on the club refresh, so load both at once.
        async let loadedMembers: Void = loadMembers()
        do {
            let mine = try await clubsService.myClubs()
            if let fresh = mine.first(where: { $0.id == club.id }) {
                club = fresh
            } else {
                // Removed from the club, or it was deleted, while this page was open.
                router.pop()
                return
            }
        } catch {
            // Keep showing what we have; the members call below reports its own failure.
            guard !Task.isCancelled else { return }
            print("❌ [Clubs] Failed to refresh club: \(error)")
        }
        await loadedMembers
    }

    private func loadMembers() async {
        do {
            members = try await clubsService.members(clubId: club.id)
            membersFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            membersFailed = true
            print("❌ [Clubs] Failed to load members: \(error)")
        }
        membersLoaded = true
    }

    // MARK: - Actions

    private func connectionNotice(_ title: String) {
        notice = Notice(title: title, message: "Check your connection and try again.")
    }

    private func setRelationship(_ relationship: ClubRelationship, for id: UUID) {
        members = members.map { $0.id == id ? $0.updating(relationship: relationship) : $0 }
    }

    private func addFriend(_ member: ClubMember) {
        guard addingId == nil, let currentUserId = authService.currentUser?.id else { return }
        addingId = member.id
        Task {
            defer { addingId = nil }
            do {
                try await friendsService.sendFriendRequest(userId: currentUserId, friendId: member.id)
                setRelationship(.requestSent, for: member.id)
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch FriendsError.alreadyFriends {
                setRelationship(.friend, for: member.id)
            } catch FriendsError.requestPending {
                setRelationship(.requestSent, for: member.id)
            } catch let error as FriendsError {
                notice = Notice(title: "Couldn't add \(member.displayName)", message: error.localizedDescription)
            } catch {
                print("❌ [Clubs] Add friend failed: \(error)")
                connectionNotice("Couldn't add \(member.displayName)")
            }
        }
    }

    private func setVisibility(_ visibility: ClubVisibility) {
        guard visibility != club.visibility, !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let result = try await clubsService.setVisibility(clubId: club.id, visibility: visibility)
                switch result {
                case .ok:
                    club = club.updating(visibility: visibility)
                case .duplicate:
                    notice = Notice(
                        title: "Can't switch to Open",
                        message: "There's already an Open club with this name and town, so this one stays Invite-only."
                    )
                default:
                    notice = Notice(title: "Couldn't change it", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Set visibility failed: \(error)")
                connectionNotice("Couldn't change it")
            }
        }
    }

    private func regenerateCode() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let outcome = try await clubsService.regenerateCode(clubId: club.id)
                if outcome.result.isOk, let newCode = outcome.joinCode {
                    club = club.updating(joinCode: newCode)
                    notice = Notice(title: "New code ready", message: "The old link and code don't work any more.")
                } else {
                    notice = Notice(title: "Couldn't make a new code", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Regenerate code failed: \(error)")
                connectionNotice("Couldn't make a new code")
            }
        }
    }

    private func remove(_ member: ClubMember) {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let result = try await clubsService.removeMember(clubId: club.id, userId: member.id)
                switch result {
                case .ok, .notMember:
                    members.removeAll { $0.id == member.id }
                    club = club.updating(memberCount: max(1, club.memberCount - 1))
                default:
                    notice = Notice(title: "Couldn't remove \(member.displayName)", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Remove member failed: \(error)")
                connectionNotice("Couldn't remove \(member.displayName)")
            }
        }
    }

    private func leave() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let result = try await clubsService.leaveClub(clubId: club.id)
                switch result {
                case .ok, .notMember:
                    router.pop()
                default:
                    notice = Notice(title: "Couldn't leave", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Leave failed: \(error)")
                connectionNotice("Couldn't leave")
            }
        }
    }

    private func report(_ target: ClubsService.ReportTarget, id: UUID, title: String) {
        guard !isReporting else { return }
        isReporting = true
        Task {
            defer { isReporting = false }
            do {
                let result = try await clubsService.report(target, id: id)
                if result.isOk {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    notice = Notice(title: title, message: "Thanks for telling us. We'll take a look.")
                } else {
                    notice = Notice(title: "Couldn't send the report", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Report failed: \(error)")
                connectionNotice("Couldn't send the report")
            }
        }
    }
}
