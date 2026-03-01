---
trigger: manual
---

# Remote Matches — Phases 1–3 (Summary + What We Changed)

This document captures the work completed in **Phases 1–3** for Remote Matches so we don’t lose context.  
Scope: **Remote match creation → acceptance → join → lobby → gameplay transition**, plus **realtime stability**.

---

## Phase 1 — Remote Match Plumbing (Create / Accept / Join)

### Goal
Establish the server-backed “remote match” lifecycle so two users can create a challenge, accept it, and both end up looking at the same match record.

### What we put in place
- **Match record lifecycle** (Supabase `matches` table / record):
  - `remote_status`: `pending` → `ready` → `lobby` → `in_progress` → `expired`/`ended`
  - `challenger_id`, `receiver_id`
  - `join_window_expires_at` (time window for both players to join)
  - `challenge_expires_at` (time window for invite acceptance)
  - `current_player_id` (set when gameplay begins)
- **Edge Functions** (server authoritative transitions):
  - `create-challenge`
  - `accept-challenge`
  - `join-match`
- **Client service calls** (RemoteMatchService / similar):
  - `createChallenge(...)`
  - `acceptChallenge(matchId)`
  - `joinMatch(matchId)`
  - `fetchMatch(matchId)` for authoritative refresh after key transitions
- **Basic UI list states** (RemoteGames tab):
  - Incoming pending challenges (Accept)
  - Sent challenges (Pending)
  - Ready matches (Join / Enter)

### Success criteria (Phase 1)
- Challenger can send a challenge.
- Receiver can see it appear and accept.
- Both clients can **join** the same match id and fetch it successfully.
- Match status transitions happen **server-side**, not via client “guessing”.

---

## Phase 2 — Navigation + Reliable Lobby Entry (Approved)

### Goal
Make the remote flow *navigation* reliable: both players can **enter Lobby**, and the app doesn’t glitch due to competing list refreshes / navigation state.

### What we changed / locked in
- **Single NavigationStack flow** (push-based navigation, not modal) so the remote flow behaves predictably.
- **Consistent navigation title mode** across parent + destinations to avoid known SwiftUI glitches (large vs inline title animation issues).
- **Stable “enter lobby” sequence**:
  - Receiver accepts → joins → fetches authoritative match → pushes Lobby.
  - Challenger joins → fetches authoritative match → pushes Lobby.
- **Lobby view refresh pattern**:
  - On appear: fetch current match state (authoritative).
  - Manual refresh available for debugging.

### Success criteria (Phase 2)
- Both players can reach Lobby reliably (this phase was marked complete/approved).
- Navigation does not bounce, pop unexpectedly, or “twitch”.
- Both players see consistent match identity (same `matchId`).

---

## Phase 3 — Realtime as Signal Only + Flow Gate (Approved / Working)

### Problem we were solving
Realtime INSERT/UPDATE handlers were triggering immediate `loadMatches()` list reloads, which could interfere with navigation when users were in the remote flow (Lobby / Gameplay).

### Goal
Use realtime as a **signal** only:
- While in remote flow, do **not** reload lists.
- Still keep the active match fresh (targeted fetch).
- Throttle bursty events.

### Key changes (what got implemented)
#### A) Flow Gate
- Added `isInRemoteFlow` flag in `RemoteMatchService`.
- Exposed `setRemoteFlowActive(true/false)` to toggle it.
- Set flow gate:
  - `RemoteLobbyView` onAppear/onDisappear
  - `RemoteGameplayPlaceholderView` onAppear/onDisappear

#### B) Throttling
- Added two throttled schedulers:
  - **List reload throttle** (e.g. ~400ms): coalesce `loadMatches()` calls.
  - **Active match fetch throttle** (e.g. ~250ms): coalesce `fetchMatch(matchId)` calls.

#### C) Realtime handlers updated
- INSERT/UPDATE handlers now do:
  - `scheduleActiveMatchFetch(matchId)` (always safe)
  - `scheduleListReload(userId)` only if `isInRemoteFlow == false`
  - keep badge notifications intact

#### D) Cleanup hardened
- `removeRealtimeSubscription()` cancels pending throttled tasks so no orphan tasks remain.

### What “working” looked like in logs
- In Lobby/Gameplay:
  - `⏭️ Skipping loadMatches (in remote flow)`
  - `fetchMatch(flow)` or `fetchMatch(active)` continues to run
- On RemoteGamesTab:
  - `loadMatches (throttled)` runs normally

### Success criteria (Phase 3)
- Realtime no longer breaks navigation.
- UI updates correctly in Lobby/Gameplay via targeted `fetchMatch`.
- Lists update on tabs via throttled reload.
- Both devices show real-time changes (debug_counter test proved it).
- Expiration / invalid states can kick you back safely (popToRoot) when match becomes unplayable.

---

## Where we ended after Phase 3
- Remote flow reliably reaches:
  - Challenge → Accept → Join → Lobby → Gameplay transition.
- Realtime behavior is “safe”:
  - Doesn’t spam list reloads during remote flow.
  - Still keeps the match state fresh.
- Gameplay is still on the **temporary gameplay placeholder**, used to validate sync + updates.

---

## Notes / Gotchas to remember going into Phase 4
- **Player identity colors** are consistent (Player 1 red, Player 2 green) and must remain stable through match summary.
- The local match UX includes a **rotating player card stack** (current player “front”). This must be carried into remote gameplay.
- Remote gameplay should reuse the existing **local 301/501 engine**, not rebuild scoring from scratch.

