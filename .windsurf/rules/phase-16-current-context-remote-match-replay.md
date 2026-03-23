---
trigger: manual
---

# phase-16-current-context-remote-match-replay

## Project Overview
This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**.

A remote match is a **live, synchronous, server-authoritative** game between two players. The established remote lifecycle is:

- **Pending** (incoming challenge)
- **Sent** (outgoing challenge)
- **Ready** (accepted and joinable)
- **Lobby** (one or both players entering, waiting to start)
- **In Progress**
- **Completed**
- **Expired**
- **Cancelled**

Remote Matches reuse existing local-game UI where possible, with targeted adaptation for remote state, realtime updates, push, and remote gameplay flow.

This new phase focuses on adding a **Replay / Rematch** experience after a remote match completes.

---

## Current Product Context
The current remote feature already supports the core lifecycle successfully:

1. Challenger sends invite
2. Receiver accepts
3. Match becomes **Ready**
4. Both players enter **Lobby**
5. Voice connects
6. Countdown starts
7. Match enters **In Progress**
8. Match completes and both users land on **EndGameView**

The remote lobby and voice-connect flow are now behaving well and should be treated as **stable foundations**.

---

## Phase 16 Goal
Add a **remote match replay/rematch flow** from **EndGameView** that feels natural, fast, and polished **without destabilising the current remote architecture**.

The product goal is:

- players finish a remote match
- both land on **EndGameView**
- one player taps **Play Again / Rematch**
- the other player can **accept or decline**
- if both agree, a **new remote match** is created using the **same game configuration**
- both players move back into the normal remote flow and start another match

---

## Key Product Principle for This Phase
This phase should favour:

- **reuse over invention**
- **existing lifecycle over special-case flows**
- **80% great UX if it is dramatically safer/faster to ship**
- **minimal new moving parts**

We do **not** want to create a highly custom rematch architecture if the same outcome can be achieved by reusing the existing Remote Matches lifecycle.

---

## Agreed UX Direction (Phase 16 Baseline)

### Core Approach
Treat replay/rematch as a **prefilled normal remote challenge**, not a completely separate match system.

That means:
- a new match record is created for the replay
- it reuses the same game config as the just-finished match
- it follows the existing remote lifecycle as much as possible
- clients should still **react to authoritative server state**, not invent client-only match states

### EndGame Replay UX

#### Player A (first player to tap rematch)
- taps **Play Again**
- an in-app overlay opens on top of **EndGameView**
- that overlay uses the existing **PlayerChallengeCard** in the **Sent** state

#### Player B
- receives a replay request while still on **EndGameView**
- the replay request is presented as an **in-app overlay on top of EndGameView**
- that overlay uses the existing **PlayerChallengeCard** in the **Pending / Accept / Decline** state
- Player B can **Accept** or **Decline**

### On Accept
If Player B accepts:
- a new replay match is confirmed
- Player B may enter the lobby immediately
- Player A’s overlay updates to the existing **PlayerChallengeCard** in the **Ready** state with the **Join now** button
- replay then continues through the normal remote flow

### On Decline
If Player B declines:
- Player B taps decline
- after a short pause the overlay fades away and Player B returns to plain **EndGameView**
- Player A’s overlay updates to the existing **PlayerChallengeCard** in the **Declined** state
- after a short pause that overlay also fades away and Player A returns to plain **EndGameView**
- both players remain in normal post-match state
- no hidden or ambiguous failure state

---

## Preferred Implementation Strategy

### Recommended strategy for Phase 16
Use the **existing remote challenge / ready / lobby flow** as the base.

That means the replay system should try to reuse:
- existing match creation patterns
- existing accept/decline semantics
- existing **PlayerChallengeCard** states and presentation rules
- existing ready/join/lobby transitions
- existing lobby countdown and voice-ready behaviour
- existing navigation patterns

### Important nuance
This should still **feel** like replay to the user, even if internally it behaves like a specially seeded normal remote match.

