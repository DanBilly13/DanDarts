# Remote Matches — Push Notifications Plan (Feedback Draft, Revised v2)

## Product description
Remote Matches adds asynchronous, server-authoritative multiplayer to the existing darts app so players can create challenges, accept matches, take turns remotely, and see consistent match state and history across the app. The feature is built on Supabase-backed backend flows, with the client reacting to authoritative server state rather than inventing state locally.

## Summary: where we are now
We are in **Phase 7 — Push Notifications (live-only)**.

What is already true:
- Remote Matches exists and core flows have been rebuilt around server-authoritative state.
- There is already an **in-app notification signal** for incoming challenges: when a challenger sends a remote match challenge, the receiving user gets a **badge on the Remote tab** while the app is open.

What Phase 7 is meant to add:
- **Real push notifications** for when the user is **not actively in the app**
- Deep linking from a push tap into the **Remote tab**
- Scroll/highlight behavior so the relevant challenge or ready match is easy to find

This means push notifications are not replacing the current in-app badge behavior; they are extending notification coverage to cases where the app is in the background, the phone is locked, or the user is in another app.

## Revised status after feedback
The biggest practical gaps identified in feedback are:
- **APNs environment handling** must be explicit
- **FCM vs direct APNs** should be resolved before Task 19 starts
- **Token sync reliability** needs retry and confirmation behavior
- **Permission denied handling** needs product treatment, not just technical handling
- **Supabase delivery mechanism** should be chosen up front
- **Logout/account switch handling** must prevent cross-account push leakage
- **Install-scoped identity storage** should be explicit

## Goal of this document
This document outlines the proposed architecture and rollout plan for Push Notifications in Remote Matches, and highlights likely implementation risks so we can get feedback before development continues.

---

## Scope for this phase

### Task 19 — Push registration + token storage
- Request notification permission
- Register device token(s)
- Store and update token(s) per user in Supabase

### Task 20 — Push: Challenge received
- Send push when a challenge is created for the receiver
- Tapping the push should open the app, route to the Remote tab, and highlight the incoming challenge

### Task 21 — Push: Challenge accepted / match ready
- Send push when the receiver accepts and the match becomes ready
- Tapping the push should open the app, route to the Remote tab, and highlight the ready match

### Task 22 — Deep linking + highlight
- Route to the Remote tab
- Scroll to the relevant card
- Pulse/highlight the correct card briefly

---

# Critical decisions to resolve before implementation

## 1) Push provider: direct APNs vs FCM
This should be resolved before any Task 19 code is written.

Why it matters:
- it changes what token is stored
- it changes the server-side sending path
- it affects payload shape and future extensibility
- it changes the operational story for retries, monitoring, and debugging

If the project chooses **direct APNs**, the backend stores APNs device tokens and sends directly to Apple.
If the project chooses **FCM**, the app/backend will work with FCM registration tokens and use Firebase as the delivery bridge.

This should no longer remain an open question once implementation starts.

## 2) Supabase delivery mechanism
The plan also needs a concrete answer for how push delivery is initiated inside the Supabase-based architecture.

Likely options:
- database trigger -> Edge Function
- explicit server-side/API-layer call into a push-delivery function

This matters for:
- idempotency
- visibility into failures
- retry design
- debugging and support

This should also be resolved before Task 19/20 implementation starts.

## 3) Existing push infrastructure reuse
This should be confirmed before the document is treated as final.

**Current planning assumption:** there is **no existing reusable push infrastructure elsewhere in the app** that materially changes this design.

If that assumption is false, revisit:
- token model
- notification manager ownership
- provider choice
- delivery pipeline

---

# Proposed architecture

## 1) Core product rule
Push notifications should be treated as a **delivery mechanism**, not a source of truth.

The notification should only carry enough information to route the user into the correct part of the app. Once the app opens, the client should fetch fresh authoritative state from the backend and then decide what to display.

