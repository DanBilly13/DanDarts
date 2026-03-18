---
trigger: always_on
---

# Remote Matches — Current Context (Phase 14)

## Project Overview
This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**.

A remote match is a **live, synchronous, server-authoritative 1v1 game** backed by Supabase, with realtime updates, edge functions, and push-driven entry into the remote flow.

The feature is designed around a deterministic lifecycle:

**Pending / Sent → Ready → Lobby → In Progress → Completed / Expired / Cancelled**

Core product rules established in the FRD and execution plan:
- Remote matches are **live-only**, not async
- Gameplay is **server-authoritative**
- Clients should **react to server state**, not invent it locally
- A user may have multiple incoming/outgoing challenges, but only limited active match states at once
- When a match becomes **Ready**, other challenges are visually disabled/dimmed rather than deleted
- **Join window** and **expiry handling** are part of the official lifecycle, not edge behavior
- Existing local-game screens should be **copied and adapted**, not loosely recreated

The original rebuild guidance also established a strict dependency order:

**Lifecycle → State → Writes → Realtime → Hardening → Edge Cases**

That principle still matters in this phase.

---

## Product Shape of Remote Matches
Remote Matches currently span these major user-visible areas:

### Entry points
- Games/Home tab → Remote game cards
- Remote Games tab → Challenge a Friend flow
- Friend Profile → Challenge to remote match

### Match lifecycle screens
- Remote setup
- Remote Games tab (incoming, sent, ready states)
- Remote lobby
- Remote gameplay
- End game
- Match history / match detail integration

### Supporting systems
- Supabase match lifecycle and server validation
- Realtime subscriptions used as **triggers** to fetch authoritative state
- Push notification registration and token sync
- Voice session/signalling lifecycle attached to the remote flow
- Shared navigation/router flow across lobby → gameplay → end game

---

## Architectural Rules We Must Preserve
These are the project rules that matter most for Phase 14:

### 1. Server state is authoritative
The client must not decide that a match is still valid just because local UI state says so.

### 2. Realtime is a trigger, not truth
Realtime payloads are useful for waking the client up, but the UI should still converge on a fetched authoritative match state.

### 3. One deterministic remote flow
Voice, lobby, gameplay, and end-game handling should belong to the **remote match flow**, not to isolated screens making independent lifecycle decisions.

### 4. Terminal states must be treated as terminal
Once a match is `expired`, `cancelled`, or `completed`, the client must stop running lobby-only or entry-only side effects.

### 5. Additive, stabilizing fixes are preferred
Do not solve Phase 14 by layering more local overrides or more frozen UI state. Prefer explicit gates, hard guards, and one clear unwind path.

---

## Where the Project Stands Before Phase 14
A large amount of Remote Matches is already working:
- Challenges can be created
- Receiver can accept
- Match can move through lobby into gameplay
- Gameplay scoring and turn switching work off authoritative server state
- End game flow works
- Remote matches can complete and appear in downstream flows
- Voice is integrated into the remote flow lifecycle
- Previous work has already emphasized deterministic navigation and deterministic state ownership

However, the current system is still vulnerable around **receiver accept / enter-lobby timing**, especially close to expiry boundaries or when the lobby-entry path is slow.

That is the focus of this phase.

---

# Phase 14 Goal
## Make receiver entry into Remote Lobby deterministic and safe under expiry pressure

The main goal of Phase 14 is to stop the client from continuing into lobby flow when the match has already become invalid on the server.

In plain terms:

> If the receiver accepts a match, but the match expires before or during lobby entry, the client must not continue into a stale lobby experience.

Instead, it must detect the authoritative terminal state, unwind entry state cleanly, and return to a correct UI state without leaking voice, countdown, cancel, or lobby-specific behavior.

---

# Current Problem We Are Fixing
## Receiver can continue into stale lobby flow after the match has already expired

This issue shows up most clearly in the receiver accept path.

### What is happening
A typical bad run looks like this:
1. Receiver taps **Accept** on an incoming pending challenge
2. `acceptChallenge` succeeds
3. Client begins the receiver entry flow and starts `enterLobby`
4. `enterLobby` takes unusually long in some runs
5. While that is happening, the match crosses the expiry boundary on the server
6. The client continues using stale local entry assumptions
7. Receiver is still pushed into **RemoteLobbyView**
8. Lobby side effects begin even though the authoritative match is already `expired`

### Why that is wrong
By product and architecture rules, the client should react to server state.

If the match is expired, the lobby is no longer a valid destination.

So the bug is not that expiry happened.
The bug is that the client **continued the flow anyway**.

---

## Symptoms Seen in Logs and Behavior
The problematic receiver flow shows this pattern:
- `acceptChallenge` succeeds
- `enterLobby` sometimes becomes abnormally slow
- the enter-flow latch remains active long enough to trip the watchdog
- by the time authoritative state is fetched, the match is already `expired`
- despite that, lobby logic still runs

### Side effects that should not happen after expiry
In failing runs, the client can still do one or more of these:
- push into `RemoteLobbyView`
- start voice session/signalling
- call `confirmLobbyViewEntered`
- run lobby refresh logic
- run countdown-related behavior
- expose cancel/abort affordances intended for active lobby states

