# Free Download, 4-Week Trial and One-Time Unlock: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make DartFreak free to download on iOS. New users get every feature free for 4 weeks. After that, a free tier stays usable forever, and one payment ("DartFreak Full") unlocks everything else. There is no subscription, ever.

**Architecture:** One pure function (`AccessPolicy`) decides the user's access from five inputs: an App Store purchase, a legacy paid download, a server entitlement (a purchase on another platform), the account creation date and the current time. `EntitlementStore` gathers those inputs from StoreKit 2 and Supabase and exposes `canUse(_:)` and `requireAccess(to:)`. The UI shows locked features (blurred, with a lock badge) instead of hiding them. Match data is **always saved**; locks only change what is shown. Purchases are recorded in a new `user_entitlements` table through an edge function that checks the purchase with Apple, so the unlock follows the account to Android.

**Tech Stack:** SwiftUI, StoreKit 2 (`Product`, `Transaction`, `AppTransaction`), Swift Testing, Supabase (Postgres + RLS + Deno edge functions), App Store Server API, Firebase Analytics.

---

## What was decided

| Free forever | DartFreak Full (one-time, same price as the app costs today) |
|---|---|
| Account and profile (header stats: wins, losses, rank) | Cricket, Halve-It, Knockout, Sudden Death, Killer |
| Local 301 and 501, with guests and friends | Remote matches: sending **and** accepting, voice included |
| Friends: search, requests, list, profiles | Head-to-head records on friend profiles |
| Match history list, and detail pages for 301/501 matches | Clubs |
| | Full stats charts on Profile |
| | Detail pages for the party-game matches in History |

- **Trial:** 28 days of everything, counted from the account's `created_at`. No purchase or card needed.
- **Existing iOS buyers** (anyone whose first download was a paid build) keep everything automatically.
- **Everything is always saved.** A free user's games, throws and stats keep being recorded, so unlocking shows their whole history straight away.
- **Locked UI:** show it, don't hide it. There's a lock badge on game cards, blurred charts with an unlock card on top, "Accept" on a remote invite opens the unlock screen, and the Clubs tab shows an unlock card. There are no pop-ups during the trial. A small banner appears in the last 5 days, and a "trial ended" screen shows once.
- **One unlock screen** used everywhere, with what you get, the price, Buy and Restore Purchases.

## Decision to confirm before release: Apple guideline 3.1.1

Apple's guideline 3.1.1 says a non-subscription app *may* offer a time-based free trial by creating a **free (price tier 0) non-consumable in-app purchase named "28-day Trial"** that the user "buys" to start the clock. This plan instead starts the trial automatically when the account is created. That's smoother, and it's defensible because the free tier is a complete, usable app, so the trial is a preview of extras rather than a time-limited app. But a reviewer could still ask for the $0 trial purchase.

**Fallback if App Review objects:** add a $0 non-consumable `com.dandarts.DartFreak.trial28` and a "Start my free 4 weeks" button on the unlock screen, and take the trial start from that transaction's `purchaseDate` instead of `createdAt`. Only `EntitlementStore.refresh()` and `AccessInputs.accountCreatedAt` change. `AccessPolicy` stays the same.

## Known limitations (accepted)

- **Locks are enforced in the app, not on the server.** The remote-match edge functions don't check entitlements. For a small one-time price this is fine. Revisit only if abuse shows up.
- **Deleting and recreating an account gives a new trial.** That's acceptable.
- **Refunds don't reach the server yet.** iOS ignores `source = 'apple'` rows (StoreKit is the truth there, so an Apple refund re-locks iOS), but a refunded Apple purchase stays unlocked on Android until an App Store Server Notifications endpoint removes the row. Add that endpoint with the Android work.
- **A purchase is tied to one DartFreak account on the server.** The same Apple ID buying on a second account still unlocks iOS locally (StoreKit), but the server returns 409 and doesn't share it to Android for the second account.

## Release order (important)

The app must **not** become free on the App Store until the build containing this feature is live. A free download of an older build would be treated as a "legacy paid customer" and unlocked forever. See Task 17.

---

## File structure

**Backend (DanDarts repo)**
- Create `supabase_migrations/099_user_entitlements.sql`: the table, unique index and RLS.
- Create `supabase_migrations/VERIFY_user_entitlements.sql`: checks to run after applying.
- Create `supabase/functions/verify-apple-purchase/index.ts`: checks a transaction with Apple and records the entitlement.

**iOS: new files** (the project uses synchronized folders, so new files are picked up automatically)
- `DanDart/Models/PaidFeature.swift`: `PaidFeature`, `PaywallReason`, `GameAccess`, `PaidFeatureLockedError`.
- `DanDart/Models/AccessPolicy.swift`: `AccessInputs`, `AccessState`, `UnlockReason`, `AccessPolicy`.
- `DanDart/Models/LegacyPurchase.swift`: the paid-download cutoff rule.
- `DanDart/Services/EntitlementStore.swift`: StoreKit 2 and Supabase glue, plus paywall presentation.
- `DanDart/Views/Unlock/PaywallView.swift`: the single unlock screen.
- `DanDart/Views/Unlock/LockedFeatureCard.swift`: the lock card and the `.lockedOverlay(_:)` modifier.
- `DanDart/Views/Unlock/TrialBanner.swift`: the "X days left" banner.
- `DanDart/DartFreak.storekit`: local StoreKit test configuration.
- `DanDartTests/PaidFeatureTests.swift`, `DanDartTests/AccessPolicyTests.swift`, `DanDartTests/LegacyPurchaseTests.swift`.