This keeps the implementation aligned with the broader Remote Matches architecture:
- server decides state
- client reacts to state
- notifications and events trigger fetches, not local state invention

---

## 2) Four-layer model

### Layer A — Device registration and token sync
The iOS app:
- asks the user for notification permission
- registers for remote notifications
- receives a device token
- uploads that token to Supabase
- keeps it updated if it changes
- retries upload if sync fails
- tracks whether the current token has been confirmed by the backend

This is the foundation for all later push delivery.

### Layer A.1 — APNs environment handling
APNs environment handling must be explicit.

Important distinction:
- **debug/dev builds** typically use **sandbox APNs**
- **TestFlight and App Store builds** use **production APNs**

This matters because a token for one environment will not work against the other endpoint.

Recommended token metadata to store when relevant:
- `provider` (`apns` or `fcm`)
- `environment` (`sandbox` or `production`)
- `token_sync_status` (`pending`, `synced`, `failed`)
- `last_sync_attempt_at`
- `last_sync_error` (optional)

### Layer B — Server-side event production
Backend code decides when a push should be sent.

For v1, only two events matter:
- challenge created -> notify receiver
- challenge accepted / match ready -> notify challenger

Push should only be sent from server-authoritative transition points, not from ad hoc client logic.

### Layer C — Notification payload contract
The payload should be intentionally small.

Recommended fields:
- `type`: `challenge_received` or `match_ready`
- `matchId`
- `route`: `remote`
- `highlight`: `incoming` or `ready`
- optional `category` if notification categories/actions are adopted

Avoid embedding full match state in the push payload.

Even if v1 does not support lock-screen actions, it is worth deciding now whether notification categories will exist, because retrofitting them later may require payload/schema changes.

### Layer D — App routing and highlight behavior
When the user taps a push:
1. app opens
2. app routes to the Remote tab
3. app stores a temporary route intent
4. Remote tab fetches latest data
5. app resolves the relevant card by `matchId`
6. app scrolls to the card
7. app pulses/highlights the card briefly
8. app clears the one-shot intent

---

# Suggested iOS architecture

## Notification manager
A dedicated notification manager should own:
- permission request
- permission-status observation
- remote notification registration
- token upload/update
- retry of failed token sync
- foreground notification handling policy
- tap handling
- logout/account-switch cleanup behavior

## Foreground presentation mechanism
Foreground policy should not stay conceptual only; it should be wired explicitly through `UNUserNotificationCenterDelegate`.

When a push arrives while the app is active, iOS suppresses the system banner by default unless `userNotificationCenter(_:willPresent:withCompletionHandler:)` returns a presentation option.

That means this delegate method is the concrete enforcement point for the product decision:
- whether foreground pushes should show a banner
- whether they should remain silent
- whether the existing in-app badge is sufficient

## App-level route intent
Use a small app-wide intent object for notification-driven navigation.

Example shape:
- destination tab
- `matchId`
- highlight style
- pending/consumed flag

This gives a single entry point for future push or deep-link driven navigation.

## Remote tab coordinator behavior
The Remote tab should not assume the item is already loaded.

Recommended flow:
- receive pending intent
- fetch authoritative lists/state
- locate item by `matchId`
- scroll after rows exist
- run pulse animation
- clear intent

---

# On-device install identity

## Recommended storage choice
Use an app-generated **device_install_id** stored in **UserDefaults**.

Why this is the best fit here:
- the current model is explicitly **install-scoped**
- uninstall clearing the value is consistent with that model
- it avoids implying durable physical-device identity when that is not actually required

## Why not rely on identifierForVendor
`UIDevice.identifierForVendor` is not a fully durable identity because it can reset after full uninstall/reinstall and can create false expectations of device-level stability.

## Why not make Keychain the default here
Keychain-backed persistence can survive some reinstall scenarios, which is often useful for durable identity, but in this case it works against the stated design goal of treating deduplication as per-install rather than per-physical-device.

---

# Permission and consent handling

Push permission should be treated as a real product state, not just a technical callback.

