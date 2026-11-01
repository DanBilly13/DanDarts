//
//  FindClubView.swift
//  Dart Freak
//
//  Find a club: search Open clubs by name or town and join with one tap, offer to create one
//  when nothing fits, or join any club (Open or Invite-only) with its code.
//

import SwiftUI

struct FindClubView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var clubsService: ClubsService

    @State private var query = ""
    @State private var joinedIds: Set<UUID> = []
    @State private var joiningId: UUID?
    @State private var code = ""
    @State private var isJoiningByCode = false
    @State private var notice: Notice?
    @FocusState private var searchFocused: Bool

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        var leavesScreen = false
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchableQuery: Bool {
        trimmedQuery.count >= ClubsService.minimumSearchLength
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                searchField
                results
                codeSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColor.backgroundPrimary)
        .navigationTitle("Find a club")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { clubsService.cancelSearch() }
        .onDisappear { clubsService.cancelSearch() }
        .onChange(of: query) { _, newValue in
            clubsService.search(query: newValue)
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

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            TextField("Search by club name or town", text: $query)
                .font(.system(size: 17))
                .foregroundColor(AppColor.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($searchFocused)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColor.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var results: some View {
        if !hasSearchableQuery {
            VStack(spacing: 8) {
                Text("Search for your pub team or darts club")
                    .font(.subheadline)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if clubsService.isSearching {
            ProgressView()
                .tint(AppColor.interactivePrimaryBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if clubsService.searchFailed {
            VStack(spacing: 8) {
                Text("Couldn't search")
                    .font(.headline)
                    .foregroundColor(AppColor.textPrimary)
                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if clubsService.searchResults.isEmpty {
                    Text("No open clubs match “\(trimmedQuery)”")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                } else {
                    Text("Open clubs matching “\(trimmedQuery)”")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                }

                VStack(spacing: 12) {
                    ForEach(clubsService.searchResults) { club in
                        ClubSearchRow(
                            club: club,
                            isJoined: joinedIds.contains(club.id),
                            isJoining: joiningId == club.id,
                            onJoin: { join(club) }
                        )
                    }

                    createRow
                }
            }
        }
    }

    private var createRow: some View {
        Button {
            router.push(.createClub(name: trimmedQuery))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                Text("Create “\(trimmedQuery)” as a new club")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .overlay(
                Capsule().strokeBorder(AppColor.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
            .contentShape(Capsule())
        }
    }

    // MARK: - Code

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Have a code?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            HStack(spacing: 10) {
                TextField("Enter club code", text: $code)
                    .font(.system(size: 17, design: .monospaced))
                    .foregroundColor(AppColor.textPrimary)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.join)
                    .onSubmit(joinByCode)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(AppColor.inputBackground)
                    .clipShape(Capsule())

                AppButton(
                    role: .secondaryOutline,
                    controlSize: .regular,
                    isDisabled: isJoiningByCode || code.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: joinByCode
                ) {
                    if isJoiningByCode {
                        ProgressView()
                    } else {
                        Text("Join")
                    }
                }
                .frame(width: 84)
            }

            Text("Codes work for Open and Invite-only clubs.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Actions

    private func join(_ club: ClubSearchResult) {
        guard joiningId == nil else { return }
        joiningId = club.id
        Task {
            defer { joiningId = nil }
            do {
                let outcome = try await clubsService.joinClub(clubId: club.id)
                switch outcome.result {
                case .ok, .alreadyMember:
                    joinedIds.insert(club.id)
                default:
                    notice = Notice(title: "Couldn't join", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Join failed: \(error)")
                notice = Notice(title: "Couldn't join", message: "Check your connection and try again.")
            }
        }
    }

    private func joinByCode() {
        guard !isJoiningByCode else { return }
        guard let clean = ClubLink.normalizedCode(code) else {
            notice = Notice(title: "Check the code", message: ClubActionResult.invalidCode.userMessage ?? "")
            return
        }
        isJoiningByCode = true
        searchFocused = false
        Task {
            defer { isJoiningByCode = false }
            do {
                let outcome = try await clubsService.joinClub(code: clean)
                switch outcome.result {
                case .ok:
                    code = ""
                    notice = Notice(title: "You're in", message: "You've joined the club.", leavesScreen: true)
                case .alreadyMember:
                    notice = Notice(title: "Already in", message: outcome.result.userMessage ?? "", leavesScreen: true)
                default:
                    notice = Notice(title: "Couldn't join", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Join by code failed: \(error)")
                notice = Notice(title: "Couldn't join", message: "Check your connection and try again.")
            }
        }
    }
}
