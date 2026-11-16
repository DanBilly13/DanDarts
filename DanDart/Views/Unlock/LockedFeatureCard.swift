//
//  LockedFeatureCard.swift
//  DanDart
//
//  "Show it, don't hide it": locked content is drawn blurred behind this card.
//

import SwiftUI

struct LockedFeatureCard: View {
    let feature: PaidFeature
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColor.justWhite)
            Text(feature.lockedTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColor.textPrimary)
            Text(feature.lockedMessage)
                .font(.system(size: 14))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            AppButton(role: .primary, controlSize: .small, action: onUnlock) {
                Text("Unlock DartFreak Full")
            }
        }
        .padding(20)
        .frame(maxWidth: 320)
        .background(AppColor.surfacePrimary.opacity(0.95))
        .cornerRadius(16)
    }
}

private struct LockedOverlay: ViewModifier {
    let feature: PaidFeature
    @ObservedObject private var store = EntitlementStore.shared

    func body(content: Content) -> some View {
        if store.canUse(feature) {
            content
        } else {
            content
                .blur(radius: 8)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay {
                    LockedFeatureCard(feature: feature) {
                        store.showPaywall(.feature(feature))
                    }
                }
        }
    }
}

extension View {
    /// Blurs this view and puts an unlock card on top when `feature` is locked.
    func lockedOverlay(_ feature: PaidFeature) -> some View {
        modifier(LockedOverlay(feature: feature))
    }
}