Recommended states to handle explicitly:
- `notDetermined`
- `authorized`
- `denied`
- any additional system-specific states you choose to model

## Recommended behavior
- if status is `notDetermined`, request permission at the chosen product moment
- if status is `denied`, do not keep trying to prompt; instead surface a graceful in-app explanation and route the user to Settings if needed
- track when permission was last requested so repeated prompting can be avoided

## Settings recovery path
For denied permission, the practical iOS escape hatch is opening the app's settings page via `UIApplication.openSettingsURLString`.

That should be treated as the standard recovery path in the denied state.

## Suggested consent/status storage
Either create a dedicated table or store equivalent fields on a user-related record.

Suggested fields:
- `user_id`
- `push_permission_status`
- `permission_last_requested_at`
- `has_ever_had_token_stored`
- `last_token_stored_at` (optional)

Why this is useful:
- analytics on push adoption
- better prompting decisions
- better support/debug visibility

---

# Session, logout, and account-switch handling

This is a core security and correctness requirement, not just cleanup.

## Risk
If a token remains active after logout, or remains associated with the wrong user during account switching, a later user on the same device could receive pushes meant for the previous user.

## Recommended behavior
On logout:
- mark the current token record inactive for that user/device install, or sever the user association
- clear any in-memory route intent or notification session state tied to that account
- ensure future notification sends for that user no longer target the logged-out install

On account switch:
- treat the old session as a logout first
- then re-register or re-sync the token under the new user context as needed

## Backend model implication
The token record should be user-associated, but the install identity should remain separate from the user identity. That makes it possible to deactivate/reactivate cleanly without confusing install identity with account identity.

---

# Foreground vs background behavior

## What already exists
When the app is open, incoming challenges already produce an in-app signal: a badge on the Remote tab.

## Recommended product behavior
- **Foreground / app open** -> keep using in-app badge or in-app notification UI
- **Background / phone locked / another app active** -> use push notification
- **Push tap** -> route to Remote tab and highlight the relevant card

This avoids duplicate/noisy UX while still giving coverage when the app is not visible.

---

# Recommended rollout order

## Step 1 — Resolve prerequisites
Before any implementation starts, resolve:
1. **Direct APNs vs FCM**
2. **Supabase push-delivery mechanism**
3. **Whether any existing push infrastructure should be reused**

These are architecture decisions, not implementation details.

## Step 2 — Task 19: token registration and storage
Build the registration path after the provider and delivery mechanism are decided.

Suggested outcomes:
- permission request works
- token is received
- token is stored in Supabase
- token is updated on refresh/reinstall
- multiple devices for the same user are supported
- token sync failures are retried
- the app knows whether the current token is confirmed-synced

### Suggested backend table
`push_tokens`
- `id`
- `user_id`
- `device_install_id`
- `platform`
- `provider`
- `environment`
- `push_token`
- `token_sync_status`
- `created_at`
- `updated_at`
- `last_seen_at` (optional)
- `last_sync_attempt_at` (optional)
- `last_sync_error` (optional)
- `is_active` (optional)

Suggested constraints:
- unique `(user_id, device_install_id)`
- optional unique on `push_token`

## Step 3 — Task 22: deep-link and highlight plumbing
Implement routing before real push delivery.

This should be testable locally without real pushes by simulating a notification intent.

Suggested behavior:
- app-level notification/deep-link handler writes a pending route intent
- Remote tab consumes the intent after data has loaded
- scroll targets the item using `matchId`
- pulse border runs for ~1 second
- intent is cleared after use

Why this comes early:
A delivered push is only useful if the destination behavior is stable.

## Step 4 — Task 20: challenge received push
Once tokens and routing work, wire server-side push sending for incoming challenges.

Expected flow:
- challenger creates challenge
- backend commits challenge creation
- backend sends push to receiver device(s)
- receiver taps push
- app opens to Remote tab
- incoming challenge card is highlighted

