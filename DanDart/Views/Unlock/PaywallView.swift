//
//  PaywallView.swift
//  DanDart
//
//  The one unlock screen. Shown from any locked feature and once when the trial ends.
//

import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason
    @ObservedObject private var store = EntitlementStore.shared
    @State private var finishedFirstProductLoad = false
    @State private var isRestoring = false

    private let benefits: [(icon: String, text: String)] = [
        ("target", "Cricket, Halve-It, Knockout, Sudden Death and Killer"),
        ("network", "Remote matches with voice chat"),
        ("person.2.fill", "Head-to-head records with your friends"),
        ("person.3.fill", "Clubs"),
        ("chart.xyaxis.line", "Your full stats and every match in detail"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(reason.headline)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textPrimary)
                    Text(reason.subheadline)
                        .font(.system(size: 15))
                        .foregroundColor(AppColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(benefits, id: \.text) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: benefit.icon)
                                .frame(width: 24)
                                .foregroundColor(AppColor.interactivePrimaryBackground)
                            Text(benefit.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(AppColor.textPrimary)
                        }
                    }
                }

                Text("One payment. No subscription. Your games and stats are always saved, free or not.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColor.textSecondary)

                AppButton(role: .primary, controlSize: .large) {
                    Task { await store.purchase() }
                } label: {
                    if store.isPurchasing || (store.product == nil && store.isLoadingProduct) {
                        ProgressView()
                    } else if let product = store.product {
                        Text("Unlock for \(product.displayPrice)")
                    } else {
                        Text("Unlock DartFreak Full")
                    }
                }
                .disabled(store.product == nil || store.isPurchasing)

                if productUnavailable {
                    VStack(spacing: 8) {
                        Text("Couldn't reach the App Store.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.textSecondary)
                        Button("Try again") {
                            Task { await store.loadProduct() }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                    }
                    .frame(maxWidth: .infinity)
                }

                if let message = store.purchaseMessage {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    isRestoring = true
                    Task {
                        await store.restore()
                        isRestoring = false
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Text("Restore Purchases")
                    }
                }
                .disabled(isRestoring || store.isPurchasing)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .onAppear {
            store.purchaseMessage = nil
            if reason == .trialEnded { store.markTrialEndedNoticeShown() }
        }
        .task {
            // The price is loaded once at refresh; if that failed, try again here.
            if store.product == nil { await store.loadProduct() }
            finishedFirstProductLoad = true
        }
    }

    private var productUnavailable: Bool {
        finishedFirstProductLoad && store.product == nil && !store.isLoadingProduct
    }
}
