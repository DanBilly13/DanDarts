//
//  ProLock.swift
//  DanDart
//
//  How a stats screen looks on the free tier: section titles stay sharp so you can see what's
//  there, only the numbers and charts are blurred, and the screen shows one calm Get Pro prompt.
//
//  Usage: put `.proLocked(.fullStats)` on the screen's stats container, mark each chart's data
//  with `.proLockedData()`, and show `ProPrompt(feature:)` once where it reads best.
//

import SwiftUI

private struct ProDataLockedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside a stats area the user can't see on the free tier.
    var proDataLocked: Bool {
        get { self[ProDataLockedKey.self] }
        set { self[ProDataLockedKey.self] = newValue }
    }
}

private struct ProLockedData: ViewModifier {
    @Environment(\.proDataLocked) private var locked

    func body(content: Content) -> some View {
        if locked {
            content
                .blur(radius: 9)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            content
        }
    }
}

private struct ProLocked: ViewModifier {
    let feature: PaidFeature
    @ObservedObject private var store = EntitlementStore.shared

    func body(content: Content) -> some View {
        content.environment(\.proDataLocked, !store.canUse(feature))
    }
}

extension View {
    /// Marks this as the data part of a stat (numbers, bars, charts): blurred when locked.
    func proLockedData() -> some View {
        modifier(ProLockedData())
    }

    /// Locks every `.proLockedData()` inside when the user can't use `feature`.
    func proLocked(_ feature: PaidFeature) -> some View {
        modifier(ProLocked(feature: feature))
    }
}

/// The one Get Pro prompt on a locked stats screen. Draws nothing when the feature is unlocked.
struct ProPrompt: View {
    let feature: PaidFeature
    @ObservedObject private var store = EntitlementStore.shared

    var body: some View {
        if !store.canUse(feature) {
            HStack(spacing: 14) {
                Text(feature.lockedMessage)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                AppButton(role: .primary, controlSize: .small, compact: true) {
                    store.showPaywall(.feature(feature))
                } label: {
                    Text("Get Pro").bold()
                }
                .fixedSize()
            }
            .padding(16)
            .background(AppColor.inputBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
