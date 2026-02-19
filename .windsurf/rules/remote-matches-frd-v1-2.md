---
trigger: manual
---

# Dart Freak — Remote Matches
## Feature Requirements Document (FRD) v1.2

> **Status:** Draft (aligned to latest UI notes + initial component build)  
> **Scope:** Live-only 1v1 remote matches for **301** and **501**

---

## 1. Overview

Remote Matches allow two friends to play a **live, head-to-head** darts match from different locations.

- Matches are **synchronous** (both players online at the same time)
- Turn-taking is **server-authoritative**
- Remote matches reuse existing local-game UI patterns where possible, with targeted adaptations

This feature introduces:
- Real-time match state management
- Turn-based synchronization
- Push notifications (real notifications, not just in-app)
- Match lifecycle handling (pending → ready → lobby → in-progress → completed)

---

## 2. Goals

- Enable **live** 1v1 remote play (301 / 501)
- Keep match lifecycle **deterministic** and easy to reason about
- Ensure a user can only have **one “Ready/Joinable” match** and **one “In Progress” match**
- Use push notifications so challenges work when users are not in the app
- Preserve role identity:
  - **Challenger = Red**
  - **Receiver = Green**
  - (These colors must persist into Match Detail / Stats screens)

---

## 3. Non-Goals

Explicitly out of scope for v1:
- Async (chess-style) turns
- Ranked / matchmaking / ladders
- Turn timers
- Turn reminders / nudges
- Match scheduling
- Multiple concurrent active matches per user
- Penalty / reputation systems

---

## 4. Core Rules

### Challenges & Concurrency
- A user may **receive multiple** incoming challenges (**Pending**).
- A user may **send multiple** outgoing challenges (**Pending**).
- A user may have **only one Ready match** at a time.
- A user may have **only one In Progress match** at a time.

### What happens when a match becomes “Ready”
When a match becomes **Ready** (i.e., both sides have accepted and it’s joinable):

- All other pending challenges (incoming + outgoing) are **disabled / dimmed** in UI (not deleted).
- Disabled challenges are **not actionable** while a Ready match exists.
- If the Ready match is **cancelled** or **expires**, any other challenges that are still within their expiry window become actionable again.

> This preserves clarity (“what just happened?”) without a toast, by visually showing other items are temporarily locked.

### Expiry Window
- Challenges **auto-expire** after a configured window (e.g., **24h**)  
- Ready join window (see below) is separate from “challenge expiry”.

### Join Window (Live requirement)
Once the match is **Ready**, players must join within the join window:
- **Join Window:** e.g. **5 minutes**
- If not joined in time → **Expired**
- No penalties for cancel/expire in v1

---

## 5. Match Lifecycle

### States
- **Pending** (challenge exists; awaiting accept)
- **Ready** (both accepted; joinable within join window)
- **Lobby** (one player joined; waiting for the other)
- **In Progress**
- **Completed**
- **Expired**
- **Cancelled**

### Allowed Transitions (server-controlled)
- Pending → Ready
- Ready → Lobby
- Lobby → In Progress
- Ready → Expired
- Lobby → Expired
- Ready → Cancelled
- Lobby → Cancelled
- In Progress → Completed

> **Important:** Clients do not “decide” state—clients react to server state.

---

## 6. Entry Points & UX Flows

### A) From Games (Home) Tab
- Games → **Remote games** section (Remote 301 / Remote 501 cards)
- Tap Remote 301/501 → **Game Setup (Remote)**  
- Choose match format (Best of 1/3/5/7)
- **Choose opponent** (sheet)
- Back to setup with opponent selected
- **Send challenge**
- After sending: **auto-navigate/switch to Remote tab** (RemoteGamesTab) and show the new challenge under **Sent challenges**

### B) From Remote Games Tab (bottom tab)
- Remote tab → **Challenge a Friend**
- Choose game (301/501) → Game Setup (Remote)
- Choose opponent → Send challenge
- Return to Remote tab (with the sent challenge visible under Sent challenges)

### C) From Friend Profile
- Friend profile → **Challenge to a remote match**
- Dialog: choose game (301/501)
- Navigate to Game Setup (Remote) with **opponent pre-filled**
- Choose match format
- **Send challenge**
- Then: auto route to Remote tab, show under Sent challenges

---

## 7. UI Implementation Notes (important for accuracy)

A lot of screens are **adaptations of existing local flow screens**. The intent is:

- **Copy + adapt** the existing local screens/components rather than re-creating loosely from screenshots.
- This reduces “half-right” UI and prevents regressions.

### Reuse/Adapt Strategy (high level)
- **RemoteGameSetupView**: adapt from existing 301/501 GameSetupView
  - Remote: user is implicitly Player 1 (no “add yourself” step)
  - Use **Choose opponent** flow instead of local “Add players”
