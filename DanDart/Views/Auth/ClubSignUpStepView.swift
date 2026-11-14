//
//  ClubSignUpStepView.swift
//  Dart Freak
//
//  The optional "Part of a club or team?" step for new accounts, between profile setup and the
//  permissions screen. Search and join, create a club, or enter a code; Continue and Skip both
//  move on, so nobody has to join anything.
//

import SwiftUI

struct ClubSignUpStepView: View {
    @EnvironmentObject private var authService: AuthService
    @StateObject private var clubsService = ClubsService()

    @State private var query = ""
    @State private var joinedIds: Set<UUID> = []
    @State private var joiningId: UUID?
    @State private var showCodeField = false
    @State private var code = ""
    @State private var isJoiningByCode = false
    @State private var isCreating = false
    @State private var showCreateConfirmation = false
    @State private var duplicateClubId: UUID?
    @State private var notice: Notice?
    @FocusState private var searchFocused: Bool

    private struct Notice: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasSearchableQuery: Bool {
        trimmedQuery.count >= ClubsService.minimumSearchLength
    }

    /// The typed text, cut to the length the database accepts, when it could be a club name.
    private var nameToCreate: String? {
        let name = CreateClubView.clamped(trimmedQuery, to: CreateClubView.maxNameLength)
        return CreateClubView.isValidName(name) ? name : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    searchField
                    results
                    codeSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 12) {
                AppButton(role: .primary, controlSize: .large, action: finish) {
                    Text("Continue")
                }
                Button(action: finish) {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(AppColor.backgroundPrimary)
        .onChange(of: query) { _, newValue in
            clubsService.search(query: newValue)
        }
        .onDisappear { clubsService.cancelSearch() }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog(
            "Create “\(nameToCreate ?? "")”?",
            isPresented: $showCreateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Create club") { createClub() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Anyone will be able to find it in search and join. You can change that later in the club's settings.")
        }
        .alert("That club already exists", isPresented: Binding(
            get: { duplicateClubId != nil },
            set: { if !$0 { duplicateClubId = nil } }
        )) {
            Button("Join it") { joinExisting() }
            Button("Cancel", role: .cancel) { duplicateClubId = nil }
        } message: {
            Text("There's already an Open club with that name and town. Do you want to join it instead?")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Part of a club or team?")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
            Text("Find your club to see which of your mates are already here. You can skip this and do it later.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            TextField("Search by club name or town", text: $query, prompt: Text("Search by club name or town").foregroundColor(AppColor.textSecondary))
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
            EmptyView()
        } else if clubsService.isSearching {
            ProgressView()
                .tint(AppColor.interactivePrimaryBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if clubsService.searchFailed {
            Text("Couldn't search. Check your connection and try again.")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            VStack(spacing: 12) {
                ForEach(clubsService.searchResults) { club in
                    ClubSearchRow(
                        club: club,
                        isJoined: joinedIds.contains(club.id),
                        isJoining: joiningId == club.id,
                        onJoin: { join(club) }
                    )
                }

                if let name = nameToCreate {
                    createRow(name: name)
                }
            }
        }
    }

    private func createRow(name: String) -> some View {
        Button {
            searchFocused = false
            showCreateConfirmation = true
        } label: {
            HStack(spacing: 10) {
                if isCreating {
                    ProgressView().tint(AppColor.interactivePrimaryBackground)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                }
                Text("Create “\(name)” as a new club")
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
        .disabled(isCreating)
    }

    private var codeSection: some View {
        VStack(spacing: 12) {
            if showCodeField {
                HStack(spacing: 10) {
                    TextField("Enter club code", text: $code, prompt: Text("Enter club code").foregroundColor(AppColor.textSecondary))
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
            } else {
                Button {
                    withAnimation { showCodeField = true }
                } label: {
                    Text("Have a code?")
                        .font(.system(size: 15, weight: .medium))
                        .underline()
                        .foregroundColor(AppColor.textPrimary)
                        .frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func finish() {
        clubsService.cancelSearch()
        authService.completeClubOnboarding()
    }

    private func join(_ club: ClubSearchResult) {
        guard joiningId == nil else { return }
        joiningId = club.id
        Task {
            defer { joiningId = nil }
            do {
                let outcome = try await clubsService.joinClub(clubId: club.id, source: .signup)
                switch outcome.result {
                case .ok, .alreadyMember:
                    joinedIds.insert(club.id)
                default:
                    notice = Notice(title: "Couldn't join", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Sign-up join failed: \(error)")
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
        Task {
            defer { isJoiningByCode = false }
            do {
                let outcome = try await clubsService.joinClub(code: clean, source: .signup)
                switch outcome.result {
                case .ok:
                    code = ""
                    showCodeField = false
                    notice = Notice(title: "You're in", message: "You've joined the club.")
                case .alreadyMember:
                    notice = Notice(title: "Already in", message: outcome.result.userMessage ?? "")
                default:
                    notice = Notice(title: "Couldn't join", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Sign-up join by code failed: \(error)")
                notice = Notice(title: "Couldn't join", message: "Check your connection and try again.")
            }
        }
    }

    private func createClub() {
        guard let name = nameToCreate, !isCreating else { return }
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                let outcome = try await clubsService.createClub(name: name, town: nil, visibility: .open)
                switch outcome.result {
                case .ok:
                    if let id = outcome.clubId { joinedIds.insert(id) }
                    query = ""
                    notice = Notice(title: "Club created", message: "“\(name)” is ready. You can share it from the Clubs tab.")
                case .duplicate:
                    if let existing = outcome.clubId {
                        duplicateClubId = existing
                    } else {
                        notice = Notice(title: "Couldn't create the club", message: outcome.result.userMessage ?? "Please try again.")
                    }
                default:
                    notice = Notice(title: "Couldn't create the club", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Sign-up create failed: \(error)")
                notice = Notice(title: "Couldn't create the club", message: "Check your connection and try again.")
            }
        }
    }

    private func joinExisting() {
        guard let id = duplicateClubId else { return }
        duplicateClubId = nil
        Task {
            do {
                let outcome = try await clubsService.joinClub(clubId: id, source: .signup)
                switch outcome.result {
                case .ok, .alreadyMember:
                    joinedIds.insert(id)
                default:
                    notice = Notice(title: "Couldn't join", message: outcome.result.userMessage ?? "Please try again.")
                }
            } catch {
                print("❌ [Clubs] Sign-up join existing failed: \(error)")
                notice = Notice(title: "Couldn't join", message: "Check your connection and try again.")
            }
        }
    }
}
