//
//  EntitlementStore.swift
//  DanDart
//
//  Gathers what AccessPolicy needs: a StoreKit purchase of DartFreak Full, whether the
//  first download was a paid build, and a user_entitlements row (an Android purchase).
//  Views ask canUse(_:) / requireAccess(to:). Locks never stop data being saved.
//

import Foundation
import StoreKit
import Supabase

@MainActor
final class EntitlementStore: ObservableObject {
    static let shared = EntitlementStore()
    static let fullUnlockProductID = "com.dandarts.DartFreak.full"

    @Published private(set) var hasPurchasedUnlock = false
    @Published private(set) var isLegacyPaidCustomer = false
    @Published private(set) var hasServerEntitlement = false
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var paywall: PaywallReason?

    private var updatesTask: Task<Void, Never>?

    private init() {}

    // MARK: - Access

    var state: AccessState {
        AccessPolicy.evaluate(AccessInputs(
            hasPurchasedUnlock: hasPurchasedUnlock,
            isLegacyPaidCustomer: isLegacyPaidCustomer,
            hasServerEntitlement: hasServerEntitlement,
            accountCreatedAt: AuthService.shared.currentUser?.createdAt,
            now: Self.now
        ))
    }

    func canUse(_ feature: PaidFeature) -> Bool {
        state.hasFullAccess
    }

    /// True if the feature can be used; otherwise opens the unlock screen and returns false.
    @discardableResult
    func requireAccess(to feature: PaidFeature) -> Bool {
        if canUse(feature) { return true }
        showPaywall(.feature(feature))
        return false
    }

    func showPaywall(_ reason: PaywallReason) {
        paywall = reason
        AnalyticsService.shared.logPaywallShown(reason: reason.analyticsName)
    }

    /// Launch with `-debugForceTrialEnded YES` (Scheme › Arguments) to test the free tier.
    private static var now: Date {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugForceTrialEnded") { return .distantFuture }
        #endif
        return Date()
    }

    // MARK: - Lifecycle

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task {
            await loadProduct()
            await refresh()
        }
    }

    func refresh() async {
        let unlockTransactionId = await Self.currentUnlockTransactionId()
        hasPurchasedUnlock = unlockTransactionId != nil
        isLegacyPaidCustomer = await Self.isLegacyDownload()
        hasServerEntitlement = await Self.fetchServerEntitlement()

        // Bought on iOS: make sure the server knows (first purchase, or a reinstall), so the
        // unlock also shows on Android. The function is idempotent for the same account.
        if let unlockTransactionId {
            await Self.reportToServer(transactionId: unlockTransactionId)
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            // Ties the purchase to this DartFreak account; verify-apple-purchase rejects a
            // transaction whose appAccountToken belongs to someone else.
            var options: Set<Product.PurchaseOption> = []
            if let userId = AuthService.shared.currentUser?.id {
                options.insert(.appAccountToken(userId))
            }
            let result = try await product.purchase(options: options)
            if case .success(.verified(let transaction)) = result {
                await transaction.finish()
                AnalyticsService.shared.logUnlockPurchased()
                await refresh()
                paywall = nil
            }
        } catch {
            print("❌ [Entitlements] Purchase failed: \(error)")
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
        if state.hasFullAccess { paywall = nil }
    }

    private func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.fullUnlockProductID]).first
        } catch {
            print("❌ [Entitlements] Could not load product: \(error)")
        }
    }

    // MARK: - Inputs

    private static func currentUnlockTransactionId() async -> UInt64? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == fullUnlockProductID,
               transaction.revocationDate == nil {
                return transaction.originalID
            }
        }
        return nil
    }

    private static func isLegacyDownload() async -> Bool {
        guard let result = try? await AppTransaction.shared,
              case .verified(let appTransaction) = result else { return false }
        return LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: appTransaction.originalAppVersion)
    }

    private struct EntitlementRow: Decodable {
        let source: String
    }

    /// A row from ANOTHER platform (Android, or granted by hand). Apple rows are ignored here:
    /// on iOS, StoreKit is the truth for Apple purchases, so an Apple refund re-locks iOS.
    private static func fetchServerEntitlement() async -> Bool {
        guard let userId = AuthService.shared.currentUser?.id else { return false }
        do {
            let rows: [EntitlementRow] = try await SupabaseService.shared.client
                .from("user_entitlements")
                .select("source")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            return rows.contains { $0.source != "apple" }
        } catch {
            print("⚠️ [Entitlements] Server check failed: \(error)")
            return false
        }
    }

    private struct VerifyPayload: Encodable {
        let transaction_id: String
    }

    private static func reportToServer(transactionId: UInt64) async {
        guard AuthService.shared.currentUser != nil else { return }
        do {
            try await SupabaseService.shared.client.functions.invoke(
                "verify-apple-purchase",
                options: FunctionInvokeOptions(body: VerifyPayload(transaction_id: String(transactionId)))
            )
        } catch {
            // Not fatal: iOS still unlocks from StoreKit. It will retry on the next refresh.
            print("⚠️ [Entitlements] Could not record purchase on server: \(error)")
        }
    }
}
