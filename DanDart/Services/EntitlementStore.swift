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
    /// Bumped by a successful purchase, so a refresh that read StoreKit before it can't undo it.
    private var purchaseCount = 0
    /// AppTransaction failed once this session: don't ask again (it can show an Apple Account
    /// prompt, and dismissing that re-activates the app) unless Restore asks for it.
    private var appTransactionFailed = false
    private var allowAppTransactionRetry = false
    private let defaults = UserDefaults.standard
    private static let legacyCacheKey = "legacyPaidCustomer"

    private init() {}

    // MARK: - Access

    var inputs: AccessInputs {
        AccessInputs(
            hasPurchasedUnlock: hasPurchasedUnlock,
            isLegacyPaidCustomer: isLegacyPaidCustomer,
            hasServerEntitlement: hasServerEntitlement,
            accountCreatedAt: accountCreatedAt,
            now: Self.now
        )
    }

    var state: AccessState {
        AccessPolicy.evaluate(inputs)
    }

    /// Bought, paid-app customer or unlocked elsewhere (not just "in the trial").
    private var isUnlocked: Bool {
        hasPurchasedUnlock || isLegacyPaidCustomer || hasServerEntitlement
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
    /// `screenBusy`: something else is on screen (a sheet, a cover, a navigation flow).
    func showTrialEndedNoticeIfNeeded(userId: UUID, screenBusy: Bool) {
        let show = TrialEndedNotice.shouldShow(
            inputs: inputs,
            alreadyShown: defaults.bool(forKey: Self.trialEndedNoticeKey(userId)),
            inputsLoaded: lastRefreshComplete && refreshedUserId == userId,
            screenBusy: screenBusy || paywall != nil
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

    /// Forgets everything tied to the signed-in account. Called on sign-out and account deletion.
    /// (A StoreKit purchase belongs to the Apple ID, so hasPurchasedUnlock stays.)
    func reset() {
        hasServerEntitlement = false
        accountCreatedAt = nil
        refreshedUserId = nil
        lastRefreshComplete = false
        paywall = nil
        purchaseMessage = nil
    }

    private func performRefresh() async {
        guard let user = AuthService.shared.currentUser else {
            // Signed out: forget the account's inputs and leave StoreKit alone.
            reset()
            return
        }
        let userId = user.id

        if product == nil { await loadProduct() }

        let purchasesBefore = purchaseCount
        let unlockTransactionId = await Self.currentUnlockTransactionId()

        let mayAskAppTransaction = !appTransactionFailed || allowAppTransactionRetry
        allowAppTransactionRetry = false
        var live: Bool?
        if mayAskAppTransaction {
            live = await Self.isLegacyDownload()
            appTransactionFailed = live == nil
        }

        let server = await Self.fetchServerEntitlement(userId: userId)

        // The account may have changed while we waited: write nothing, its own refresh follows.
        guard AuthService.shared.currentUser?.id == userId else { return }

        hasPurchasedUnlock = unlockTransactionId != nil || purchaseCount != purchasesBefore

        let legacy = LegacyResolution.resolve(live: live, cached: defaults.bool(forKey: Self.legacyCacheKey))
        if legacy.cache {
            defaults.set(true, forKey: Self.legacyCacheKey)
        } else {
            defaults.removeObject(forKey: Self.legacyCacheKey)
        }
        isLegacyPaidCustomer = legacy.isLegacy

        hasServerEntitlement = server ?? false
        accountCreatedAt = user.createdAt
        refreshedUserId = userId
        lastRefreshComplete = legacy.isKnown && server != nil

        // An unlock landed (Ask to Buy approved, Android purchase): drop any unlock screen still
        // waiting, including one held back by a disabled .paywallSheet.
        if isUnlocked { paywall = nil }

        // Bought on iOS: make sure the server knows (first purchase, or a reinstall), so the
        // unlock also shows on Android. Once per account and transaction.
        if let unlockTransactionId {
            await reportToServerIfNeeded(userId: userId, transactionId: unlockTransactionId)
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
                purchaseCount += 1
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
        allowAppTransactionRetry = true
        await refresh()
        // Only an actual unlock counts: during the trial hasFullAccess is true anyway.
        if isUnlocked {
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

    /// A 4xx other than 401 (signed out / token expired) and 429 (rate limited).
    private static func isPermanentRejection(_ code: Int) -> Bool {
        (400..<500).contains(code) && code != 401 && code != 429
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
        } catch FunctionsError.httpError(let code, _) where Self.isPermanentRejection(code) {
            // 409 linked to another account, 403 mismatch / sandbox / not an unlock, 400, 404:
            // asking again won't change the answer.
            print("⚠️ [Entitlements] Server declined the purchase record (\(code)); not retrying.")
            defaults.set(true, forKey: key)
        } catch {
            // Not fatal: iOS still unlocks from StoreKit. It will retry on the next refresh.
            print("⚠️ [Entitlements] Could not record purchase on server: \(error)")
        }
    }
}