The UI can be replay-specific while the state machine remains familiar to the system.

---

## Voice Requirement

### Desired behaviour
**Keep voice connected** across:
- EndGameView
- replay request / accept moment
- transition into replay lobby

This is an important polish goal because it makes replay feel continuous:
- players can finish the match
- talk to each other
- agree to play again
- replay begins without the experience feeling broken or reset

### Guidance
Voice continuity is a **strong preference**, but implementation should still avoid destabilising the existing remote flow.

If voice continuity can be preserved safely while replay creates a new match, that is preferred.

If preserving voice would introduce major architectural risk, the replay flow should still be implemented using the stable remote replay/challenge/lobby approach first.

---

## UX Priorities in Order
1. **Reuse existing remote match flow** wherever possible
2. **Reuse the existing PlayerChallengeCard and its established states**
3. **Keep replay easy to understand on EndGameView**
4. **Preserve voice connection if safe**
5. **Avoid introducing brand-new complicated states unless clearly necessary**
6. **Do not destabilise lobby/gameplay/navigation that already took a long time to stabilise**

---

## What This Phase Is Not
This phase is **not** trying to build:
- a fully bespoke instant rematch engine
- a no-lobby auto-start rematch flow
- a new alternate remote lifecycle
- a large backend redesign
- a complex matchmaking or queue system

This phase is specifically about a **practical replay feature** built on top of the remote system that already works.

---

## Reuse / Adapt Guidance
The replay feature should strongly consider reusing these existing concepts:

- **EndGameView** as the replay entry surface
- existing remote **challenge creation** behaviour, but seeded from completed match config
- existing **accept / decline** semantics
- existing **PlayerChallengeCard** UI and its existing states
- existing **Ready** and **Lobby** transitions
- existing **RemoteLobbyView** behaviour for match starting
- existing countdown/start logic once both players are ready

The second player’s replay prompt may be presented differently in UI location (overlay on EndGameView), but should still map onto the existing remote challenge model and the same card states already used elsewhere in the feature.

---

## Suggested Replay Flow (Top-Line)

### Happy path
1. Remote match completes
2. Both players land on **EndGameView**
3. Player A taps **Play Again**
4. System creates replay request / replay match using same config
5. Player A sees overlay with existing **PlayerChallengeCard** in **Sent**
6. Player B sees overlay with existing **PlayerChallengeCard** in **Pending**
7. Player B taps **Accept**
8. Player B may enter **Lobby**
9. Player A’s overlay updates to existing **PlayerChallengeCard** in **Ready**
10. Player A taps **Join now**
11. Both players are in **Lobby**
12. Voice remains connected if safely possible
13. Countdown starts
14. New match begins

### Decline path
1. Player A taps **Play Again**
2. Player B sees replay request overlay and taps **Decline**
3. Player B’s overlay fades away after a short pause
4. Player A’s overlay updates to existing **Declined** card state
5. Player A’s overlay fades away after a short pause
6. Both remain on existing end-game/post-match surfaces

---

## Constraints / Guardrails

### Architecture guardrails
- Do not bypass server-authoritative state
- Do not create client-only lifecycle truth
- Do not add fragile special-case navigation if existing routing can be reused
- Do not introduce major complexity into already-stable lobby/gameplay flows unless unavoidable

### Product guardrails
- replay should feel faster than starting a brand-new remote match manually
- but it does **not** need to be perfect if that introduces major risk
- prefer a slightly less magical UX that is much safer to ship

---

## Main Risks

### 1. State duplication risk
The biggest risk is creating two sources of truth:
- replay overlay UI state on **EndGameView**
- actual remote match lifecycle state from the backend

If replay becomes “part overlay system” and “part remote match state,” it becomes easy for the UI to drift from reality.

This can cause:
- wrong PlayerChallengeCard state shown
- one player seeing Sent while the other already moved to Ready
- stuck overlays
- overlays not dismissing after decline/cancel
- navigation happening from stale client assumptions

