import SwiftUI
import UIKit

struct InviteClaimView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var inviteService = InviteService()

    let token: String

    @State private var isClaiming: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 56, weight: .light))
                    .foregroundColor(AppColor.textSecondary)

                VStack(spacing: 8) {
                    Text("Connect with a friend")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)

                    Text("This will send a friend request.")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if let successMessage {
                    Text(successMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    AppButton(role: .primary, controlSize: .regular, isDisabled: isClaiming) {
                        claim()
                    } label: {
                        if isClaiming {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(AppColor.interactivePrimaryForeground)
                                Text("Sending…")
                            }
                        } else {
                            Text("Send Friend Request")
                        }
                    }

                    AppButton(role: .secondary, controlSize: .regular, isDisabled: isClaiming) {
                        dismiss()
                    } label: {
                        Text("Not Now")
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColor.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Invite")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.interactivePrimaryBackground)
                }
            }
        }
    }

    private func claim() {
        isClaiming = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                let result = try await inviteService.claimInvite(token: token)

                switch result {
                case .claimed:
                    let successFeedback = UINotificationFeedbackGenerator()
                    successFeedback.notificationOccurred(.success)

                    successMessage = "Friend request sent"
                    NotificationCenter.default.post(name: NSNotification.Name("FriendRequestsChanged"), object: nil)

                    try? await Task.sleep(nanoseconds: 700_000_000)
                    dismiss()

                case .alreadyFriends:
                    errorMessage = "You are already friends."
                case .pendingExists:
                    errorMessage = "A friend request is already pending."
                case .blocked:
                    errorMessage = "You can’t connect with this user."
                case .expired:
                    errorMessage = "This invite link has expired."
                case .alreadyUsed:
                    errorMessage = "This invite link has already been used."
                case .selfInvite:
                    errorMessage = "You can’t use your own invite link."
                case .notAuthenticated:
                    errorMessage = "Please sign in to accept this invite."
                case .invalid:
                    errorMessage = "Invalid invite link."
                case .unknown(let message):
                    errorMessage = message
                }

                isClaiming = false
            } catch {
                isClaiming = false
                errorMessage = "Failed to claim invite. Please try again."
                print("❌ Claim invite error: \(error)")

                let errorFeedback = UINotificationFeedbackGenerator()
                errorFeedback.notificationOccurred(.error)
            }
        }
    }
}
