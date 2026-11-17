//
//  TrialBanner.swift
//  DanDart
//
//  Only in the last 5 days of the trial. Never a pop-up.
//

import SwiftUI

struct TrialBanner: View {
    @ObservedObject private var store = EntitlementStore.shared
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        if case .trial(let daysLeft) = store.state, daysLeft <= 5 {
            Button {
                store.showPaywall(.trialEnding(daysLeft: daysLeft))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text(daysLeft == 1 ? "1 day left of your free trial" : "\(daysLeft) days left of your free trial")
                    Spacer()
                    Text("Get Pro").fontWeight(.semibold)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.justWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColor.interactivePrimaryBackground)
            }
            .buttonStyle(.plain)
        }
    }
}
