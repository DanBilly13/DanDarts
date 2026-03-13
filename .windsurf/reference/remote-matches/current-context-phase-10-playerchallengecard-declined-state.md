

current-context-phase-10-playerchallengecard-declined-state

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).

It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations using a server-authoritative flow

This context is for a **single tightly scoped Phase 10 task**:
adding a new **declined** presentation state to `PlayerChallengeCard` for the challenger.

---

## Current task
Add a new `PlayerChallengeCard` state called **declined**.

Goal:
- when the **receiver declines** a challenge
- the **challenger** should briefly see a **declined** card state
- then the card can disappear according to the agreed cleanup timing

This task is specifically about the **challenge card / remote list presentation flow**.

It is **not** a broad refactor of Remote Match lifecycle.

---

## Critical warning
We previously spent significant time fixing a fragile bug where the `PlayerChallengeCard` and/or its parent remote list view would:

- flicker
- reload repeatedly
- jump between states
- briefly show the wrong state
- change state before both users eventually entered the lobby

That flow is now working well.

### Highest priority for this task
**Do not break the existing stable transition behavior.**

Especially do not break:
- the transition from challenge state into lobby/join flow
- the state-freezing / latching behavior used during enter/join flow
- the current anti-flicker protections in card rendering and remote list updates

If a proposed solution risks destabilizing that flow, stop and choose the smaller safer approach.

---

## Key architectural guidance

### 1) Distinguish database state from UI presentation state
This is extremely important.

Not every card state should become a new stored database state.

Example:
- `.sent` is a **UI-only state**
- database stores sent challenges as `.pending`
- the challenger sees `.sent` because the UI maps the shared backend state into a challenger-specific presentation state

That pattern should be treated as a precedent.

### 2) The new `.declined` state should be treated the same way unless there is a very strong reason otherwise
Preferred approach:
- keep backend lifecycle/state model as stable as possible
- derive challenger-facing `.declined` as a **UI presentation state** from existing authoritative data/events
- avoid introducing a new database enum/state unless it is clearly required everywhere in the system

### 3) Push is transport, not truth; UI mapping is presentation, not truth
The client should continue to react to authoritative remote state and then map that into the correct local presentation state.

Do not invent extra local state machines if the same effect can be achieved by a thin, deterministic presentation mapping layer.

---

## Working assumptions for this task
Unless code inspection proves otherwise, start from these assumptions:

- sent challenges are represented in the UI using `.sent`
- backend/shared match state for that card is still `.pending`
- challenger and receiver may legitimately see different card presentations from the same underlying authoritative state
- decline handling may need:
  - a UI-only declined presentation
  - toast for challenger (`"Match declined"`)
  - badge cleanup
  - delayed removal of the card after the declined state is shown

These should be layered onto the existing flow carefully, not by rewriting it.

---

## Safe implementation strategy
For this task, prefer this order of thinking:

1. inspect the current remote challenge state mapping path
2. identify where `.pending` becomes `.sent` for challenger presentation
3. add `.declined` using the same kind of thin presentation mapping
4. keep the existing enter/lobby freeze logic intact
5. keep card identity and list identity stable
6. avoid forcing extra reloads or full list resets just to show declined
7. only after that, handle toast + cleanup timing

---

## Things that are likely dangerous
Avoid these unless clearly necessary:

- changing the authoritative backend enum/state model broadly
- introducing a brand-new persisted remote lifecycle state without proving the need
- changing `ForEach` identity/signatures in the remote list
- resetting or recreating the whole remote list just to show declined
- removing or bypassing the current freeze/latch logic used during enter flow
- mixing decline-state work with unrelated remote-card refactors

---

## Desired user-facing behavior
When the receiver declines:

### Challenger should experience:
1. existing challenge card transitions into a **declined** presentation state
2. challenger sees toast: **Match declined**
3. badge/UI cleanup happens correctly
4. card disappears after a short, intentional delay

### Receiver should experience:
- their side should complete the decline flow cleanly
- no stale badge or stale ready/waiting text should remain

---

## Important implementation principles
- Prefer **smallest safe change**
- Prefer **presentation mapping** over backend lifecycle expansion
- Preserve existing stable lobby/join behavior
- Preserve stable card identity
- Preserve current anti-flicker protections
- If a solution requires broad changes to remote status handling, assume it is too risky until proven otherwise

---

## Where to inspect first
- `PlayerChallengeCard.swift`
- `RemoteGamesTab.swift`
- `RemoteMatchService`
- any current mapping from backend/shared match status -> `PlayerChallengeCard` state
- any existing latch/freeze logic protecting enter/lobby flow
- decline/cancel badge cleanup path
- toast path for remote match events

---

## What Windsurf should do for this task
For this task, do **not** jump straight into implementation.

First:
1. inspect the relevant files
2. explain the current state-mapping path
3. identify where `.sent` is derived from `.pending`
4. propose the smallest safe way to add `.declined`
5. explicitly explain why the proposed approach should not break the stabilized lobby-entry flow

Only then should implementation begin.

---

## Success criteria
A good solution for this task will:

- add a challenger-visible `.declined` state
- preserve the current stable card/list behavior
- avoid flicker/regression in lobby-entry flow
- avoid unnecessary backend lifecycle changes
- keep the implementation narrow and reviewable
