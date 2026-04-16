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
    let secondaryMessage: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        imageName: String,
        title: String,
        message: String,
        secondaryMessage: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.imageName = imageName
        self.title = title
        self.message = message
        self.secondaryMessage = secondaryMessage
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
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                if let secondaryMessage {
                    Text(secondaryMessage)
                        .font(.system(.footnote, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
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
        secondaryMessage: "You can invite people by handle or name.",
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
        message: "Challenge a friend to a remote 301 or 501",
        secondaryMessage: "Matches expire if not joined within 5 minutes",
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