- **ChooseOpponentSheet**: adapt from existing SearchPlayerSheet
- **RemoteGamesTab**: new screen (but using existing card components / styling patterns)
- **RemoteLobbyView**: adapt from existing PreGameHypeView
- **GameView**: copy existing local 301/501 game view and adapt for remote lockout + synced turns
- **GameEndView** and **MatchDetailView**: reuse existing versions

---

## 8. Push Notification Requirements

This feature needs “real” push notifications (APNs via FCM or direct APNs), so users see requests while not in the app.

### Required notification events
1) **Challenge Received**
- Deep link → Remote tab
- Highlight that incoming challenge card

2) **Challenge Accepted / Match Ready**
- Deep link → Remote tab
- Highlight Ready match card (“Match ready — {name} accepted”)

3) **Match Starting** (optional for v1)
- Only if we find it necessary; not required to ship v1

> No turn-by-turn push in v1. This is “live right now” play.

---

## 9. Gameplay Mechanics (Live, synchronous)

### Identity (static)
- Challenger = **Red**
- Receiver = **Green**
These colors persist across:
- in-game player cards
- results
- match details/stat bars

### Turn indication (dynamic)
- “Whose turn” = the player card **at the front**
- The other player card is behind

### Turn flow (authoritative)
1. Active player throws 3 darts
2. Active player enters darts and taps **Save Visit**
3. Server validates + persists visit, updates scores, and switches turn
4. Both clients briefly show the saved visit result (1–2s reveal)
5. Card rotation animation runs
6. Next player becomes active; input unlocks

### Input lock rules
- Only active player can input
- Inactive player sees the board state but cannot interact
- Save button disabled after submission and until server ack

---

## 10. End of Match

- Player reaches exactly 0 (double-out rules still apply if used in the game rules)
- On Save Visit:
  - match becomes **Completed**
  - show Winner state (no further rotation)
  - navigate to existing **EndGameView**
  - from there: View Match Details, Play Again, or Back to Games
- Match appears in History tab using existing pipeline

---

## 11. Edge Cases

- App closes mid-turn → match continues; on resume, subscribe and render current state
- Join window expires → Expired state + UI explanation
- Network delay during Save → UI waits for server confirmation
- Duplicate Save attempts prevented server-side
- Race conditions:
  - First acceptance that produces “Ready” wins; other pending challenges become disabled (not deleted)
- User manually closes a Ready card:
  - v1 assumption: **no penalty**
  - match can still expire naturally or be cancelled (explicitly)

---

## 12. Technical Requirements

### Backend
- Matches table with:
  - status
  - challengerId / receiverId
  - currentPlayerId
  - scores (or legs/sets model)
  - lastVisit payload (for “reveal”)
  - joinWindowExpiresAt
  - challengeExpiresAt
- Server-authoritative:
  - validate visits
  - switch turns
  - advance legs/sets
  - set Completed
- Push token storage per user
- Function/worker for push delivery on events

### iOS
- Push registration + permission flow
- Deep link routing to Remote tab + specific match
- Realtime subscription to match updates
- Lockout UI states for non-active player
- Rotation animation + 1–2s “visit reveal” timing

---

## 13. Implemented UI Components (pre-backend wiring)

These exist in the codebase and should be treated as the UI foundation for Remote Matches.

### `enum RemoteMatchStatus`
Used to drive challenge card presentation and footer actions:

```swift
enum RemoteMatchStatus {
    case pending
    case ready
    case expired
}
```

### `PlayerChallengeCard`
A reusable card component for remote challenges and match-ready states.
- Uses `RemoteMatchStatus` to render the footer:
  - `pending` → Accept / Decline
  - `ready` → Join/Start flow (wording may vary by direction)
  - `expired` → Timeout UI
- Intended to appear in Remote tab sections:
  - “You’ve been challenged” (incoming)
  - “Sent challenges” (outgoing)
  - “Match ready” (priority state)

### `GameCardRemote`
A reusable game card for **Remote 301** and **Remote 501** entry points.
- Drives content via a small game-type enum (e.g., 301 vs 501)
- Card copy: “Remote {game}” + strapline (currently: “Play together. Apart.”)
- Used in Games/Home tab under the “Remote games” section

> Note: These components are currently **presentation-first** and will be wired to live backend state during implementation.

---

## 14. Summary

Remote Matches v1 are **live, synchronous, head-to-head** games between friends.
The design prioritizes:
- clarity
- determinism
- reusing existing screens/components (copy + adapt)
- minimal complexity (no async/timers/scheduling)

This document is the contract for the `feature/remote-matches` branch.
