//
//  EmptyState.swift
//  DanDart
//
//  Created by Billingham Daniel on 2026-03-28.


import SwiftUI

struct EmptyState: View {
    let imageName: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        imageName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 100)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame( height: 120)

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                AppButton(role: .primary, controlSize: .regular) {
                    action()
                } label: {
                    Text(actionTitle)
                }
                .frame(maxWidth: 280)
                .padding(.top, 8)
            }

            Spacer()
                .frame(height: 100)
        }
        .frame(maxWidth: .infinity)
    }
}



#Preview("Friends Action") {
    EmptyState(
        imageName: "empty-friends",
        title: "No friends yet",
        message: "Search for friends to add them",
        actionTitle: "Find Friends",
        action: {}
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("Remote Example") {
    EmptyState(
        imageName: "empty-remote",
        title: "No remote matches",
        message: "No pending or upcoming challenges",
        actionTitle: "Challenge a Friend",
        action: {}
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}

#Preview("History Example") {
    EmptyState(
        imageName: "empty-history",
        title: "No history yet",
        message: "Your match history will show here"
    )
    .padding()
    .background(AppColor.backgroundPrimary)
}
