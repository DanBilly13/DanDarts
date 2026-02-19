---
trigger: manual
---

# Dart Freak — Remote Matches
## Full Implementation Task List (Gated Execution Plan) v1.1

> **Aligned with:** FRD v1.2 (includes implemented UI components + disabled/dimmed pending rule)

---

# Execution Model

- Work in `feature/remote-matches` branch
- Each task must be **approved** before moving to the next
- No skipping phases
- Backend is authoritative for match state + turn switching
- UI approach: **duplicate + adapt** existing local screens/components (verify you duplicated the correct screen)

---

# Completed / Already Built (UI Foundations)

These exist and should be used (not rebuilt):

- `enum RemoteMatchStatus { case pending, ready, expired }`
- `PlayerChallengeCard` (footer driven by `RemoteMatchStatus`)
- `GameCardRemote` (Remote 301 / Remote 501 entry cards; enum-driven content)

> Note: These are presentation-first and will be wired to backend state during implementation.

---

# PHASE 0 — Foundation (Design Lock)

## Task 0 — Finalize Data Model (Design Only)

### Goal
Lock the backend schema and state machine fields before building features.

### Scope
Define Match table schema, status enum, turn fields, expiry fields, and enforcement rules.

### Must Decide
- Join window duration (default 5 minutes)
- Challenge expiry duration (default 24 hours)
- Enforcement mechanism for “one Ready + one In Progress per user” (Edge Function / server logic)

### Acceptance Criteria
- Schema approved
- Status enum approved
- Expiration strategy approved
- Turn control model approved

---

# PHASE 1 — Backend Skeleton (No UI wiring yet)

## Task 1 — Create Match Table + Indexes in Supabase
- Implement approved schema
- Create status enum type (if using DB enum)
- Add indexes:
  - `(challengerId, status)`
  - `(receiverId, status)`
  - `status`
  - `joinWindowExpiresAt` / `challengeExpiresAt` (if querying by time)

### Acceptance Criteria
- Table exists
- Basic queries are performant

## Task 2 — Create Server Functions (Edge Functions / RPC)
Implement server-authoritative operations:

- Create challenge (Pending)
- Accept challenge (Pending → Ready)
- Cancel challenge (Pending/Ready/Lobby → Cancelled)
- Join match (Ready → Lobby; if both joined → In Progress)
- Save visit (In Progress; validates + switches turn)
- Expire challenge / ready / lobby (time-based → Expired)

### Acceptance Criteria
- All operations exist as server endpoints
- Invalid transitions are rejected

## Task 3 — Enforce Single Active Match Rule (Server-Side)
- A user may have only:
  - **one Ready match**
  - **one In Progress match**
- Race-condition safe:
  - First accept that creates “Ready” wins
  - Other matches remain Pending but become “disabled” by client rule (see next phase)
- Decide whether to enforce via:
  - Transaction + server check
  - Unique partial index (optional later)

### Acceptance Criteria
- Attempting to create/accept into a second Ready/In Progress match is rejected deterministically

---

# PHASE 2 — Remote Tab + Challenge Lists (Wire to Backend)

## Task 4 — Remote Games Tab Skeleton
Build the Remote bottom-tab view composed of existing components:

Sections:
- **Match Ready** (priority)
- **You’ve been challenged** (incoming Pending)
- **Sent challenges** (outgoing Pending)

Use:
- `PlayerChallengeCard` for each row
- `RemoteMatchStatus` to drive footer actions

### Acceptance Criteria
- Remote tab displays server-backed lists for incoming/outgoing/ready

## Task 5 — Disabled/Dimmed Pending Rule in UI
When a match becomes **Ready** for the user:
- All other pending challenges are shown but **disabled/dimmed**
- They are not actionable (buttons disabled)
- If Ready match is cancelled/expired:
  - Pending challenges that are still within expiry become actionable again

### Acceptance Criteria
- Visual dim/disable works
- No toast required to explain disappearance/changes

## Task 6 — Footer Actions Hookup (Pending/Ready/Expired)
Wire `PlayerChallengeCardFoot` actions:

- Pending incoming:
  - Accept → server accept → produces Ready (if allowed)
  - Decline → server cancel/decline (Cancelled)
- Pending outgoing:
  - Cancel → server cancel
- Ready:
  - Join now → server join → Lobby / In Progress
- Expired:
  - No actions (informational)

### Acceptance Criteria
- Buttons call correct server actions
- States update via realtime subscription

---

# PHASE 3 — Create Challenge Flow (Entry Points)

## Task 7 — Games/Home: Remote Game Cards
- Use existing `GameCardRemote` for Remote 301 / 501
- Tap → navigates to Remote Setup

### Acceptance Criteria
- Both cards render and navigate

## Task 8 — Remote Setup Screen (Duplicate + Adapt)
Duplicate existing 301/501 setup screen and adapt for remote:

- No “add players”
- User is implicitly Player 1
- Choose match format (Best of 1/3/5/7)
- Choose opponent sheet
- CTA morph:
  - “Choose opponent” → “Send challenge”

