//
//  EntitlementStore.swift
//  DanDart
//
//  Gathers what AccessPolicy needs: a StoreKit purchase of DartFreak Full, whether the
//  first download was a paid build, a user_entitlements row (an Android purchase) and the
//  account's creation date. Views ask canUse(_:) / requireAccess(to:). Locks never stop data
//  being saved.
//
//  StoreKit is only queried for a signed-in user: asking AppTransaction before sign-in made
//  the simulator show an "Apple Account Verification" password prompt at launch.
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
    /// From the signed-in account, set by refresh(). nil before the first refresh (counts as a new account).
    @Published private(set) var accountCreatedAt: Date?
    @Published private(set) var product: Product?
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var isPurchasing = false
    /// Feedback for the unlock screen after Buy or Restore. Cleared whenever the screen opens.
    @Published var purchaseMessage: String?
    @Published var paywall: PaywallReason?

    /// The account the last refresh ran for, and whether every input loaded. A failed input
    /// falls back to "locked", so decisions that would surprise someone (the trial-ended
    /// notice) wait until everything loaded.
    @Published private(set) var refreshedUserId: UUID?
    @Published private(set) var lastRefreshComplete = false

    private var updatesTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var refreshAgain = false
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Access

    var state: AccessState {
        AccessPolicy.evaluate(AccessInputs(
            hasPurchasedUnlock: hasPurchasedUnlock,
            isLegacyPaidCustomer: isLegacyPaidCustomer,
            hasServerEntitlement: hasServerEntitlement,
            accountCreatedAt: accountCreatedAt,
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
        purchaseMessage = nil
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

    // MARK: - Trial-ended notice

    private static func trialEndedNoticeKey(_ userId: UUID) -> String {
        "trialEndedNoticeShown.\(userId.uuidString)"
    }

    /// Opens the "your 4 weeks are up" screen once per account, the first time we're sure.
    /// The flag is only set when the screen actually appears (markTrialEndedNoticeShown).
    func showTrialEndedNoticeIfNeeded(userId: UUID) {
        guard paywall == nil else { return }
        let show = TrialEndedNotice.shouldShow(
            state: state,
            alreadyShown: defaults.bool(forKey: Self.trialEndedNoticeKey(userId)),
            inputsLoaded: lastRefreshComplete && refreshedUserId == userId
        )
        if show { showPaywall(.trialEnded) }
    }

    /// Called by the unlock screen when it appears with `.trialEnded`.
    func markTrialEndedNoticeShown() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        defaults.set(true, forKey: Self.trialEndedNoticeKey(userId))
    }

    // MARK: - Lifecycle

    func start() {
        guard updatesTask == nil else { return }
        // Listening is passive (no prompt); refresh() itself does nothing until someone signs in.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    /// Overlapping calls share one run; a call that arrives mid-run queues one more run so
    /// nobody gets results read before their change (a purchase, a new sign-in).
    func refresh() async {
        if let refreshTask {
            refreshAgain = true
            await refreshTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.refreshAgain = false
                await self.performRefresh()
            } while self.refreshAgain
            self.refreshTask = nil
        }
        refreshTask = task
        await task.value
    }

    private func performRefresh() async {
        guard let user = AuthService.shared.currentUser else {
            // Signed out: forget the account's inputs and leave StoreKit alone.
            hasServerEntitlement = false
            accountCreatedAt = nil
            refreshedUserId = nil
            lastRefreshComplete = false
            return
        }
        let userId = user.id
        accountCreatedAt = user.createdAt

        if product == nil { await loadProduct() }

        let unlockTransactionId = await Self.currentUnlockTransactionId()
        hasPurchasedUnlock = unlockTransactionId != nil

        let legacyKnown = resolveLegacy(await Self.isLegacyDownload())

        let server = await Self.fetchServerEntitlement(userId: userId)
        hasServerEntitlement = server ?? false

        // The account may have changed while we waited; its own refresh follows.
        guard AuthService.shared.currentUser?.id == userId else { return }
        refreshedUserId = userId
        lastRefreshComplete = legacyKnown && server != nil && accountCreatedAt != nil

        // Bought on iOS: make sure the server knows (first purchase, or a reinstall), so the
        // unlock also shows on Android. Once per account and transaction.
        if let unlockTransactionId {
            await reportToServerIfNeeded(userId: userId, transactionId: unlockTransactionId)
        }
    }

    /// Applies the AppTransaction answer. A verified "paid download" is remembered, so a paid
    /// customer who is offline (AppTransaction fails) isn't locked out. Returns whether the
    /// answer is known.
    private func resolveLegacy(_ answer: Bool?) -> Bool {
        let cacheKey = "legacyPaidCustomer"
        switch answer {
        case .some(true):
            defaults.set(true, forKey: cacheKey)
            isLegacyPaidCustomer = true
            return true
        case .some(false):
            isLegacyPaidCustomer = false
            return true
        case .none:
            let cached = defaults.bool(forKey: cacheKey)
            isLegacyPaidCustomer = cached
            return cached
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        purchaseMessage = nil
        defer { isPurchasing = false }

        do {
            // Ties the purchase to this DartFreak account; verify-apple-purchase rejects a
            // transaction whose appAccountToken belongs to someone else.
            var options: Set<Product.PurchaseOption> = []
            if let userId = AuthService.shared.currentUser?.id {
                options.insert(.appAccountToken(userId))
            }
            let result = try await product.purchase(options: options)
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                hasPurchasedUnlock = true
                AnalyticsService.shared.logUnlockPurchased()
                paywall = nil
                await refresh()
            case .success(.unverified):
                purchaseMessage = "That purchase couldn't be verified."
            case .pending:
                purchaseMessage = "Waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            print("❌ [Entitlements] Purchase failed: \(error)")
            if case StoreKitError.userCancelled = error { return }
            purchaseMessage = "Something went wrong. Please try again."
        }
    }

    func restore() async {
        purchaseMessage = nil
        do {
            try await AppStore.sync()
        } catch {
            print("❌ [Entitlements] Restore failed: \(error)")
            if case StoreKitError.userCancelled = error { return }
            purchaseMessage = "Couldn't reach the App Store."
            return
        }
        await refresh()
        // Only an actual unlock counts: during the trial hasFullAccess is true anyway.
        if hasPurchasedUnlock || isLegacyPaidCustomer || hasServerEntitlement {
            paywall = nil
        } else {
            purchaseMessage = "No previous purchase found for this Apple ID."
        }
    }

    /// Runs at refresh, and from the unlock screen when the price hasn't loaded.
    func loadProduct() async {
        guard !isLoadingProduct, AuthService.shared.currentUser != nil else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
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

    /// nil when AppTransaction couldn't be read or verified.
    private static func isLegacyDownload() async -> Bool? {
        guard let result = try? await AppTransaction.shared,
              case .verified(let appTransaction) = result else { return nil }
        return LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: appTransaction.originalAppVersion)
    }

    private struct EntitlementRow: Decodable {
        let source: String
    }

    /// A row from ANOTHER platform (Android, or granted by hand). Apple rows are ignored here:
    /// on iOS, StoreKit is the truth for Apple purchases, so an Apple refund re-locks iOS.
    /// nil when the check failed.
    private static func fetchServerEntitlement(userId: UUID) async -> Bool? {
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
            return nil
        }
    }

    private struct VerifyPayload: Encodable {
        let transaction_id: String
    }

    private func reportToServerIfNeeded(userId: UUID, transactionId: UInt64) async {
        let key = "unlockReported.\(userId.uuidString).\(transactionId)"
        guard !defaults.bool(forKey: key) else { return }
        do {
            try await SupabaseService.shared.client.functions.invoke(
                "verify-apple-purchase",
                options: FunctionInvokeOptions(body: VerifyPayload(transaction_id: String(transactionId)))
            )
            defaults.set(true, forKey: key)
        } catch FunctionsError.httpError(code: 409, _) {
            // Already recorded for another account; asking again won't change that.
            defaults.set(true, forKey: key)
        } catch {
            // Not fatal: iOS still unlocks from StoreKit. It will retry on the next refresh.
            print("⚠️ [Entitlements] Could not record purchase on server: \(error)")
        }
    }
}
