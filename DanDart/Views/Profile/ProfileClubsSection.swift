//
//  ProfileClubsSection.swift
//  Dart Freak
//
//  "Clubs" at the bottom of your Profile: the clubs you're in, the same rows as the Clubs tab.
//  Not a stat, so it's never blurred on the free tier; opening a club still needs Pro.
//

import SwiftUI

struct ProfileClubsSection: View {
    /// Close Profile and open this club on the Clubs tab.
    let onOpenClub: (Club) -> Void
    /// Close Profile and open Find a club.
    let onFindClub: () -> Void

    @StateObject private var clubsService = ClubsService()
    @State private var clubs: [Club] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clubs")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColor.textSecondary)

            if !loaded {
                ProgressView()
                    .tint(AppColor.interactivePrimaryBackground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if clubs.isEmpty {
                HStack(spacing: 8) {
                    Text("Not in a club yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                    Spacer()
                    Button("Find a club", action: onFindClub)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                }
                .frame(minHeight: 44)
            } else {
                VStack(spacing: 10) {
                    ForEach(clubs) { club in
                        Button {
                            guard EntitlementStore.shared.requireAccess(to: .clubs) else { return }
                            onOpenClub(club)
                        } label: {
                            ClubRow(club: club)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task {
            clubs = (try? await clubsService.myClubs()) ?? []
            loaded = true
        }
    }
}
