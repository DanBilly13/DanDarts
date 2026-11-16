//
//  PaywallSheet.swift
//  DanDart
//
//  Presents the unlock screen from EntitlementStore.shared.paywall. A view can only present
//  one sheet at a time, so every full-screen cover or sheet that contains locked UI needs its
//  own .paywallSheet(), and the view underneath turns its copy off while that cover is up.
//

import SwiftUI

private struct PaywallSheetModifier: ViewModifier {
    let isEnabled: Bool
    @ObservedObject private var store = EntitlementStore.shared

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { isEnabled ? store.paywall : nil },
            set: { store.paywall = $0 }
        )) { reason in
            PaywallView(reason: reason)
                .modernSheet(title: "DartFreak Full", detents: [.large], background: AppColor.surfacePrimary)
        }
    }
}

extension View {
    /// Shows the unlock screen when something asks for it. Pass `isEnabled: false` while a
    /// child cover or sheet (with its own `.paywallSheet()`) is on screen.
    func paywallSheet(isEnabled: Bool = true) -> some View {
        modifier(PaywallSheetModifier(isEnabled: isEnabled))
    }
}