**iOS: modified files**
- `DanDart/Services/AnalyticsService.swift`: two events.
- `DanDart/Views/MainTabView.swift`: start the store, the paywall sheet, the trial-ended notice, the banner.
- `DanDart/Views/Games/Shared/GamesListView.swift`: lock the party games (two Play buttons).
- `DanDart/Views/Remote/RemoteGamesTab.swift`: lock "Challenge a Friend" and "Accept".
- `DanDart/Views/Friends/FriendProfileView.swift`: lock the Challenge button and head-to-head.
- `DanDart/Services/RemoteMatchService.swift`: a safety guard in `createChallenge` and `acceptChallenge`.
- `DanDart/Views/Clubs/ClubsTabView.swift`: lock the tab content.
- `DanDart/Views/Profile/ProfileView.swift`: blur the charts.
- `DanDart/Views/History/MatchHistoryView.swift`: lock party-game detail pages (two lists).

---

### Task 0: Branch

- [ ] **Step 1:** Make sure the uncommitted changes on `test-flight` (`project.pbxproj`, migration `091_pin_save_remote_visit_search_path.sql`, `supabase/.temp/`) are either committed or deliberately left. Ask Dan, and don't discard them.
- [ ] **Step 2:** Pull and branch.

```bash
cd /Users/dan/Projects/DanDarts
git checkout test-flight && git pull
git checkout -b feature/free-trial-unlock
```

---

### Task 1: `user_entitlements` table

**Files:**
- Create: `supabase_migrations/099_user_entitlements.sql`
- Create: `supabase_migrations/VERIFY_user_entitlements.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 099_user_entitlements.sql
-- DartFreak Full: one row per account that has unlocked the full app.
-- Written only by edge functions (service role) or by hand (source 'manual', e.g. Android testers).
-- Each signed-in user can read their own row, so both iOS and Android can show the unlock.
-- Match data is unaffected: free users' matches are saved exactly as before.

create table if not exists public.user_entitlements (
    user_id uuid primary key references public.users(id) on delete cascade,
    source text not null check (source in ('apple', 'google', 'manual')),
    store_transaction_id text,
    granted_at timestamptz not null default now()
);

-- One store purchase can only unlock one DartFreak account.
create unique index if not exists user_entitlements_store_transaction
    on public.user_entitlements (source, store_transaction_id)
    where store_transaction_id is not null;

alter table public.user_entitlements enable row level security;

drop policy if exists "Users read own entitlement" on public.user_entitlements;
create policy "Users read own entitlement"
    on public.user_entitlements
    for select
    to authenticated
    using (auth.uid() = user_id);

-- No insert/update/delete policies: only the service role (edge functions) writes.
```

- [ ] **Step 2: Write the verify script**

```sql
-- VERIFY_user_entitlements.sql: run after 099. Every row should say true.
select 'table exists' as check, to_regclass('public.user_entitlements') is not null as ok
union all
select 'rls enabled', relrowsecurity from pg_class where oid = 'public.user_entitlements'::regclass
union all
select 'only a select policy', count(*) = 1 and bool_and(cmd = 'SELECT')
  from pg_policies where tablename = 'user_entitlements'
union all
select 'unique store tx index', count(*) = 1
  from pg_indexes where tablename = 'user_entitlements' and indexname = 'user_entitlements_store_transaction';
```

- [ ] **Step 3: Dry-run.** In the Supabase SQL Editor, run the migration wrapped in `begin; … rollback;` and check that there are no errors.
- [ ] **Step 4: Commit.** Don't apply to the live database yet. It's applied with the release in Task 17.

```bash
git add supabase_migrations/099_user_entitlements.sql supabase_migrations/VERIFY_user_entitlements.sql
git commit -m "feat(unlock): add user_entitlements table"
```

---

### Task 2: `verify-apple-purchase` edge function

**Files:**
- Create: `supabase/functions/verify-apple-purchase/index.ts`

The app sends a transaction ID. The function asks Apple's App Store Server API for that transaction, so it never trusts the app's word. It checks the bundle ID, the product ID and that the purchase wasn't refunded, then records the entitlement against the caller's account.

- [ ] **Step 1: Write the function**

