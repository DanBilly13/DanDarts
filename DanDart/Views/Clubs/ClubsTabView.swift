//
//  ClubsTabView.swift
//  Dart Freak
//
//  The Clubs tab: the clubs the signed-in user belongs to, with ways to find, create or join one.
//

import SwiftUI

struct ClubsTabView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var clubsService: ClubsService
    @ObservedObject private var entitlements = EntitlementStore.shared

    @State private var clubs: [Club] = []
    @State private var hasLoaded = false
    @State private var loadFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .refreshable { await loadClubs() }
        .background(AppColor.backgroundPrimary)
        .task { await loadClubs() }
        .onReceive(clubsService.$myClubsVersion.dropFirst()) { _ in
            Task { await loadClubs() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded && !loadFailed {
            ProgressView()
                .tint(AppColor.interactivePrimaryBackground)
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else if loadFailed && clubs.isEmpty {
            failedState
        } else if clubs.isEmpty {
            emptyState
        } else {
            clubList
            actions
        }
    }

    // MARK: - States

    private var clubList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My clubs")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)

            VStack(spacing: 12) {
                ForEach(clubs) { club in
                    Button {
                        guard entitlements.requireAccess(to: .clubs) else { return }
                        router.push(.clubDetail(club))
                    } label: {
                        ClubRow(club: club)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            EmptyState(
                // Placeholder art until Clubs has its own empty-state illustration.
                imageName: "empty-remote",
                title: "Join your darts club",
                message: "Find your pub team or darts club, or start one for your mates.",
                actionTitle: "Find a club",
                action: { router.push(.findClub) }
            )

            haveACodeButton
        }
    }

    private var failedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(AppColor.textSecondary)

            Text("Couldn't load your clubs")
                .font(.headline)
                .foregroundColor(AppColor.textPrimary)

            Text("Check your connection and try again.")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)

            AppButton(role: .primary, controlSize: .regular) {
                Task { await loadClubs() }
            } label: {
                Text("Try again")
            }
            .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var actions: some View {
        VStack(spacing: 14) {
            AppButton(role: .primary, controlSize: .large) {
                router.push(.findClub)
            } label: {
                Label("Find a club", systemImage: "magnifyingglass")
            }

            haveACodeButton
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    /// The code box lives on the Find screen, so this opens it.
    private var haveACodeButton: some View {
        Button {
            router.push(.findClub)
        } label: {
            Text("Have a code?")
                .font(.system(size: 15, weight: .medium))
                .underline()
                .foregroundColor(AppColor.textPrimary)
                .frame(minHeight: 44)
        }
    }

    // MARK: - Loading

    private func loadClubs() async {
        do {
            clubs = try await clubsService.myClubs()
            loadFailed = false
        } catch {
            // Leaving the tab or a cancelled refresh isn't a failure; the task runs again on return.
            guard !Task.isCancelled else { return }
            // Keep what is already on screen if a refresh fails.
            loadFailed = true
            print("❌ [Clubs] Failed to load my clubs: \(error)")
        }
        hasLoaded = true
    }
}