That is the exact class of stale continuation Phase 14 must eliminate.

---

## Strongest failure signature
The most important signal from the debug traces is the difference between healthy and bad `enterLobby` timing.

### Healthy runs
- receiver `enterLobby` completes quickly
- flow proceeds to lobby normally

### Bad run
- receiver `enterLobby` duration is abnormally long
- enter-flow watchdog warns the latch is still active
- authoritative fetch then shows the match is already `expired`
- client has already continued into lobby-side behavior

This tells us the issue is a **timing-sensitive stale-flow race**, exposed by slow receiver lobby entry.

---

# Root Cause
## Missing authoritative revalidation barrier before committing to lobby flow

The main root cause is:

> After receiver-side acceptance and lobby-entry work begins, the client does not enforce a hard authoritative revalidation gate before committing to lobby routing and lobby-only side effects.

In other words:
- local flow state says “we are entering”
- but server state has already moved to terminal
- and there is not yet a strong enough barrier to stop the client from continuing

That is the core bug.

---

## Secondary root cause
### `expired` is not treated as a hard terminal state early enough inside lobby handling

Even once expired state becomes visible, the lobby layer is still too permissive.

That allows expired matches to temporarily behave like live lobby matches.

Examples:
- starting voice even though the match is already invalid
- confirming lobby view entry after expiry
- showing cancel behavior that the backend correctly rejects
- doing post-confirm refresh and countdown work that assumes a still-live lobby

So Phase 14 is not only about the accept path.
It is also about **terminal-state enforcement inside lobby**.

---

# What Phase 14 Must Accomplish

## 1. Add an authoritative revalidation gate after receiver `enterLobby`
After `enterLobby` returns, the client must fetch the authoritative match and decide whether continuing is still legal.

Allowed states for continued flow should be explicitly defined, for example:
- `lobby`
- possibly `in_progress` if direct recovery is intentionally supported

Disallowed states must block continuation immediately:
- `expired`
- `completed`
- `cancelled`
- missing / invalid match
- any other terminal or inconsistent state

If the match is no longer valid, the client must **abort entry flow and not push lobby**.

---

## 2. Add one clear abort path for receiver entry flow
We need a single helper or centralized path that unwinds transient entry state cleanly.

This should clear things like:
- enter-flow latch
- nav-in-flight markers
- accept UI freeze
- processing match state
- stale pending overrides / temporary frozen card state

The system should not be left half-entering and half-aborted.

---

## 3. Treat `expired` as terminal immediately inside `RemoteLobbyView`
Lobby should not assume that appearing means the match is still valid.

At the earliest safe point, lobby must guard against terminal status and refuse to run lobby-only side effects when the match is already expired.

That means blocking or short-circuiting:
- voice startup
- confirm-lobby-view-entered
- countdown setup
- cancel/abort controls intended for active lobby states
- refresh logic that assumes the lobby is still live

---

## 4. Make terminal-state handling consistent across entry, lobby, and flow exit
If the authoritative match becomes terminal during entry or while lobby is mounted, the behavior should be deterministic:
- no stale progression
- no retry loops that keep the user inside an invalid lobby
- no backend calls that only make sense for active states
- clean UI exit or clean state reset

---

## 5. Investigate why receiver `enterLobby` can become very slow
The stale-flow bug must be fixed regardless, but the long `enterLobby` timing is still important because it is what exposes the race most dramatically.

We should instrument and understand whether the delay is caused by:
- backend lock contention
- server-side serialization / state contention
- client request suspension
- network delay
- duplicate flow coupling or request overlap

This is a reliability item, but it is still secondary to fixing stale continuation.

---

# Recommended Phase 14 Implementation Plan

## Step 1 — Trace the exact receiver accept path
Before changing logic, confirm the full order of operations through:
- accept tap
- accept UI freeze
- begin enter flow
- `acceptChallenge`
- delay before `enterLobby`
- `enterLobby`
- authoritative fetch
- route push to lobby
- lobby onAppear side effects

The goal is to make sure we know **exactly where the last safe stop point is** before stale continuation occurs.

### Deliverable
A confirmed receiver accept sequence with the authoritative gate location identified.

---

## Step 2 — Add authoritative revalidation immediately after `enterLobby`
This is the main code change.

After `enterLobby` succeeds:
- fetch authoritative match
- evaluate status before routing
- only continue if state is explicitly valid for continued flow

### Rule
No lobby route push should happen based only on stale local assumptions.

### Acceptance condition
Receiver cannot enter lobby if the fetched match is already terminal.

---

## Step 3 — Introduce a centralized `abortEnteringFlow(...)` style helper
The project needs one explicit unwind path for invalid-entry outcomes.

This helper should clear all transient entry state in one place.

### Why
This avoids the current risk of clearing one piece of state but leaving another piece active, which is exactly how stale UI flow leaks happen.

### Acceptance condition
An expired-or-invalid match leaves no stuck processing state, no frozen accept state, and no lingering nav-in-flight or latch state.

---