```ts
// Edge Function: verify-apple-purchase
// Records a DartFreak Full purchase made on iOS against the calling user's account, so the
// unlock follows them to Android. Looks the transaction up with Apple's App Store Server API
// (rather than trusting the app), checks it is our unlock and not refunded, then upserts
// public.user_entitlements with the service role.
//
// Requires env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY,
//   ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY (In-App Purchase .p8 key, PEM), APPLE_BUNDLE_ID

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const PRODUCT_ID = 'com.dandarts.DartFreak.full'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function base64Url(bytes: Uint8Array): string {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function base64UrlJson(value: unknown): string {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)))
}

function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem.replace(/\\n/g, '\n').replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  return Uint8Array.from(atob(body), (c) => c.charCodeAt(0)).buffer
}

// ES256 JWT for the App Store Server API (valid 5 minutes).
async function appStoreServerToken(): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(Deno.env.get('ASC_PRIVATE_KEY') ?? ''),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
  const now = Math.floor(Date.now() / 1000)
  const header = base64UrlJson({ alg: 'ES256', kid: Deno.env.get('ASC_KEY_ID'), typ: 'JWT' })
  const payload = base64UrlJson({
    iss: Deno.env.get('ASC_ISSUER_ID'),
    iat: now,
    exp: now + 300,
    aud: 'appstoreconnect-v1',
    bid: Deno.env.get('APPLE_BUNDLE_ID'),
  })
  // WebCrypto ECDSA returns raw r||s, which is exactly what JWS ES256 needs.
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )
  return `${header}.${payload}.${base64Url(new Uint8Array(signature))}`
}

// The response comes straight from Apple over TLS with our credentials, so the
// signed payload can be decoded without re-verifying Apple's certificate chain.
function decodeJwsPayload(jws: string): Record<string, unknown> {
  const part = jws.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
  return JSON.parse(atob(part + '='.repeat((4 - (part.length % 4)) % 4)))
}

// Production first; a 404 there means it may be a sandbox (TestFlight / Xcode) purchase.
async function fetchTransaction(transactionId: string): Promise<Record<string, unknown> | null> {
  const token = await appStoreServerToken()
  const hosts = ['https://api.storekit.itunes.apple.com', 'https://api.storekit-sandbox.itunes.apple.com']
  for (const host of hosts) {
    const res = await fetch(`${host}/inApps/v1/transactions/${encodeURIComponent(transactionId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    if (res.status === 404) continue
    if (!res.ok) throw new Error(`App Store Server API returned ${res.status}`)
    const body = await res.json()
    return decodeJwsPayload(body.signedTransactionInfo)
  }
  return null
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json(401, { error: 'not_authenticated' })

    const { transaction_id } = await req.json()
    if (typeof transaction_id !== 'string' || !/^\d+$/.test(transaction_id)) {
      return json(400, { error: 'invalid_transaction_id' })
    }

    const tx = await fetchTransaction(transaction_id)
    if (!tx) return json(404, { error: 'transaction_not_found' })
    if (tx.bundleId !== Deno.env.get('APPLE_BUNDLE_ID') || tx.productId !== PRODUCT_ID || tx.revocationDate) {
      return json(403, { error: 'not_a_valid_unlock' })
    }

    const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '')
    const { error } = await admin.from('user_entitlements').upsert(
      {
        user_id: user.id,
        source: 'apple',
        store_transaction_id: String(tx.originalTransactionId),
        granted_at: new Date().toISOString(),
      },
      { onConflict: 'user_id' },
    )
    if (error) {
      if (error.code === '23505') return json(409, { error: 'purchase_linked_to_another_account' })
      throw error
    }

    console.log(`✅ [verify-apple-purchase] entitlement recorded for ${user.id}`)
    return json(200, { ok: true })
  } catch (err) {
    console.error('❌ [verify-apple-purchase]', err)
    return json(500, { error: 'internal' })
  }
})
```

- [ ] **Step 2: Commit.** It's deployed in Task 17, after the In-App Purchase key exists.

```bash
git add supabase/functions/verify-apple-purchase/index.ts
git commit -m "feat(unlock): verify-apple-purchase edge function"
```

---

### Task 3: `PaidFeature` and `GameAccess`

**Files:**
- Create: `DanDart/Models/PaidFeature.swift`
- Test: `DanDartTests/PaidFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
//
//  PaidFeatureTests.swift
//  DanDartTests
//
//  301 and 501 stay free forever; every other game needs DartFreak Full after the trial.
//

import Testing
@testable import DanDart

struct PaidFeatureTests {

    @Test func threeOhOneAndFiveOhOneAreFree() {
        #expect(GameAccess.isFree(gameType: "301"))
        #expect(GameAccess.isFree(gameType: "501"))
        #expect(GameAccess.isFree(gameType: " 501 "))
    }

    @Test func partyGamesAreNotFree() {
        for type in ["cricket", "Cricket", "halve_it", "halve it", "knockout", "sudden_death", "sudden death", "killer", "Killer"] {
            #expect(!GameAccess.isFree(gameType: type), "\(type) should be locked")
        }
    }

    @Test func everyFeatureHasCopy() {
        for feature in PaidFeature.allCases {
            #expect(!feature.lockedTitle.isEmpty)
            #expect(!feature.lockedMessage.isEmpty)
        }
    }

    @Test func paywallReasonsHaveDistinctIds() {
        let reasons = PaidFeature.allCases.map(PaywallReason.feature) + [.trialEnded]
        #expect(Set(reasons.map(\.id)).count == reasons.count)
    }

    @Test func lockedErrorNamesTheFeature() {
        let error = PaidFeatureLockedError(feature: .remoteMatches)
        #expect(error.errorDescription == "Remote matches need DartFreak Full.")
    }
}
```

- [ ] **Step 2: Run them and confirm they fail** (they won't compile: `GameAccess` doesn't exist yet).

```bash
cd /Users/dan/Projects/DanDarts
xcodebuild test -project DanDart.xcodeproj -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/PaidFeatureTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement**

