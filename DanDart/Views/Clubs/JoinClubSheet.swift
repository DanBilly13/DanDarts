//
//  JoinClubSheet.swift
//  Dart Freak
//
//  Shown when someone opens a club link (or a code arrives after sign-in): names the club and
//  asks before joining, so nobody lands in a group by accident.
//

import SwiftUI

struct JoinClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var clubsService: ClubsService

    let code: String
    /// Called after a successful join, so the app can show the Clubs tab.
    let onJoined: () -> Void

    @State private var phase: Phase = .loading
    @State private var isJoining = false
    @State private var errorMessage: String?

    enum Phase: Equatable {
        case loading
        case found(ClubCodePreview)
        case notFound
        case failed
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            ProgressView()
                .tint(AppColor.interactivePrimaryBackground)
        case .found(let club):
            found(club)
        case .notFound:
            message(
                icon: "questionmark.circle",
                title: "That code doesn't work",
                detail: ClubActionResult.invalidCode.userMessage ?? "",
                primary: ("OK", { dismiss() })
            )
        case .failed:
            message(
                icon: "wifi.exclamationmark",
                title: "Couldn't check the code",
                detail: "Check your connection and try again.",
                primary: ("Try again", { Task { await load() } }),
                secondary: ("Not now", { dismiss() })
            )
        }
    }

    // MARK: - Club found

    private func found(_ club: ClubCodePreview) -> some View {
        VStack(spacing: 16) {
            ClubTile(id: club.id, name: club.name, size: 72)

            VStack(spacing: 6) {
                Text(club.isMember ? "You're already in" : "Join this club?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)

                Text(club.name)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(ClubText.subtitle(town: club.town, memberCount: club.memberCount))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }

            ClubVisibilityChip(visibility: club.visibility)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                if club.isMember {
                    AppButton(role: .primary, controlSize: .regular) {
                        dismiss()
                    } label: {
                        Text("OK")
                    }
                } else {
                    AppButton(role: .primary, controlSize: .regular, isDisabled: isJoining) {
                        join()
                    } label: {
                        if isJoining {
                            ProgressView().tint(AppColor.justWhite)
                        } else {
                            Text("Join club")
                        }
                    }

                    AppButton(role: .secondaryOutline, controlSize: .regular, isDisabled: isJoining) {
                        dismiss()
                    } label: {
                        Text("Not now")
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func message(
        icon: String,
        title: String,
        detail: String,
        primary: (String, () -> Void),
        secondary: (String, () -> Void)? = nil
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(AppColor.textSecondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                Text(detail)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                AppButton(role: .primary, controlSize: .regular, action: primary.1) {
                    Text(primary.0)
                }
                if let secondary {
                    AppButton(role: .secondaryOutline, controlSize: .regular, action: secondary.1) {
                        Text(secondary.0)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func load() async {
        phase = .loading
        do {
            if let club = try await clubsService.preview(code: code) {
                phase = .found(club)
            } else {
                phase = .notFound
            }
        } catch {
            guard !Task.isCancelled else { return }
            print("❌ [Clubs] Code preview failed: \(error)")
            phase = .failed
        }
    }

    private func join() {
        guard !isJoining else { return }
        isJoining = true
        errorMessage = nil
        Task {
            defer { isJoining = false }
            do {
                let outcome = try await clubsService.joinClub(code: code)
                switch outcome.result {
                case .ok, .alreadyMember:
                    dismiss()
                    onJoined()
                default:
                    errorMessage = outcome.result.userMessage ?? "Please try again."
                }
            } catch {
                print("❌ [Clubs] Join from link failed: \(error)")
                errorMessage = "Check your connection and try again."
            }
        }
    }
}
