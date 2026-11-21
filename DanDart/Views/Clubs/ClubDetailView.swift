//
//  ClubDetailView.swift
//  Dart Freak
//
//  A club's page, the same calm layout for everyone: the club, three stats, one Invite players
//  button, then the members (with Add friend / Request sent / Friend on each row), then Leave.
//  Invite players opens a sheet: the share button for everyone, plus for the admin the
//  Open / Invite-only switch and, for an Invite-only club, the code with a "new code" button.
//

import SwiftUI
import UIKit
import PhotosUI

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
    @State private var showInvite = false
    /// Confirmations and messages raised from inside the Invite sheet (the page's own can't show over it).
    @State private var sheetPending: Pending?
    @State private var sheetNotice: Notice?
    @State private var welcome: ClubWelcome
    /// A short line at the bottom, e.g. "Friend request sent to Sam".
    @State private var toast: String?
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isSavingPhoto = false
    /// The Invite sheet's "Your friends" list.
    @State private var friends: [User] = []
    @State private var friendsLoaded = false
    @State private var invitedIds: Set<UUID> = []
    @State private var invitingId: UUID?

    /// Something that needs a "Are you sure?" before it happens.
    private enum Pending {
        case leave
        case reportClub
        case newCode
        case reportMember(ClubMember)
        case removeMember(ClubMember)
        case blockMember(ClubMember)
    }

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var leavesScreen = false
    }

    init(club: Club, welcome: ClubWelcome = .none) {
        _club = State(initialValue: club)
        _welcome = State(initialValue: welcome)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statsRow
                inviteButton
                membersSection
                footerActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.justBlack)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(AppColor.justWhite, in: Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .refreshable { await refresh() }
        .background(AppColor.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .task {
            // A new club opens straight onto the Invite sheet: bringing mates in is the next step.
            if welcome == .created {
                try? await Task.sleep(for: .milliseconds(400))
                showInvite = true
            }
            // Joined: a short "You're in …" at the bottom instead of leaving people to guess.
            if welcome == .joined {
                try? await Task.sleep(for: .milliseconds(400))
                showToast("You're in \(club.name)")
            }
            welcome = .none
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            savePhoto(item)
        }
        .sheet(isPresented: $showInvite) {
            inviteSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppColor.surfacePrimary)
        }
        .confirmationDialog(
            pending.map { dialog(for: $0).title } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { item in
            if case .reportClub = item, club.imageURL != nil {
                // A club with a photo: say whether it's the photo or the club itself.
                Button("Report the photo", role: .destructive) {
                    report(.club, id: club.id, title: "Photo reported", reason: "photo")
                }
                Button("Report the club", role: .destructive) { perform(item) }
            } else {
                Button(dialog(for: item).button, role: dialog(for: item).isDestructive ? .destructive : nil) {
                    perform(item)
                }
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            if club.isAdmin {
                // The admin taps the tile to pick a photo (or remove it).
                Menu {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label(club.imageURL == nil ? "Add a photo" : "Change photo", systemImage: "photo")
                    }
                    if club.imageURL != nil {
                        Button(role: .destructive) {
                            removePhoto()
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                } label: {
                    ClubTile(id: club.id, name: club.name, size: 96, imageURL: club.imageURL)
                        .overlay {
                            if isSavingPhoto {
                                Circle().fill(.black.opacity(0.45))
                                ProgressView().tint(AppColor.justWhite)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColor.justBlack)
                                .frame(width: 30, height: 30)
                                .background(AppColor.justWhite, in: Circle())
                                .overlay(Circle().stroke(AppColor.backgroundPrimary, lineWidth: 3))
                        }
                }
                .disabled(isSavingPhoto)
                .accessibilityLabel("Club photo")
            } else {
                ClubTile(id: club.id, name: club.name, size: 96, imageURL: club.imageURL)
            }

            VStack(spacing: 4) {
                Text(club.name)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    if club.visibility == .invite { ClubInviteOnlyMark(size: 13) }
                    Text(visibilityLine)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// "Leeds · Open club · Started Nov ’26". The admin started the club; everyone else joined it.
    /// (Being admin shows on your own member card, so it isn't repeated here.)
    private var visibilityLine: String {
        var parts: [String] = []
        if let town = club.town, !town.isEmpty { parts.append(town) }
        parts.append(club.visibility == .open ? "Open club" : "Invite-only club")
        parts.append("\(club.isAdmin ? "Started" : "Joined") \(ClubText.joinedText(club.joinedAt))")
        return parts.joined(separator: " · ")
    }

    /// The club as a big player: members, your friends in it, and its rank (the average of its
    /// ranked members), in the same cards as a player's profile.
    private var statsRow: some View {
        let rank = ClubText.clubRank(of: members)
        return HStack(spacing: 8) {
            StatCard(title: "Members", value: "\(club.memberCount)", icon: "person.3.fill")
            StatCard(
                title: "Your friends",
                value: membersLoaded ? "\(ClubText.friendCount(in: members))" : "–",
                icon: "person.2.fill"
            )
            StatCard(
                title: "Rank",
                value: membersLoaded ? rank.displayName : "–",
                icon: rank.iconName
            )
        }
    }

    // MARK: - Invite players

    private var inviteButton: some View {
        AppButton(role: .primary, controlSize: .large) {
            showInvite = true
        } label: {
            Label("Invite players", systemImage: "person.badge.plus")
        }
        .padding(.horizontal, 16)
    }

    /// Everything about getting people in, kept off the page. Open club: one line and Share.
    /// Invite-only: the code too (admin only), tap to copy, ↻ for a new one. The admin also gets
    /// the Open / Invite-only switch at the top, and the sheet changes as they flip it.
    private var inviteSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Invite players")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)

                if club.isAdmin {
                    visibilityPicker
                }

                friendsSection

                VStack(alignment: .leading, spacing: 12) {
                    Text("Or send a link")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)

                    if club.isAdmin && club.visibility == .invite {
                        codeRow
                    }

                    AppButton(role: .primary, controlSize: .large) {
                        shareLink()
                    } label: {
                        Label("Share invite", systemImage: "square.and.arrow.up")
                    }
                    .disabled(club.shareURL == nil)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .task { await loadFriendsForInvite() }
        .sheet(isPresented: $showShareSheet) {
            if let url = club.shareURL {
                ShareSheet(activityItems: ["Join \(club.name) on Dart Freak:", url])
            }
        }
        .confirmationDialog(
            sheetPending.map { dialog(for: $0).title } ?? "",
            isPresented: Binding(get: { sheetPending != nil }, set: { if !$0 { sheetPending = nil } }),
            titleVisibility: .visible,
            presenting: sheetPending
        ) { item in
            Button(dialog(for: item).button, role: dialog(for: item).isDestructive ? .destructive : nil) {
                perform(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text(dialog(for: item).message)
        }
        .alert(item: $sheetNotice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }

    /// Your DartFreak friends, each with Invite (or "In club" / "Invited"). They get a notification and
    /// a Join / No thanks card on their Clubs tab. Nobody is added without saying yes.
    @ViewBuilder
    private var friendsSection: some View {
        let memberIds = Set(members.map(\.id))
        VStack(alignment: .leading, spacing: 12) {
            Text("Your friends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            if !friendsLoaded {
                ProgressView()
                    .tint(AppColor.interactivePrimaryBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if friends.isEmpty {
                Text("When you have friends on DartFreak, you can invite them here with one tap.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    // People you can still invite first, then the ones already invited or in.
                    ForEach(friends.sorted { rank($0, memberIds) < rank($1, memberIds) }) { friend in
                        friendRow(friend, inClub: memberIds.contains(friend.id))
                    }
                }
            }
        }
    }

    private func rank(_ friend: User, _ memberIds: Set<UUID>) -> Int {
        if memberIds.contains(friend.id) { return 2 }
        if invitedIds.contains(friend.id) { return 1 }
        return 0
    }

    private func friendRow(_ friend: User, inClub: Bool) -> some View {
        HStack(spacing: 12) {
            AsyncAvatarImage(avatarURL: friend.avatarURL, size: 40)
            Text(friend.displayName)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if inClub {
                statusLabel("In club")
            } else if invitedIds.contains(friend.id) {
                statusLabel("Invited")
            } else {
                AppButton(role: .primary, controlSize: .small, isDisabled: invitingId != nil) {
                    inviteFriend(friend)
                } label: {
                    if invitingId == friend.id {
                        ProgressView().tint(AppColor.justWhite)
                    } else {
                        Text("Invite")
                    }
                }
                .fixedSize()
                .accessibilityLabel("Invite \(friend.displayName) to \(club.name)")
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(height: 60)
        .background(AppColor.inputBackground, in: Capsule())
    }

    private func loadFriendsForInvite() async {
        guard let userId = authService.currentUser?.id else { return }
        async let pending = try? clubsService.pendingInvitees(clubId: club.id)
        friends = (try? await friendsService.loadFriends(userId: userId)) ?? []
        invitedIds = await pending ?? []
        friendsLoaded = true
    }

    private func inviteFriend(_ friend: User) {
        guard invitingId == nil else { return }
        invitingId = friend.id
        Task {
            defer { invitingId = nil }
            do {
                let invited = try await clubsService.invite(clubId: club.id, clubName: club.name, userIds: [friend.id])
                if invited.contains(friend.id) {
                    invitedIds.insert(friend.id)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    // Already in, already invited by someone else, or no longer friends: refresh.
                    await loadFriendsForInvite()
                    if !invitedIds.contains(friend.id) {
                        sheetNotice = Notice(title: "Couldn't invite \(friend.displayName)", message: "Please try again.")
                    }
                }
            } catch {
                print("❌ [Clubs] Invite failed: \(error)")
                sheetNotice = Notice(title: "Couldn't invite \(friend.displayName)", message: "Check your connection and try again.")
            }
        }
    }

    /// The code, big, for "what's the code?" at the board. Tap to copy; ↻ makes a new one (after a warning).
    private var codeRow: some View {
        HStack(spacing: 12) {
            Button(action: copyCode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(justCopied ? "Copied" : "Code · tap to copy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(justCopied ? AppColor.interactiveSecondaryBackground : AppColor.textSecondary)
                    Text(ClubLink.displayCode(club.joinCode))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(AppColor.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Club code \(ClubLink.displayCode(club.joinCode)). Tap to copy.")

            Button {
                sheetPending = .newCode
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(AppColor.backgroundPrimary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .accessibilityLabel("Make a new code")
        }
        .padding(16)
        .background(AppColor.inputBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Opens the share sheet. Counts as sharing when it is opened, since the sheet does not say what the person picked.
    private func shareLink() {
        AnalyticsService.shared.logClub(.shared)
        showShareSheet = true
    }

    private func copyCode() {
        UIPasteboard.general.string = ClubLink.displayCode(club.joinCode)
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            // The same radio cards as Create a club: a choice, not a button.
            visibilityOption(.open, title: "Open", detail: "Anyone can find it and join")
            visibilityOption(.invite, title: "Invite-only", detail: "Hidden. People join with a link or code")
        }
    }

    private func visibilityOption(_ option: ClubVisibility, title: String, detail: String) -> some View {
        let selected = club.visibility == option
        return Button {
            setVisibility(option)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selected ? AppColor.interactivePrimaryBackground : AppColor.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                    Text(detail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.inputBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected ? AppColor.interactivePrimaryBackground : Color.clear, lineWidth: 2)
            )
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
            }

            // Only worth saying when someone here isn't your friend yet.
            if ClubText.hasNonFriends(in: members) {
                Text("Club members aren't friends automatically.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                HStack(spacing: 6) {
                    Text(isSelf ? "You" : member.displayName)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    if member.rank != .unranked {
                        Image(member.rank.iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(AppColor.brandPrimary)
                            .accessibilityLabel("Rank \(member.rank.displayName)")
                    }
                }

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
            // Outlined, not solid red: a column of red buttons read like part of joining.
            AppButton(role: .primaryOutline, controlSize: .small, isDisabled: addingId != nil) {
                addFriend(member)
            } label: {
                if addingId == member.id {
                    ProgressView().tint(AppColor.justWhite)
                } else {
                    Text("Add friend")
                }
            }
            .fixedSize()
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
            if member.relationship != .blocked {
                Button(role: .destructive) {
                    pending = .blockMember(member)
                } label: {
                    Label("Block \(member.displayName)", systemImage: "hand.raised")
                }
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
        case .blockMember(let member):
            return DialogText(
                title: BlockText.title(for: member.displayName),
                message: BlockText.message,
                button: "Block",
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
        case .blockMember(let member): block(member)
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

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { if toast == text { toast = nil } }
        }
    }

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
                try await friendsService.sendFriendRequest(userId: currentUserId, friendId: member.id, clubName: club.name)
                setRelationship(.requestSent, for: member.id)
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showToast("Friend request sent to \(member.displayName)")
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
                    sheetNotice = Notice(
                        title: "Can't switch to Open",
                        message: "There's already an Open club with this name and town, so this one stays Invite-only."
                    )
                default:
                    sheetNotice = Notice(title: "Couldn't change it", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Set visibility failed: \(error)")
                sheetNotice = Notice(title: "Couldn't change it", message: "Check your connection and try again.")
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
                    sheetNotice = Notice(title: "New code ready", message: "The old link and code don't work any more.")
                } else {
                    sheetNotice = Notice(title: "Couldn't make a new code", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Regenerate code failed: \(error)")
                sheetNotice = Notice(title: "Couldn't make a new code", message: "Check your connection and try again.")
            }
        }
    }

    /// Square-crops and shrinks the picked photo (512px JPEG), uploads it and sets it as the club photo.
    private func savePhoto(_ item: PhotosPickerItem) {
        guard !isSavingPhoto else { return }
        isSavingPhoto = true
        Task {
            defer { isSavingPhoto = false }
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = image.squareCropped().resized(toMaxDimension: 512).jpegData(compressionQuality: 0.8)
                else {
                    notice = Notice(title: "Couldn't use that photo", message: "Please try a different one.")
                    return
                }
                let saved = try await clubsService.setPhoto(clubId: club.id, jpeg: jpeg)
                if saved.result.isOk, let url = saved.url {
                    club = club.updating(imageURL: .some(url))
                } else {
                    notice = Notice(title: "Couldn't save the photo", message: saved.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Save photo failed: \(error)")
                connectionNotice("Couldn't save the photo")
            }
        }
    }

    private func removePhoto() {
        guard !isSavingPhoto else { return }
        isSavingPhoto = true
        Task {
            defer { isSavingPhoto = false }
            do {
                let result = try await clubsService.removePhoto(clubId: club.id)
                if result.isOk {
                    club = club.updating(imageURL: .some(nil))
                } else {
                    notice = Notice(title: "Couldn't remove the photo", message: result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Remove photo failed: \(error)")
                connectionNotice("Couldn't remove the photo")
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

    private func block(_ member: ClubMember) {
        guard let currentUserId = authService.currentUser?.id else { return }
        Task {
            do {
                try await friendsService.blockUser(userId: currentUserId, blockedUserId: member.id)
                setRelationship(.blocked, for: member.id)
                NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                notice = Notice(title: "\(member.displayName) blocked", message: "You can unblock them in Settings under Blocked Users.")
            } catch {
                print("❌ [Clubs] Block failed: \(error)")
                connectionNotice("Couldn't block \(member.displayName)")
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

    private func report(_ target: ClubsService.ReportTarget, id: UUID, title: String, reason: String? = nil) {
        guard !isReporting else { return }
        isReporting = true
        Task {
            defer { isReporting = false }
            do {
                let result = try await clubsService.report(target, id: id, reason: reason)
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