```swift
//
//  PaidFeature.swift
//  DanDart
//
//  The parts of DartFreak that need DartFreak Full once the 4-week trial ends.
//  Everything else (account, local 301/501, friends, history list) is free forever.
//  Locks only change what is SHOWN. Match data is always saved for everyone.
//

import Foundation

enum PaidFeature: String, CaseIterable, Identifiable {
    case partyGames
    case remoteMatches
    case clubs
    case headToHead
    case fullStats
    case fullHistory

    var id: String { rawValue }

    var lockedTitle: String {
        switch self {
        case .partyGames: return "More games"
        case .remoteMatches: return "Remote matches"
        case .clubs: return "Clubs"
        case .headToHead: return "Head-to-head"
        case .fullStats: return "Your full stats"
        case .fullHistory: return "Match details"
        }
    }

    var lockedMessage: String {
        switch self {
        case .partyGames: return "Cricket, Halve-It, Knockout, Sudden Death and Killer come with DartFreak Full."
        case .remoteMatches: return "Play your mates live from anywhere, with voice chat."
        case .clubs: return "Join and run clubs with the people you play with."
        case .headToHead: return "See who's really winning between you two."
        case .fullStats: return "Your trends, scoring and personal bests have been saved since day one."
        case .fullHistory: return "Every throw of this match has been saved. Unlock to see it."
        }
    }
}

/// Why the unlock screen is showing.
enum PaywallReason: Identifiable, Equatable {
    case feature(PaidFeature)
    case trialEnded

    var id: String {
        switch self {
        case .feature(let feature): return "feature-\(feature.rawValue)"
        case .trialEnded: return "trial-ended"
        }
    }

    var analyticsName: String {
        switch self {
        case .feature(let feature): return feature.rawValue
        case .trialEnded: return "trial_ended"
        }
    }
}

enum GameAccess {
    /// Game types that are free forever. Matched against both stored `gameType`
    /// values and local game titles, which are "301" and "501" for these two.
    static let freeGameTypes: Set<String> = ["301", "501"]

    static func isFree(gameType: String) -> Bool {
        freeGameTypes.contains(gameType.trimmingCharacters(in: .whitespaces).lowercased())
    }
}

/// Thrown by service-level guards so a locked feature can't start by a side route
/// (a rematch button or a notification), even if a view forgot to check.
struct PaidFeatureLockedError: LocalizedError {
    let feature: PaidFeature

    var errorDescription: String? {
        "\(feature.lockedTitle) need DartFreak Full."
    }
}
```

> Note: `"\(feature.lockedTitle) need…"` reads correctly for "Remote matches", which is the only feature that throws.

- [ ] **Step 4: Run the tests again and confirm they pass.**
- [ ] **Step 5: Commit**

```bash
git add DanDart/Models/PaidFeature.swift DanDartTests/PaidFeatureTests.swift
git commit -m "feat(unlock): paid features and free game rule"
```

---

### Task 4: `AccessPolicy`

**Files:**
- Create: `DanDart/Models/AccessPolicy.swift`
- Test: `DanDartTests/AccessPolicyTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
//
//  AccessPolicyTests.swift
//  DanDartTests
//
//  4 weeks of everything from account creation, then the free tier,
//  unless they bought DartFreak Full, bought the paid app, or unlocked on Android.
//

import Foundation
import Testing
@testable import DanDart

struct AccessPolicyTests {

    private let day: TimeInterval = 86_400
    private let created = Date(timeIntervalSince1970: 1_800_000_000)

    private func state(daysAfterCreation days: Double,
                       purchased: Bool = false,
                       legacy: Bool = false,
                       server: Bool = false) -> AccessState {
        AccessPolicy.evaluate(AccessInputs(
            hasPurchasedUnlock: purchased,
            isLegacyPaidCustomer: legacy,
            hasServerEntitlement: server,
            accountCreatedAt: created,
            now: created.addingTimeInterval(days * day)
        ))
    }

    @Test func newAccountGetsTheFullTrial() {
        #expect(state(daysAfterCreation: 0) == .trial(daysLeft: 28))
    }

    @Test func daysLeftRoundsUp() {
        #expect(state(daysAfterCreation: 27.5) == .trial(daysLeft: 1))
        #expect(state(daysAfterCreation: 1) == .trial(daysLeft: 27))
    }

    @Test func trialEndsAfterTwentyEightDays() {
        #expect(state(daysAfterCreation: 28) == .free)
        #expect(state(daysAfterCreation: 90) == .free)
    }

    @Test func purchaseUnlocksForever() {
        #expect(state(daysAfterCreation: 90, purchased: true) == .unlocked(.purchased))
        #expect(state(daysAfterCreation: 1, purchased: true) == .unlocked(.purchased))
    }

    @Test func paidAppBuyersAreUnlocked() {
        #expect(state(daysAfterCreation: 400, legacy: true) == .unlocked(.legacyPaidApp))
    }

    @Test func otherPlatformPurchaseUnlocks() {
        #expect(state(daysAfterCreation: 400, server: true) == .unlocked(.otherPlatform))
    }

    @Test func unknownAccountDateDoesNotFlashLocks() {
        let s = AccessPolicy.evaluate(AccessInputs(accountCreatedAt: nil, now: created))
        #expect(s == .trial(daysLeft: 28))
    }

    @Test func fullAccessFlag() {
        #expect(AccessState.trial(daysLeft: 3).hasFullAccess)
        #expect(AccessState.unlocked(.purchased).hasFullAccess)
        #expect(!AccessState.free.hasFullAccess)
    }
}
```

- [ ] **Step 2: Run them and confirm they fail.**

```bash
xcodebuild test -project DanDart.xcodeproj -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/AccessPolicyTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement**

```swift
//
//  AccessPolicy.swift
//  DanDart
//
//  Decides what a user can use. Pure, so it's fully unit-tested;
//  EntitlementStore gathers the inputs from StoreKit and Supabase.
//

import Foundation

enum UnlockReason: Equatable {
    case purchased       // bought DartFreak Full on this Apple ID
    case legacyPaidApp   // first downloaded DartFreak when it was a paid app
    case otherPlatform   // unlocked on Android (or granted by hand) — user_entitlements row
}

enum AccessState: Equatable {
    case unlocked(UnlockReason)
    case trial(daysLeft: Int)
    case free

    var hasFullAccess: Bool {
        if case .free = self { return false }
        return true
    }
}

struct AccessInputs: Equatable {
    var hasPurchasedUnlock = false
    var isLegacyPaidCustomer = false
    var hasServerEntitlement = false
    /// nil while the user row is still loading — treated as a brand-new account so locks don't flash.
    var accountCreatedAt: Date?
    var now = Date()
}

enum AccessPolicy {
    static let trialDays = 28

