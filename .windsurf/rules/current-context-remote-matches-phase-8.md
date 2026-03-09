---
trigger: always_on
---

current-context-remote-matches-phase-8

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).

It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations using a server-authoritative flow

Current focus is **Remote Matches**.

---

## Current focus: Remote Matches (Phase 8)

### Phase 8 Goal: Push Notifications (live-only)
Phase 8 introduces real push notifications for Remote Matches when the user is **not actively in the app**.

This phase is specifically about:
- registering devices for push
- storing and maintaining push tokens safely
- sending push notifications for key remote-match events
- deep linking the user into the correct place in the app
- highlighting the relevant remote item after push tap

This phase does **not** treat push as a source of truth.
Push is only a **delivery mechanism**.
The app must still fetch authoritative server state after opening.

---

## Status
- Remote Matches core flows are already in place.
- There is already an **in-app notification signal** for incoming challenges:
  - when a challenger sends a remote challenge, the receiving user gets a badge on the **Remote tab** while the app is open
- Planning for push notifications is complete enough to move into implementation
- Architecture decisions for this phase have been made:
  - **Provider:** direct APNs
  - **Delivery path:** explicit server-side invocation of a dedicated Supabase Edge Function

---

## Primary requirements (Phase 8)

### 1) Push registration + token storage
The app must:
- request notification permission
- register with APNs
- receive a device token
- store/update token data in Supabase per signed-in user and install

Token handling must support:
- sync retry
- environment awareness where relevant
- logout/account-switch safety
- install-scoped identity

### 2) Push: Challenge Received
When a remote challenge is created for the receiving player:
- send a push notification if that user is not actively in the app
- tapping the push should open the app to the **Remote tab**
- the relevant incoming challenge card should be located and highlighted

### 3) Push: Challenge Accepted / Match Ready
When a challenge is accepted and the match becomes ready:
- send a push notification to the challenger
- tapping the push should open the app to the **Remote tab**
- the relevant ready match card should be located and highlighted

### 4) Deep linking + highlight behavior
Push tap handling must:
- route into the correct app destination
- fetch authoritative remote state
- locate the target item using `matchId`
- scroll to the correct card
- pulse/highlight it briefly
- degrade gracefully if the item no longer exists or changed state

---

## Key design decisions (important)

### Push provider
Use **direct APNs**.

Reason:
- current scope is iOS-focused
- simpler architecture
- fewer moving parts than introducing FCM
- easier token/debug model for this project

### Delivery mechanism
Use **explicit server-side invocation of a dedicated Supabase Edge Function**.

Reason:
- keeps push sending explicit and observable
- easier to reason about retries, failures, logging, and idempotency
- better fit for server-authoritative Remote Match transitions

### Identity model
Use an install-scoped `device_install_id`, stored locally, and associate push tokens to:
- user
- install
- environment/provider metadata as needed

### Push philosophy
Push notifications are **transport**, not truth.
The client must always fetch authoritative state after push tap.

---

## Implementation rules for this phase
- Do **not** move to the next implementation task until the current one is:
  - implemented
  - manually tested
  - reviewed
  - explicitly approved
- Keep task order strict
- If a task reveals a structural issue, stop and update the plan before continuing
- Avoid mixing multiple concerns into one implementation step

---

## Main risks to watch
- APNs environment mismatch
- token sync failure
- logout/account-switch push leakage
- duplicate sends
- deep-link timing issues before list rendering
- match state changing between push send and push tap
- foreground notification behavior becoming noisy or inconsistent

---

## Where to look first (code / system areas)
- iOS notification registration and app lifecycle entry points
- notification manager / app routing layer
- Remote tab navigation + card highlighting logic
- Remote challenge creation flow
- Remote accept / ready transition flow
- Supabase token storage path
- Supabase Edge Function delivery path

---

## Reference docs
Use these as the source of truth for execution details:
.windsurf/reference/remote-matches/remote-matches-push-plan-final.md
.windsurf/reference/remote-matches/remote-matches-phase-8-task-list.md`

Do not duplicate the full task list in this context file.
This context should remain a concise orientation document for the current phase.