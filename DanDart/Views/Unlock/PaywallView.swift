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
                    Text(headline)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(AppColor.textPrimary)
                    Text(subheadline)
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
                    if store.isPurchasing {
                        ProgressView()
                    } else if let product = store.product {
                        Text("Unlock for \(product.displayPrice)")
                    } else {
                        Text("Unlock DartFreak Full")
                    }
                }
                .disabled(store.product == nil || store.isPurchasing)

                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
    }

    private var headline: String {
        switch reason {
        case .trialEnded: return "Your free 4 weeks are up"
        case .feature(let feature): return feature.lockedTitle
        }
    }

    private var subheadline: String {
        switch reason {
        case .trialEnded:
            return "301, 501 and your friends stay free forever. Unlock DartFreak Full to keep everything else."
        case .feature(let feature):
            return feature.lockedMessage
        }
    }
}
