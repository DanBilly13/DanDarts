//
//  ProLock.swift
//  DanDart
//
//  How a stats screen looks on the free tier: section titles stay sharp so you can see what's
//  there, only the numbers and charts are blurred, and the screen shows one calm Get Pro prompt.
//
//  Usage: put `.proLocked(.fullStats)` on the screen's stats container, mark each chart's data
//  with `.proLockedData()`, and pin `ProPanel(feature:)` above the stats as a section header.
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

/// While the Get Pro panel is pinned, a see-through title bar would let the stats show above it,
/// so the bar goes solid in the page colour. Unlocked screens keep the normal bar.
private struct ProPanelBar: ViewModifier {
    let feature: PaidFeature
    let color: Color
    @ObservedObject private var store = EntitlementStore.shared

    func body(content: Content) -> some View {
        let locked = !store.canUse(feature)
        content
            .toolbarBackground(color, for: .navigationBar)
            .toolbarBackground(locked ? .visible : .automatic, for: .navigationBar)
    }
}

extension View {
    /// Use on a screen that pins a `ProPanel`: keeps the title bar solid while it shows.
    func proPanelBar(_ feature: PaidFeature, color: Color = AppColor.surfacePrimary) -> some View {
        modifier(ProPanelBar(feature: feature, color: color))
    }

    /// Marks this as the data part of a stat (numbers, bars, charts): blurred when locked.
    func proLockedData() -> some View {
        modifier(ProLockedData())
    }

    /// Locks every `.proLockedData()` inside when the user can't use `feature`.
    func proLocked(_ feature: PaidFeature) -> some View {
        modifier(ProLocked(feature: feature))
    }
}

/// The one Get Pro panel on a locked stats screen: a red card with a short headline, one line and
/// the white Get Pro button. Use it as a pinned section header so it sticks under the navigation
/// bar and the blurred stats scroll behind it. Draws nothing when unlocked.
struct ProPanel: View {
    let feature: PaidFeature
    /// The page colour, so the band behind the card hides what scrolls under it.
    var background: Color = AppColor.surfacePrimary
    @ObservedObject private var store = EntitlementStore.shared

    var body: some View {
        if !store.canUse(feature) {
            VStack(spacing: 8) {
                Text(feature.proHeadline)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(AppColor.justWhite)
                Text(feature.proBody)
                    .font(.system(.subheadline))
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.justWhite.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                AppButton(role: .pro, controlSize: .regular) {
                    store.showPaywall(.feature(feature))
                } label: {
                    Text("Get Pro")
                }
                .frame(maxWidth: 180)
                .padding(.top, 8)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .background(
                AppColor.interactivePrimaryBackground,
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .padding(.vertical, 12)
            .background {
                // A solid band of page colour behind the card (edge to edge), then a short fade,
                // so the blurred stats disappear neatly behind it instead of showing round the corners.
                VStack(spacing: 0) {
                    background
                    LinearGradient(colors: [background, background.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 16)
                }
                .padding(.horizontal, -16)
                .padding(.bottom, -16)
                .allowsHitTesting(false)
            }
        }
    }
}