**Verification Step**
- Confirm you duplicated the correct local screen
- Confirm styling matches local setup screen

### Acceptance Criteria
- User can configure format + pick opponent + send challenge (server create Pending)

## Task 9 — Choose Opponent Sheet
- Single selection
- Checkmark briefly visible before dismiss
- Uses existing search/friends data source

### Acceptance Criteria
- Selecting opponent returns to setup with opponent filled

## Task 10 — Friend Profile Entry
- “Challenge to a remote match” button
- Modal choose game (301/501)
- Routes to Remote Setup with opponent pre-filled
- Send challenge → auto switch to Remote tab

### Acceptance Criteria
- Works end-to-end

---

# PHASE 4 — Lobby + Match Start

## Task 11 — RemoteLobbyView (Duplicate + Adapt)
- Waiting state (“waiting for opponent to join”)
- Join window countdown visible
- Cancel match (no penalty)

### Acceptance Criteria
- Ready → Lobby transition works
- Both join → transitions to In Progress

## Task 12 — Expiration UX
- Ready/Lobby expiration shows Expired card state
- Pending challenges become actionable again if appropriate

### Acceptance Criteria
- Expired states are clear and deterministic

---

# PHASE 5 — Live Gameplay (Turn-Based)

## Task 13 — Remote GameView (Duplicate + Adapt)
Duplicate existing local 301/501 GameView and adapt:

- Reads match state from backend
- Shows two cards (red/green identity fixed)
- Turn indicated by which card is at the front

### Acceptance Criteria
- Remote GameView renders correct players and scores

## Task 14 — Turn Lockout + Save Visit (Server-authoritative)
- Only active player can input
- Save Visit calls server
- Server updates score + lastVisit + switches currentPlayerId
- Prevent duplicate saves server-side

### Acceptance Criteria
- Inactive player cannot input
- Saves are validated and consistent

## Task 15 — Reveal Delay + Rotation Animation
- After server ack, show last visit to both players
- 1–2s reveal window
- Rotate front card to indicate turn switch
- Unlock input for next player

### Acceptance Criteria
- Turn switches feel “live”
- No confusing instant flip

---

# PHASE 6 — Completion + History

## Task 16 — Completion State (Server)
- Detect checkout and mark Completed server-side
- Set winnerId
- Prevent further saves

### Acceptance Criteria
- Completed is authoritative and consistent

## Task 17 — EndGameView + Match Detail
- Navigate to existing EndGameView
- Provide actions:
  - View match details
  - Play again
  - Back to Games

### Acceptance Criteria
- Works for remote matches without breaking local

## Task 18 — History Integration
- Completed match appears in History tab
- Match detail uses existing pipeline

### Acceptance Criteria
- History shows remote matches reliably

---

# PHASE 7 — Push Notifications (Live-only)

## Task 19 — Push Registration + Token Storage
- Request permission
- Store device token(s) per user in Supabase

### Acceptance Criteria
- Token stored and updated

## Task 20 — Push: Challenge Received
- Send push when challenge created for receiver
- Deep link to Remote tab and highlight incoming challenge

### Acceptance Criteria
- Receiver sees push when app closed

## Task 21 — Push: Challenge Accepted / Match Ready
- Send push when receiver accepts
- Deep link to Remote tab and highlight Ready match

### Acceptance Criteria
- Challenger sees push when app closed

## Task 22 — Deep Linking + Highlight
- Route to Remote tab
- Scroll/highlight relevant match card (pulse border 1s)

### Acceptance Criteria
- Push tap lands in correct place

---

# PHASE 8 — Hardening + QA

## Task 23 — Background/Resume State Restore
- If app closed mid-match, restore correct view on return
- Resubscribe to realtime updates

### Acceptance Criteria
- No “stuck” states

## Task 24 — Network Failure Handling
- Save retry UX
- Disable duplicate inputs while pending

### Acceptance Criteria
- No score corruption

## Task 25 — Race Condition Testing
- Simulate simultaneous accept
- Simulate join at same time
- Simulate simultaneous save attempts

### Acceptance Criteria
- Deterministic outcomes

## Task 26 — Visual Consistency Pass
- Verify duplicated screens match originals
- Ensure spacing, typography, rounding matches design system
- Confirm red/green identity usage is consistent

### Acceptance Criteria
- UI feels native to existing app

## Task 27 — End-to-End Test Pass
- Create → accept → ready → lobby → in progress → complete
- Cancel/expire paths
- Push paths

### Acceptance Criteria
- Remote matches v1 meets FRD

---

# Definition of Done (Remote Matches v1)

- Live synchronous 1v1 remote play for 301/501
- Push notifications working (challenge received + accepted)
- Server-authoritative turn control
- Single Ready + single In Progress match per user
- Disabled/dimmed pending challenges while Ready exists
- Deterministic match lifecycle
- Challenger = Red, Receiver = Green throughout

---

This task list governs implementation of the `feature/remote-matches` branch.