Note:
The existing in-app Remote tab badge already covers the foreground/open-app case.
This task mainly adds background/standby delivery.

## Step 5 — Task 21: challenge accepted / match ready push
Finally wire push sending for the accept/ready event.

Expected flow:
- receiver accepts challenge
- backend commits authoritative transition to ready
- backend sends push to challenger device(s)
- challenger taps push
- app opens to Remote tab
- ready match card is highlighted

---

# Likely implementation difficulties

## 1) Token lifecycle issues
Possible problems:
- token changes after reinstall or restore
- permission granted later, not on first launch
- stale tokens remain in the database
- one user has multiple active devices

Mitigation:
- always upsert, never assume one permanent token
- support multiple tokens/devices per user
- mark invalid/stale tokens inactive when detected

## 2) Token upload failure / silent desync
The app may successfully receive a token from APNs, but fail to store it in Supabase.

Mitigation:
- track sync status for the current token locally and/or server-side
- retry upload on next app launch or next eligible lifecycle point
- avoid treating the token as usable until backend sync is confirmed

## 3) Logout/account-switch leakage
A token can remain linked to the wrong user if logout/account-switch handling is incomplete.

Mitigation:
- explicitly deactivate or detach token associations on logout
- rebind only after the next authenticated session is established
- test shared-device and tester-switch scenarios explicitly

## 4) State drift between push send and push tap
A push may say “match ready,” but by the time the user taps it the match may have changed state.

Possible examples:
- expired
- cancelled
- already moved on in the flow

Mitigation:
- never trust push payload as current state
- always fetch after tap
- resolve by `matchId`
- if exact section no longer matches, still land in Remote and surface the current truth gracefully

## 5) Duplicate pushes
Retries or race conditions could lead to duplicate notifications.

Mitigation:
- make backend sending idempotent where possible
- log event type, recipient, and `matchId`
- consider a short dedupe window if needed

## 6) Timing issues in SwiftUI scroll/highlight
The app may try to scroll before the target row exists.

Mitigation:
- treat highlight as deferred intent
- fetch first
- wait for the list to render
- then scroll and animate

## 7) Section assumptions becoming invalid
The app may expect an item to be under “incoming” or “ready,” but state may have changed before the app opens.

Mitigation:
- identify by `matchId`, not list section
- treat sections as presentation only

## 8) Foreground duplication and UX noise
If the app is open and already showing a badge, a full system-style interruption could feel redundant.

Mitigation:
- define a clear foreground presentation policy
- wire that policy through `willPresent`
- likely keep existing in-app indicators as primary while active

## 9) Emitting pushes from the wrong place
If push sending is initiated from loosely coordinated client code, false or out-of-date notifications become more likely.

Mitigation:
- send only from authoritative server-side transition points
- do not rely on client-side assumptions that a challenge was created or a match became ready

---

# Recommended acceptance test plan

## Task 19 — Token registration
- fresh install, allow permission, token stored
- app relaunch does not duplicate the same install entry unnecessarily
- reinstall / token refresh updates correctly
- same user on second device stores a second token
- token upload fails once, then succeeds on retry
- token upload fails and current token remains marked as not confirmed-synced

## Session and account handling
- logout deactivates or detaches the token association correctly
- logging into a different account on the same install does not deliver the previous user's pushes
- shared-device tester flow does not leak pushes across accounts

## Task 20 — Challenge received push
- receiver app is closed or backgrounded
- challenger sends challenge
- receiver gets push
- tapping push opens Remote tab
- incoming challenge card is highlighted

## Task 21 — Match ready push
- challenger app is closed or backgrounded
- receiver accepts challenge
- challenger gets push
- tapping push opens Remote tab
- ready match card is highlighted

## Negative and edge cases
- push permission denied
- denied state opens app settings successfully
- push arrives with a `matchId` that no longer exists
- push arrives while the user is already mid-navigation somewhere else in the app
- push payload says incoming/ready but the match has moved to another state before tap
- duplicate push delivery for the same event
- wrong environment token/send mismatch is detectable in testing
- foreground push policy behaves as intended via `willPresent`