    static func evaluate(_ inputs: AccessInputs) -> AccessState {
        if inputs.hasPurchasedUnlock { return .unlocked(.purchased) }
        if inputs.isLegacyPaidCustomer { return .unlocked(.legacyPaidApp) }
        if inputs.hasServerEntitlement { return .unlocked(.otherPlatform) }

        guard let createdAt = inputs.accountCreatedAt else { return .trial(daysLeft: trialDays) }

        let trialEnd = createdAt.addingTimeInterval(TimeInterval(trialDays) * 86_400)
        let remaining = trialEnd.timeIntervalSince(inputs.now)
        guard remaining > 0 else { return .free }
        return .trial(daysLeft: Int((remaining / 86_400).rounded(.up)))
    }
}
```

- [ ] **Step 4: Run the tests again and confirm they pass.**
- [ ] **Step 5: Commit**

```bash
git add DanDart/Models/AccessPolicy.swift DanDartTests/AccessPolicyTests.swift
git commit -m "feat(unlock): access policy with 28-day trial"
```

---

### Task 5: Legacy paid-download rule

**Files:**
- Create: `DanDart/Models/LegacyPurchase.swift`
- Test: `DanDartTests/LegacyPurchaseTests.swift`

On iOS, `AppTransaction.originalAppVersion` is the **build number** (`CFBundleVersion`) of the user's first download. It stays the same across deletes, reinstalls and updates. The current build is 54, so the first free build will be 55 or later. Task 17 confirms the exact number.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  LegacyPurchaseTests.swift
//  DanDartTests
//
//  Anyone whose first download was a build before the app went free paid for it,
//  and keeps everything.
//

import Testing
@testable import DanDart

struct LegacyPurchaseTests {

    @Test func earlierBuildsPaid() {
        #expect(LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "54", firstFreeBuild: 55))
        #expect(LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "1", firstFreeBuild: 55))
    }

    @Test func freeBuildsDidNotPay() {
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "55", firstFreeBuild: 55))
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "60", firstFreeBuild: 55))
    }

    /// The sandbox (Xcode / TestFlight) reports "1.0", which must not unlock anything.
    @Test func nonNumericVersionsAreNotLegacy() {
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "1.0", firstFreeBuild: 55))
        #expect(!LegacyPurchase.isLegacyPaidCustomer(originalAppVersion: "", firstFreeBuild: 55))
    }
}
```

- [ ] **Step 2: Run them and confirm they fail.**

```bash
xcodebuild test -project DanDart.xcodeproj -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:DanDartTests/LegacyPurchaseTests 2>&1 | tail -20
```

- [ ] **Step 3: Implement**

```swift
//
//  LegacyPurchase.swift
//  DanDart
//
//  DartFreak used to cost money up front. Anyone whose first download was a build from
//  before the price went to free keeps everything, with no purchase needed.
//

import Foundation

enum LegacyPurchase {
    /// The first build number (CFBundleVersion) on the App Store once the price is Free.
    /// MUST equal the build released in the same moment the price changes (Task 17).
    static let firstFreeBuild = 55

    static func isLegacyPaidCustomer(originalAppVersion: String,
                                     firstFreeBuild: Int = firstFreeBuild) -> Bool {
        guard let build = Int(originalAppVersion.trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        return build < firstFreeBuild
    }
}
```

- [ ] **Step 4: Run the tests again and confirm they pass.**
- [ ] **Step 5: Commit**

```bash
git add DanDart/Models/LegacyPurchase.swift DanDartTests/LegacyPurchaseTests.swift
git commit -m "feat(unlock): recognise people who bought the paid app"
```

---

### Task 6: Analytics events

**Files:**
- Modify: `DanDart/Services/AnalyticsService.swift` (add after `logFriendRequestAccepted()`)

- [ ] **Step 1: Add**

```swift
    // MARK: - Unlock Events

    func logPaywallShown(reason: String) {
        Analytics.logEvent("paywall_shown", parameters: ["reason": reason])
    }

    func logUnlockPurchased() {
        Analytics.logEvent("unlock_purchased", parameters: nil)
    }
```

- [ ] **Step 2: Build and commit**

```bash
git add DanDart/Services/AnalyticsService.swift
git commit -m "feat(unlock): paywall and purchase analytics events"
```

---

### Task 7: `EntitlementStore` and local StoreKit config

**Files:**
- Create: `DanDart/Services/EntitlementStore.swift`
- Create: `DanDart/DartFreak.storekit` (in Xcode)

- [ ] **Step 1: Create the StoreKit config in Xcode.** File › New › File › *StoreKit Configuration File*, name it `DartFreak`, and leave "Sync with App Store Connect" off. Add a **Non-Consumable**: reference name `DartFreak Full`, product ID `com.dandarts.DartFreak.full`, price the same as today's app price, and display name `DartFreak Full`. Then go to Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration and choose `DartFreak.storekit`.

- [ ] **Step 2: Write the store**

```swift
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
```

- [ ] **Step 3: Build** (`⌘B`). Fix any Supabase SDK signature differences. `functions.invoke(_:options:)` without a result type is the Void-returning overload.
- [ ] **Step 4: Commit**

```bash
git add DanDart/Services/EntitlementStore.swift DanDart/DartFreak.storekit DanDart.xcodeproj
git commit -m "feat(unlock): entitlement store with StoreKit 2 and server record"
```

---

### Task 8: Unlock screen, lock card and lock overlay

**Files:**
- Create: `DanDart/Views/Unlock/PaywallView.swift`
- Create: `DanDart/Views/Unlock/LockedFeatureCard.swift`
- Create: `DanDart/Views/Unlock/TrialBanner.swift`

- [ ] **Step 1: The unlock screen**

