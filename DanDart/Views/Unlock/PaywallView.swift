//
//  PaywallView.swift
//  DanDart
//
//  The one unlock screen. Shown from any locked feature and once when the trial ends.
//  Kept deliberately quiet: the app icon, one headline, one line, what you get, the price.
//  The feature that brought the user here is highlighted in the list rather than described twice.
//

import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason
    @ObservedObject private var store = EntitlementStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var showStoreUnavailable = false

    private struct Benefit: Identifiable {
        let icon: String
        let title: String
        let detail: String
        let features: Set<PaidFeature>
        var id: String { title }
    }

    // Icons match the app's own tabs (Games, Remote, Friends, Clubs).
    private let benefits: [Benefit] = [
        Benefit(icon: "target", title: "Five more games",
                detail: "Cricket, Halve-It, Knockout, Sudden Death and Killer.",
                features: [.partyGames]),
        Benefit(icon: "network", title: "Remote matches",
                detail: "Play your mates live, with voice chat.",
                features: [.remoteMatches]),
        Benefit(icon: "person.2.fill", title: "Head-to-head",
                detail: "See who's really winning.",
                features: [.headToHead]),
        Benefit(icon: "shield.fill", title: "Clubs",
                detail: "Play with your club, all in one place.",
                features: [.clubs]),
        Benefit(icon: "chart.xyaxis.line", title: "Every stat",
                detail: "Trends, personal bests and every match in detail.",
                features: [.fullStats, .fullHistory]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                header
                benefitList
            }
            .padding(.horizontal, 24)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .accessibilityLabel("Close")
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
        .safeAreaInset(edge: .bottom) { purchaseArea }
        .alert("App Store unavailable", isPresented: $showStoreUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again in a moment.")
        }
        .onAppear {
            store.purchaseMessage = nil
            if reason == .trialEnded { store.markTrialEndedNoticeShown() }
        }
        .task {
            // The price normally loads at launch; if that failed, try again quietly.
            if store.product == nil { await store.loadProduct() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            // A copy of the current app icon (AppIcon sets can't be loaded as images).
            Image("AppIconArtwork")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text("DartFreak Pro")
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(AppColor.textPrimary)
                Text(reason.tagline)
                    .font(.system(.body))
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - What you get

    private var benefitList: some View {
        VStack(spacing: 4) {
            ForEach(benefits) { benefit in
                let isHighlighted = reason.feature.map { benefit.features.contains($0) } ?? false
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: benefit.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.interactivePrimaryBackground)
                        .frame(width: 28, height: 28)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColor.textPrimary)
                        Text(benefit.detail)
                            .font(.system(.subheadline))
                            .foregroundColor(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isHighlighted ? AppColor.interactivePrimaryBackground.opacity(0.14) : Color.clear)
                )
            }
        }
    }

    // MARK: - Price and buy

    private var purchaseArea: some View {
        VStack(spacing: 12) {
            if let message = store.purchaseMessage {
                Text(message)
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
            }

            AppButton(role: .pro, controlSize: .large) {
                Task { await buy() }
            } label: {
                if store.isPurchasing || store.isLoadingProduct {
                    ProgressView()
                } else if let product = store.product {
                    Text("Get Pro for \(product.displayPrice)")
                } else {
                    Text("Get Pro")
                }
            }
            .disabled(store.isPurchasing || isRestoring)

            Text("One-time purchase. No subscription.")
                .font(.system(.footnote))
                .foregroundColor(AppColor.textSecondary)

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
                    Text("Restore Purchase")
                }
            }
            .font(.system(.footnote))
            .fontWeight(.semibold)
            .foregroundColor(AppColor.textSecondary)
            .disabled(isRestoring || store.isPurchasing)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(AppColor.surfacePrimary)
    }

    /// The button never sits disabled waiting on the network: if the price hasn't
    /// loaded yet, tapping loads it and carries straight on to the purchase.
    private func buy() async {
        if store.product == nil {
            await store.loadProduct()
        }
        guard store.product != nil else {
            showStoreUnavailable = true
            return
        }
        await store.purchase()
    }
}
