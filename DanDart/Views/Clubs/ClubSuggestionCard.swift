//
//  ClubSuggestionCard.swift
//  Dart Freak
//
//  One row of "People from your clubs" in the Friends tab: who, which club you share, an Add
//  button that sends a normal friend request, and a small cross that hides them for good.
//

import SwiftUI

struct ClubSuggestionCard: View {
    let suggestion: ClubSuggestion
    let isAdding: Bool
    let onAdd: () -> Void
    let onDismiss: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                AsyncAvatarImage(avatarURL: suggestion.avatarURL, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.displayName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 5) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                        Text(ClubText.suggestionSubtitle(clubName: suggestion.clubName, sharedCount: suggestion.sharedCount))
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                AppButton(role: .primary, controlSize: .small, isDisabled: isAdding, action: onAdd) {
                    if isAdding {
                        ProgressView().tint(AppColor.justWhite)
                    } else {
                        Text("Add")
                    }
                }
                .frame(width: 64)
                .accessibilityLabel("Add \(suggestion.displayName) as a friend")

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAdding)
                .accessibilityLabel("Hide suggestion for \(suggestion.displayName)")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .frame(height: 80)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.inputBackground)
        .clipShape(Capsule())
        .contextMenu {
            Button(role: .destructive, action: onBlock) {
                Label("Block \(suggestion.displayName)", systemImage: "hand.raised")
            }
        }
    }
}

/// How many suggestions the Friends tab shows before "See all", and what shows when.
enum ClubSuggestionList {
    static let collapsedCount = 3

    static func visible(_ suggestions: [ClubSuggestion], showAll: Bool) -> [ClubSuggestion] {
        showAll ? suggestions : Array(suggestions.prefix(collapsedCount))
    }

    /// Puts a suggestion back where it was after a failed dismiss.
    static func restoring(_ suggestion: ClubSuggestion, at index: Int, into suggestions: [ClubSuggestion]) -> [ClubSuggestion] {
        guard !suggestions.contains(where: { $0.id == suggestion.id }) else { return suggestions }
        var copy = suggestions
        copy.insert(suggestion, at: min(max(index, 0), copy.count))
        return copy
    }
}