```swift
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
```

- [ ] **Step 2: The lock card and overlay**

```swift
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
```

> If `AppButton` doesn't accept an `action:` label in this position, use the trailing-closure form already used in the app: `AppButton(role: .primary, controlSize: .small) { onUnlock() } label: { Text("Unlock DartFreak Full") }`.

- [ ] **Step 3: The trial banner**

```swift
//
//  TrialBanner.swift
//  DanDart
//
//  Only in the last 5 days of the trial. Never a pop-up.
//

import SwiftUI

struct TrialBanner: View {
    @ObservedObject private var store = EntitlementStore.shared
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        if case .trial(let daysLeft) = store.state, daysLeft <= 5 {
            Button {
                store.showPaywall(.trialEnded)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    Text(daysLeft == 1 ? "1 day left of your free trial" : "\(daysLeft) days left of your free trial")
                    Spacer()
                    Text("Unlock").fontWeight(.semibold)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.justWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColor.interactivePrimaryBackground)
            }
            .buttonStyle(.plain)
        }
    }
}
```

> The banner's button opens the paywall with `.trialEnded` copy. Change that to a separate `.trialEnding` reason only if Dan wants different words.

- [ ] **Step 4: Build and commit**

```bash
git add DanDart/Views/Unlock
git commit -m "feat(unlock): unlock screen, lock card and trial banner"
```

---

### Task 9: Wire into `MainTabView`

**Files:**
- Modify: `DanDart/Views/MainTabView.swift` (the main `body`, around lines 163–310)

- [ ] **Step 1:** Add to `MainTabView`'s properties:

```swift
    @ObservedObject private var entitlements = EntitlementStore.shared
```

- [ ] **Step 2:** Add the banner to the Games tab. Wrap the existing `GamesTabView(...)` call:

```swift
                    GamesTabView(
                        gameHeroNamespace: gameHeroNamespace,
                        showProfile: $showProfile,
                        selectedTab: $selectedTab
                    )
                    .safeAreaInset(edge: .top) { TrialBanner() }
```

(Keep the existing `.tabItem` and `.tag` modifiers after it.)

- [ ] **Step 3:** Next to the existing `.sheet(item: $clubCodeToJoin)`, add:

```swift
        .sheet(item: $entitlements.paywall) { reason in
            PaywallView(reason: reason)
                .modernSheet(title: "DartFreak Full", detents: [.large], background: AppColor.surfacePrimary)
        }
        .task { entitlements.start() }
        .task(id: authService.currentUser?.id) {
            await entitlements.refresh()
            showTrialEndedOnce()
        }
```

- [ ] **Step 4:** Add the helper inside `MainTabView`:

```swift
    /// The "your 4 weeks are up" screen, once per account, the first time we notice.
    private func showTrialEndedOnce() {
        guard let userId = authService.currentUser?.id,
              entitlements.state == .free else { return }
        let key = "trialEndedNoticeShown.\(userId.uuidString)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        entitlements.showPaywall(.trialEnded)
    }
```