### 2. Navigation timing risk
Replay introduces a new entry point into the remote flow from **EndGameView**, not from **RemoteGamesTab**.

That means even if backend state is correct, there is still risk in:
- overlay visibility during navigation
- one player entering Lobby while the other still sees stale overlay/card state
- transition timing conflicts
- replay accept/update arriving while another EndGameView update is running

### 3. Voice continuity risk
Keeping voice connected is desirable, but it is also the riskiest polish requirement.

The completed match and the replay match are different matches.
If voice is tightly coupled to the old match lifecycle, carrying it across replay can create problems such as:
- stale signalling state
- duplicate subscriptions
- incorrect cleanup
- route/audio-session issues
- replay decline/cancel leaving voice in the wrong state

### 4. Fake reuse risk
Reusing **PlayerChallengeCard** is the right direction, but it becomes risky if that reuse is implemented by adding many replay-only conditionals and branches.

If the card becomes heavily special-cased for replay, then reuse becomes harder to reason about and may destabilise existing RemoteGamesTab behaviour.

### 5. Edge-case cleanup risk
The happy path is relatively straightforward.
The harder cases are:
- Player A sends replay and leaves the screen
- Player B declines late
- one player disconnects
- replay request expires
- double taps / repeated replay attempts
- replay exists while other realtime updates arrive

These cases can leave orphaned overlays, stale card state, or confusing post-match UI unless cleanup rules are explicit.

---

## Risk Mitigation Direction

### Keep the backend authoritative
Replay overlays should be driven by the same remote state model, not by standalone client-only replay state.

### Treat EndGameView overlay as presentation, not a second system
The overlay should present the same **PlayerChallengeCard** states that already exist, rather than inventing a parallel replay-only state machine.

### Reuse the proven remote transitions
Accepted replay should move through the same broad structure already used elsewhere:
- challenge created
- accepted
- ready
- lobby
- countdown
- start

### Keep voice continuity as a preference, not a reason to destabilise the flow
If voice can continue safely across replay, that is preferred.
If it requires major new lifecycle complexity, the replay feature should still ship on top of the stable remote flow first.

### Be strict about cleanup
Replay decline, cancel, expiry, or abandonment should always resolve the overlay cleanly and deterministically on both devices.

---

## Definition of Success for Phase 16
Phase 16 is successful when:

- remote **Play Again / Rematch** works from EndGameView
- replay uses the same completed match config automatically
- both players can reach a new replay lobby deterministically
- the existing **PlayerChallengeCard** and its states are reused clearly
- lobby/start behaviour remains stable
- voice remains connected if safely achievable
- decline is handled clearly
- the solution feels like a natural extension of Remote Matches rather than a separate mini-system

---

## Working Assumption for Implementation
Unless a better low-risk option emerges, implementation should proceed with this assumption:

> Replay is a new remote match seeded from the completed one, using the existing remote lifecycle and the existing PlayerChallengeCard states as much as possible, with replay-specific presentation layered on top of EndGameView.

---

## Immediate Next Step for This Phase
Design and implementation planning should now focus on:

1. deciding the minimal replay data model / server action needed
2. deciding how replay request surfaces on **EndGameView** for both players using the existing **PlayerChallengeCard**
3. deciding how the accepted replay transitions back into the normal **Ready / Lobby** flow
4. deciding the safest way to preserve **voice continuity** across replay setup and lobby entry
5. deciding the cleanup rules for decline / cancel / expiry / abandonment so overlays cannot get stuck

---

## Notes for Future Decisions
If there is a tradeoff between:
- **more magical UX**
- and **reusing the stable remote challenge/lobby system**

then Phase 16 should prefer:

- reuse
- determinism
- speed to implementation
- lower regression risk

If there is a tradeoff between:
- **perfect voice continuity**
- and **keeping the replay flow robust and easy to reason about**

then the phase should prefer:
- stable replay flow first
- voice continuity second