## State-drift handling
- send push, then change match state before user taps
- app still opens to Remote and shows the correct current state

---

# Current status assessment

## What appears complete or partially complete
- Core Remote Matches foundations exist
- Server-authoritative direction is established
- In-app badge for incoming challenges is already working

## What still needs to be built for Phase 7
- device registration and token storage
- provider/environment-aware token handling
- server-side push delivery pipeline
- push event wiring for challenge received
- push event wiring for challenge accepted / match ready
- app routing from push tap
- scroll/highlight resolution in the Remote tab
- denied-permission handling and token sync reliability
- logout/account-switch safety

## Main conclusion
The current system already has a useful **foreground notification signal**.
The remaining work is primarily about building the **background/standby delivery path** and making sure notification taps resolve into a stable, authoritative navigation flow.

The three highest-priority pre-implementation decisions are:
1. **FCM vs direct APNs**
2. **Supabase delivery mechanism**
3. **Whether any existing push infrastructure should be reused**

---

# Remaining questions for feedback

1. Do we already have a stable app-wide deep-link/router entry point, or would this be the first notification-driven route?
2. Do we want any foreground presentation beyond the current Remote tab badge?
3. Should push sending include any additional dedupe or retry guardrails in v1?

---

# Proposed next move
Proceed in this order:
1. Resolve **FCM vs direct APNs**
2. Resolve **Supabase delivery mechanism**
3. Confirm **existing push infrastructure reuse**
4. Task 19 — token registration/storage
5. Task 22 — deep-link/highlight plumbing
6. Task 20 — challenge received push
7. Task 21 — challenge accepted / match ready push

This keeps dependencies clean and prevents early implementation decisions from forcing rework later.

---

# Final implementation decisions

This section closes the two main architecture decisions that were previously left open.

## Decision 1 — Push provider
**Chosen approach: direct APNs**

### Why this was chosen
- the current scope is iOS-focused
- the feature needs a simple and traceable architecture
- avoiding an extra messaging layer keeps token handling and debugging clearer
- the project does not currently need cross-platform messaging abstraction strongly enough to justify added complexity

### Practical implication
- the app will register for remote notifications directly with Apple Push Notification service
- the backend will store APNs device tokens
- token records must continue to include environment awareness where relevant (`sandbox` vs `production`)

## Decision 2 — Delivery mechanism
**Chosen approach: explicit server-side invocation of a dedicated Supabase Edge Function**

### Why this was chosen
- it keeps push sending explicit and observable
- it is easier to reason about idempotency, retries, and failure logging
- it aligns with the broader server-authoritative architecture of Remote Matches
- it avoids hiding delivery behavior behind database-trigger-driven side effects

### Practical implication
Authoritative match transition points should explicitly invoke push delivery after the transition is successfully committed.

For v1, that means:
- challenge created -> invoke push-delivery function for receiver
- challenge accepted / match ready -> invoke push-delivery function for challenger

The dedicated push-delivery Edge Function should:
- load active token records for the target user
- filter tokens by provider/environment as needed
- send the notification to APNs
- log success/failure outcomes
- deactivate invalid tokens when appropriate
- support idempotency and dedupe rules

## Final architecture position
For this project, the agreed baseline is:

- **Provider:** direct APNs
- **Delivery path:** explicit server-side call to a dedicated Supabase Edge Function

This should now be treated as the implementation baseline unless a separate project-wide infrastructure decision changes it.

---

# Final conclusion

The push-notification plan is now considered final enough to move from architecture review into implementation planning.

The remaining work is no longer about choosing the core approach. It is about executing the chosen approach cleanly:
1. direct APNs token registration and sync
2. explicit Edge Function delivery path
3. deep-link and highlight plumbing
4. event wiring for challenge received and match ready
5. logout/account safety and negative-case testing

At this stage, the document should be treated as the final planning baseline for Phase 7 push notifications.