- [ ] **Step 5:** Build and run in the simulator, signed in. Nothing should look different (you're in the trial). Then launch with `-debugForceTrialEnded YES` and check that the "Your free 4 weeks are up" sheet appears once and not again on the next launch.
- [ ] **Step 6: Commit**

```bash
git add DanDart/Views/MainTabView.swift
git commit -m "feat(unlock): start entitlements, unlock sheet and trial-ended notice"
```

---

### Task 10: Lock the party games

**Files:**
- Modify: `DanDart/Views/Games/Shared/GamesListView.swift` (the `AppButton` at ~line 52 and ~line 134)

- [ ] **Step 1:** Add the property `@ObservedObject private var entitlements = EntitlementStore.shared` and this helper:

```swift
    @ViewBuilder
    private func playButton(for game: Game) -> some View {
        let locked = !GameAccess.isFree(gameType: game.title) && !entitlements.canUse(.partyGames)
        AppButton(role: .primary, controlSize: .small) {
            if locked {
                entitlements.showPaywall(.feature(.partyGames))
            } else {
                onGameSelected(game)
            }
        } label: {
            if locked {
                Label("Unlock", systemImage: "lock.fill")
            } else {
                Text("Play")
            }
        }
    }
```

- [ ] **Step 2:** In **both** places, replace

```swift
                        GameCard(game: game) {
                            AppButton(role: .primary, controlSize: .small) {
                                onGameSelected(game)
                            } label: {
                                Text("Play")
                            }
                        }
```

with

```swift
                        GameCard(game: game) {
                            playButton(for: game)
                        }
```

- [ ] **Step 3:** Run with `-debugForceTrialEnded YES`. 301 and 501 should say Play and start normally. The other five should say 🔒 Unlock and open the unlock screen. Without the flag, all seven should say Play.
- [ ] **Step 4: Commit**

```bash
git add DanDart/Views/Games/Shared/GamesListView.swift
git commit -m "feat(unlock): lock party games after the trial"
```

---

### Task 11: Lock remote matches

**Files:**
- Modify: `DanDart/Views/Remote/RemoteGamesTab.swift` (~line 206 `onAccept`, ~line 532 `showGameSelection = true`)
- Modify: `DanDart/Views/Friends/FriendProfileView.swift` (~line 33 `showGameSelection = true`)
- Modify: `DanDart/Services/RemoteMatchService.swift` (`createChallenge` ~line 637, `acceptChallenge` ~line 950)

- [ ] **Step 1:** In `RemoteGamesTab` and `FriendProfileView`, add `@ObservedObject private var entitlements = EntitlementStore.shared`, and change every `showGameSelection = true` to:

```swift
                guard entitlements.requireAccess(to: .remoteMatches) else { return }
                showGameSelection = true
```

- [ ] **Step 2:** In `RemoteGamesTab`, change the invite card's accept closure to:

```swift
                            onAccept: {
                                guard entitlements.requireAccess(to: .remoteMatches) else { return }
                                acceptChallenge(matchId: matchWithPlayers.match.id)
                            },
```

Invites still arrive and show who sent them. Tapping Accept on the free tier opens the unlock screen. Decline stays free.

- [ ] **Step 3:** The safety net for side routes (rematch on `EndGameViewRemote`, setup screens, notifications). Make these the **first lines** of `createChallenge(...)` and `acceptChallenge(matchId:)`:

```swift
        guard EntitlementStore.shared.requireAccess(to: .remoteMatches) else {
            throw PaidFeatureLockedError(feature: .remoteMatches)
        }
```

(`RemoteMatchService` is `@MainActor`, the same as `EntitlementStore`, so no `await` is needed.)

- [ ] **Step 4:** Test with two simulators or devices and `-debugForceTrialEnded YES` on one. The locked user can't challenge, sees invites, gets the unlock screen on Accept and can still Decline. The unlocked user is unaffected.
- [ ] **Step 5: Commit**

```bash
git add DanDart/Views/Remote/RemoteGamesTab.swift DanDart/Views/Friends/FriendProfileView.swift DanDart/Services/RemoteMatchService.swift
git commit -m "feat(unlock): remote matches need DartFreak Full after the trial"
```

---

### Task 12: Lock Clubs

**Files:**
- Modify: `DanDart/Views/Clubs/ClubsTabView.swift` (the `content` view builder, ~line 35)

- [ ] **Step 1:** Add `@ObservedObject private var entitlements = EntitlementStore.shared`, and make the first branch of `content`:

```swift
    @ViewBuilder
    private var content: some View {
        if !entitlements.canUse(.clubs) {
            LockedFeatureCard(feature: .clubs) {
                entitlements.showPaywall(.feature(.clubs))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 48)
        } else if !hasLoaded && !loadFailed {
            // …existing code unchanged…
```

The tab stays visible. Club membership is kept in the database, so unlocking later brings everything back.

- [ ] **Step 2:** Check with and without `-debugForceTrialEnded YES`, then commit.

```bash
git add DanDart/Views/Clubs/ClubsTabView.swift
git commit -m "feat(unlock): clubs need DartFreak Full after the trial"
```

---

### Task 13: Lock head-to-head

**Files:**
- Modify: `DanDart/Views/Friends/FriendProfileView.swift` (`HeadToHeadStatsView(...)`, ~line 100)

- [ ] **Step 1:** Add one modifier:

```swift
                        HeadToHeadStatsView(
                            matches: headToHeadMatches,
                            currentUserAvatar: authService.currentUser?.avatarURL,
                            friendAvatar: friend.avatarURL,
                            currentUserId: authService.currentUser?.id ?? UUID(),
                            friendId: friend.userId ?? friend.id
                        )
                        .lockedOverlay(.headToHead)
```

The real records are drawn blurred, so free users can see there's a rivalry worth unlocking. The "No matches yet" empty state stays unlocked.

- [ ] **Step 2:** Check and commit.

```bash
git add DanDart/Views/Friends/FriendProfileView.swift
git commit -m "feat(unlock): blur head-to-head on the free tier"
```

---

### Task 14: Lock full stats

**Files:**
- Modify: `DanDart/Views/Profile/ProfileView.swift` (`VStack(spacing: 48) { … }`, ~lines 53–94)

- [ ] **Step 1:** Add the modifier to the closing brace of the charts `VStack(spacing: 48)`, which contains `ThreeDartAverageTrendChart` through `PracticeSessionsSection`:

```swift
                        VStack(spacing: 48) {
                            // …charts unchanged…
                        }
                        .lockedOverlay(.fullStats)
```

The profile header (wins, losses, rank) stays visible. Stats keep calculating, so unlocking shows everything immediately.

- [ ] **Step 2:** Check and commit.

```bash
git add DanDart/Views/Profile/ProfileView.swift
git commit -m "feat(unlock): blur full stats on the free tier"
```

---

### Task 15: Lock party-game match details

**Files:**
- Modify: `DanDart/Views/History/MatchHistoryView.swift` (~line 254 and ~line 327)

- [ ] **Step 1:** Add `@ObservedObject private var entitlements = EntitlementStore.shared` and:

```swift
    private func canOpen(_ summary: MatchSummary) -> Bool {
        GameAccess.isFree(gameType: summary.gameType) || entitlements.canUse(.fullHistory)
    }

    private func lockedRow(_ summary: MatchSummary) -> some View {
        Button {
            entitlements.showPaywall(.feature(.fullHistory))
        } label: {
            matchRowView(summary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                        .padding(10)
                }
        }
        .buttonStyle(.plain)
    }
```

- [ ] **Step 2:** In the main list (~line 254), replace the `ForEach` body with:

```swift
                    ForEach(filteredSummaries) { summary in
                        if canOpen(summary) {
                            NavigationLink(value: summary.id) {
                                matchRowView(summary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            lockedRow(summary)
                        }
                    }
```

- [ ] **Step 3:** In the search results list (~line 327), replace the `ForEach` body with:

```swift
                            ForEach(filteredSummaries) { summary in
                                if canOpen(summary) {
                                    NavigationLink(value: summary.id) {
                                        matchRowView(summary)
                                    }
                                    .buttonStyle(.plain)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        stopSearch()
                                    })
                                } else {
                                    lockedRow(summary)
                                }
                            }
```

All matches still appear in the list. Only the detail page of a party-game match is locked.

- [ ] **Step 4:** Check and commit.

```bash
git add DanDart/Views/History/MatchHistoryView.swift
git commit -m "feat(unlock): lock party-game match details on the free tier"
```

---

### Task 16: Full check on the simulator and devices

- [ ] Run all unit tests: `xcodebuild test -project DanDart.xcodeproj -scheme DanDart -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30`
- [ ] **Trial user** (normal launch): everything works exactly as before. No banner unless the account is 23 or more days old.
- [ ] **Free user** (`-debugForceTrialEnded YES`):
  - 301/501 work, with guests and with friends, and the match is saved (check the `matches` row in Supabase).
  - The party games show 🔒 Unlock.
  - Remote: can't challenge, Accept opens the unlock screen, Decline works.
  - Clubs: the lock card shows.
  - Head-to-head is blurred. Profile charts are blurred and the header is visible.
  - History lists everything. 301/501 details open and party-game details open the unlock screen.
  - The trial-ended sheet shows once per account.
- [ ] **Purchase** (Xcode StoreKit config): buy from the unlock screen, and everything unlocks without a restart. Debug › StoreKit › Manage Transactions › delete the transaction, and the locks return. Restore Purchases works.
- [ ] **Server entitlement:** in the SQL Editor, `insert into user_entitlements (user_id, source) values ('<test user id>', 'manual');`. Pull to refresh or relaunch with `-debugForceTrialEnded YES`, and everything should be unlocked. Delete the row afterwards.
- [ ] Use superpowers:requesting-code-review before opening the PR. Open the PR to `test-flight` **only with Dan's go-ahead**.

---

### Task 17: App Store Connect, backend and release (Dan, with Claude's help)

Order matters. Do it top to bottom.

- [ ] **1. Check build numbers.** In App Store Connect › TestFlight, confirm every build ever released on the App Store is a plain whole number, all below the build you'll ship. Set `LegacyPurchase.firstFreeBuild` to that build number exactly (55 if nothing else ships first) and commit.
- [ ] **2. Create the in-app purchase.** App Store Connect › DartFreak › Monetization › In-App Purchases › **Non-Consumable**:
  - Reference name `DartFreak Full`, Product ID `com.dandarts.DartFreak.full`.
  - Price: **the same as the app's current price** (Pricing and Availability shows it).
  - Display name `DartFreak Full`. Description "Every game, remote matches, clubs, head-to-head and full stats. One payment, no subscription."
  - Review screenshot: the unlock screen.
- [ ] **3. Create an In-App Purchase key.** Users and Access › Integrations › In-App Purchase. Note the Issuer ID and Key ID, and download the `.p8` (it can only be downloaded once).
- [ ] **4. Backend.** Apply `099_user_entitlements.sql` in the SQL Editor and run `VERIFY_user_entitlements.sql` (all rows true). Set the function secrets `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY` and `APPLE_BUNDLE_ID=com.dandarts.DartFreak`, plus `APPLE_ALLOW_SANDBOX=true` for testing only. Deploy `verify-apple-purchase`.
- [ ] **5. TestFlight.** A sandbox purchase from TestFlight should create a `user_entitlements` row (`source = 'apple'`). Then **remove `APPLE_ALLOW_SANDBOX`** (sandbox purchases are free, so they must not unlock Android in production) and delete the test rows.
- [ ] **6. Submit the version with the IAP attached.** Keep the app **paid** while it's in review. In the review notes, explain the free tier, the automatic 4-week trial and the one-time unlock. Set the release to **manual**.
- [ ] **7. Go free in one move.** Once it's approved: release the version, **then straight away** set Pricing to Free. Don't set it to Free before the new build is live (see "Release order" at the top).
- [ ] **8. Words.** Update the App Store description ("Free to download. Every feature free for 4 weeks. Then 301, 501 and friends stay free forever, or unlock everything with one payment. No subscription."), the website and the terms if they mention price.
- [ ] **9. If App Review objects to the automatic trial:** use the $0 "28-day Trial" fallback described at the top.

---

### Task 18: Android (separate plan, in `DartFreak-Android`)

Write a separate plan for this once iOS is live. Its outline:

- Use Google Play Billing with one **one-time product** `dartfreak_full` at the same price.
- Add a `verify-google-purchase` edge function (Google Play Developer API `purchases.products.get`) that writes `user_entitlements` with `source = 'google'`.
- Copy `PaidFeature`, `GameAccess` and `AccessPolicy` to Kotlin **with the same tests**, so both apps lock exactly the same things. The iOS test files are the spec.
- Read `user_entitlements` so an iOS purchase unlocks Android too.
- Give existing paid Android testers `manual` rows.
- Make the Play listing free. **This can't be undone**: once a Play app is free, it can never go back to paid.

---

## Self-review notes

- Every decided rule maps to a task: free 301/501 (10), friends free (nothing is locked there except the Challenge button, 11), remote send and accept (11), head-to-head (13), clubs (12), party games (10), full stats (14), history details (15), 28-day trial (4), legacy buyers (5), always saved (no save path is touched, checked in 16), locked UI style (8), banner and one-time notice (8, 9), same price (17), Android follows (18).
- Names match across tasks: `EntitlementStore.shared`, `canUse(_:)`, `requireAccess(to:)`, `showPaywall(_:)`, `paywall`, `state`, `PaidFeature`, `PaywallReason`, `GameAccess.isFree(gameType:)`, `PaidFeatureLockedError`, `AccessPolicy.evaluate(_:)`, `LegacyPurchase.isLegacyPaidCustomer(originalAppVersion:firstFreeBuild:)`.