## Step 4 — Add hard terminal-state guards at the top of `RemoteLobbyView`
Lobby should validate state before doing lobby-only work.

### Guard targets
- voice startup
- `confirmLobbyViewEntered`
- countdown start
- post-confirm refresh
- cancel button behavior
- any other live-lobby-only side effect

### Acceptance condition
If lobby sees `expired`, it behaves as terminal immediately rather than acting like a live lobby first and correcting later.

---

## Step 5 — Fix expired lobby UX so it does not expose invalid actions
Once a match is expired:
- hide cancel actions that only apply to live pre-game states
- replace with close / dismiss / return behavior as appropriate
- do not call backend cancel for an already-expired match

### Acceptance condition
No more server 400s caused by expired-lobby UI offering impossible actions.

---

## Step 6 — Instrument `enterLobby` timing more clearly
Add logs around:
- client request start
- request sent
- server received
- server state mutation complete
- response sent
- client response received

This should let us separate:
- true server delay
- client/network delay
- lock contention
- duplicated request or lifecycle interference

### Acceptance condition
We can explain why the pathological slow runs happen, even if that work does not fully land in the first code pass.

---

# File Areas Most Likely to Change

## `RemoteGamesTab.swift`
Receiver accept path is the primary entry-point bug surface.

Most likely changes:
- post-`enterLobby` authoritative fetch gate
- block route push when match is terminal
- call centralized abort helper when entry is no longer valid

## `RemoteMatchService.swift`
This is the right place for shared flow-state cleanup.

Most likely changes:
- centralized abort / unwind helper
- latch cleanup
- accept freeze cleanup
- nav-in-flight cleanup
- flow-state consistency helpers

## `RemoteLobbyView.swift`
This is the secondary bug surface.

Most likely changes:
- terminal-state guard on appear
- no-op / block live-lobby side effects when expired
- fix cancel / dismiss behavior for expired state
- prevent voice and confirm-lobby-entry from running on terminal matches

---

# Coding Rules for Phase 14

## Rule 1 — No more optimistic continuation without authoritative re-check
A successful edge call is not enough by itself if the match may have changed state during the wait.

## Rule 2 — Terminal means terminal
`expired`, `cancelled`, and `completed` should end the path, not partially continue it.

## Rule 3 — Prefer one explicit guard over layered UI patches
Do not solve this with more card freezing, more temporary overrides, or more delayed UI hacks.

## Rule 4 — Voice must obey remote flow truth
Voice belongs to the remote flow lifecycle, but it must still not start for a lobby that is already invalid.

## Rule 5 — Stabilize first, optimize second
Even if we later improve `enterLobby` latency, the stale-flow continuation bug must already be impossible.

---

# Acceptance Criteria for Phase 14

## Core correctness
- Receiver does not enter stale lobby flow after server expiry
- Receiver accept path always revalidates authoritative state before committing to lobby continuation
- Terminal states stop flow cleanly

## UI correctness
- No stuck Accept button / processing state after invalid continuation is aborted
- No stale pending override left behind
- Expired state does not present invalid lobby controls

## Lobby correctness
- `RemoteLobbyView` does not start voice for an already expired match
- `confirmLobbyViewEntered` does not run for terminal states
- Countdown logic does not continue for expired matches

## Flow correctness
- enter-flow latch is properly cleared on abort paths
- nav-in-flight is cleared on abort paths
- no stale route push happens after invalid revalidation

## Reliability diagnostics
- pathological `enterLobby` timing is measurable and traceable
- logs clearly show where expiry happened relative to entry flow

---

# Practical Test Scenarios

## Scenario A — Healthy receiver accept
- Accept challenge well before expiry
- `enterLobby` returns quickly
- authoritative fetch says `lobby`
- route continues normally

## Scenario B — Receiver accept near expiry
- Accept close to expiry boundary
- match expires during or immediately after entry work
- authoritative fetch returns `expired`
- client aborts flow cleanly
- no lobby-only side effects run

## Scenario C — Slow `enterLobby`
- Simulate or reproduce long receiver `enterLobby`
- verify watchdog may warn, but stale continuation still does **not** happen
- client exits cleanly if state is terminal by revalidation time

## Scenario D — Expired lobby UI
- force lobby to observe `expired`
- verify no voice startup, no confirm-lobby-entry, no invalid cancel call, no countdown progression

## Scenario E — Normal lobby still works
- valid lobby still starts correctly
- valid lobby still transitions to gameplay correctly
- no regression to happy-path receiver flow

---

# Summary for W
Phase 14 is a **receiver-entry hardening phase**.

The bug is not that matches can expire.
The bug is that the client can still continue into lobby flow **after** expiry because it is missing a strong enough authoritative revalidation barrier and is not treating terminal state as terminal early enough inside lobby.

So the plan is:
1. revalidate after `enterLobby`
2. abort invalid entry cleanly
3. hard-guard lobby against terminal states
4. remove invalid expired-lobby actions
5. instrument slow `enterLobby` timing so the latency cause can be understood separately

The desired end state is simple:

> A receiver should never be able to continue into a stale remote lobby when the authoritative match is already expired.
