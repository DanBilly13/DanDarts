

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

Remote Matches reuse existing local-game UI where possible, with targeted adaptation for remote state, realtime updates, push, voice, and remote gameplay flow.

This new phase focuses on building a safe foundation for **remote replay / rematch** from the end-game experience.

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
8. Match completes
9. Both users land on the end-game experience

The remote lobby and voice-connect flow are now behaving well and should be treated as **stable foundations**.

---

## Why Phase 16 Is Being Reframed
Initial replay work started to make the existing `GameEndView` too complicated.

That created risk in a part of the app that should stay simple and reliable.

To reduce that risk, Phase 16 is being reframed so that the first task is **not replay logic**.

The first task is to create a **dedicated remote end-game view**:

- `EndGameViewRemote`

This should begin as a **carbon copy** of the current end-game experience, but separated from the local end-game view so remote-specific behaviour can be added safely later.

This is now the correct foundation for the replay/rematch feature.

---

## Phase 16 Goal
Create a safe remote-specific end-game foundation first, then build replay/rematch on top of it.

The product goal for the full phase remains:

- remote match completes
- both players land on a remote end-game screen
- one player can initiate replay
- the other player can accept or decline
- if both agree, a new remote match is created using the same game configuration
- both players move back into the existing remote match flow

However, **Phase 16 should begin by separating the remote end-game UI from the local end-game UI before replay is added**.

---

## Key Product Principle for This Phase
This phase should favour:

- **separation before extension**
- **reuse over invention**
- **existing lifecycle over special-case flows**
- **80% great UX if it is dramatically safer/faster to ship**
- **minimal new moving parts**
- **protecting already-stable remote architecture**

We do **not** want to continue adding remote replay behaviour directly into the shared local end-game view.

---

## Phase 16 Implementation Order

### Step 1 — Create `EndGameViewRemote`
Create a new remote-specific end-game screen named:

- `EndGameViewRemote`

This should start as a **carbon copy** of the current end-game experience, but only for remote matches.

The purpose is to give remote match completion its own UI surface before replay logic is added.

### Step 2 — Route remote match completion to `EndGameViewRemote`
Remote matches should navigate to `EndGameViewRemote` instead of the shared end-game view.

Local matches should continue using the existing local end-game view unchanged.

### Step 3 — Verify `EndGameViewRemote` baseline behaviour
Before replay work begins, the remote end-game screen must be verified to behave correctly.

### Step 4 — Only after that, begin replay/rematch work
Replay should be added on top of the dedicated remote end-game screen, not inside the shared local end-game view.

---

## Phase 16 First Task
### First deliverable
The first task in this phase is:

> Create `EndGameViewRemote` as a carbon copy of the current end-game screen and make sure remote users can use it normally before any replay work begins.

This first task should **not** introduce replay/rematch logic yet.

It should focus on safe separation and behaviour parity.

---

## Required Behaviour for `EndGameViewRemote`
At the end of Task 1, `EndGameViewRemote` must support the same essential end-game actions remote users already need.

### Must work correctly
- winner presentation
- existing visual styling / layout parity with current end-game experience
- **View Match Details** navigation
- **Back to Games** behaviour
- any existing remote-specific data needed for match result display

### Explicit verification requirement
The following must be confirmed working in `EndGameViewRemote` before replay work starts:

1. **View Match Details** opens correctly
2. match details load correctly
3. cached / preloaded match-detail behaviour still works if already supported
4. **Back to Games** returns correctly
5. remote end-game presentation does not break existing navigation flow

---

## Important Scope Limit for Task 1
Task 1 is **not** the replay implementation.

Task 1 should **not** add:
- replay request creation
- replay overlay UI
- replay accept / decline
- replay realtime listeners
- replay challenge creation
- rematch state logic
- extra replay-specific complexity in shared view code

Task 1 should only establish the remote-specific end-game surface cleanly.

---

## Why This Approach Is Preferred
Creating `EndGameViewRemote` first gives several important benefits:

### 1. Keeps local end-game stable
The existing local end-game flow stays simple and does not become polluted with remote replay logic.

### 2. Reduces conditional UI complexity
Instead of filling one shared view with remote-specific branches, remote logic gets its own isolated screen.

### 3. Makes replay safer to implement
Replay can be added on a dedicated remote screen without constantly worrying about breaking local end-game behaviour.

### 4. Improves debugging and iteration
If replay work causes issues later, the blast radius is smaller because it is contained inside the remote end-game surface.

### 5. Matches the project’s current needs
The remote feature already has enough complexity. This phase should reduce coupling, not increase it.

---

## Agreed UX Direction for Replay After Task 1
Once `EndGameViewRemote` is stable, replay should still follow the previously agreed product direction:

### Replay foundation
Replay should behave as a **new remote match seeded from the completed remote match**.

That means:
- a new match record is created
- it uses the same game configuration
- it reuses the existing remote lifecycle
- clients still respond to authoritative server state

### UI direction
Replay presentation should use:
- the dedicated `EndGameViewRemote`
- the existing **PlayerChallengeCard**
- the existing PlayerChallengeCard states already used elsewhere in Remote Matches

We should be specific here:

Replay UI should aim to reuse the **same PlayerChallengeCard and its existing states**, rather than inventing a new replay-specific card system.

---

## Replay UX Direction (For Later In This Phase)
### Player A (first player to tap replay)
- taps **Play Again / Rematch** on `EndGameViewRemote`
- an overlay opens on top of `EndGameViewRemote`
- that overlay should reuse the existing **PlayerChallengeCard** in the **sent** state

### Player B
- while on `EndGameViewRemote`, receives a replay request
- sees an overlay on top of `EndGameViewRemote`
- that overlay should reuse the existing **PlayerChallengeCard** in the **pending** state
- B can **Accept** or **Decline**

### On accept
If Player B accepts:
- Player B may enter lobby immediately if that matches the existing accepted flow
- Player A’s overlay/card should update using the existing **ready** state with **Join now**

### On decline
If Player B declines:
- Player B’s overlay fades away after a short pause
- Player A’s overlay/card shows declined feedback, then fades away
- both users remain on the end-game screen
- no ambiguous state is left behind

---

## Preferred Implementation Strategy
### Recommended strategy
Use the **existing remote challenge / ready / lobby flow** as the base for replay.

That means replay should try to reuse:
- existing challenge creation patterns
- existing accept / decline semantics
- existing PlayerChallengeCard states
- existing ready / join / lobby transitions
- existing lobby countdown and voice-ready behaviour
- existing navigation patterns

### Important implementation rule
Replay should be layered onto `EndGameViewRemote`, not retrofitted into the shared local end-game view.

---

## Voice Requirement
### Desired behaviour
**Keep voice connected** across:
- remote end-game view
- replay request / accept moment
- transition into replay lobby

This remains an important polish goal.

### Guidance
Voice continuity is still preferred, but not at the cost of destabilising the remote system.

The safe order is:

1. get `EndGameViewRemote` separated and stable
2. get replay flow working
3. preserve voice continuity if safely achievable within that structure

---

## UX Priorities in Order
1. **Create `EndGameViewRemote` and keep it clean**
2. **Verify View Match Details and Back to Games work correctly**
3. **Reuse existing PlayerChallengeCard and remote lifecycle**
4. **Keep replay easy to understand**
5. **Preserve voice connection if safe**
6. **Avoid introducing brand-new complicated states unless clearly necessary**
7. **Do not destabilise lobby/gameplay/navigation that already took a long time to stabilise**

---

## What This Phase Is Not
This phase is **not** trying to build:
- replay directly inside the shared local end-game view
- a fully bespoke instant rematch engine
- a no-lobby auto-start rematch flow
- a new alternate remote lifecycle
- a large backend redesign
- a complex matchmaking or queue system

This phase is about building replay safely on top of a dedicated remote end-game surface.

---

## Reuse / Adapt Guidance
This phase should strongly consider reusing these existing concepts:

- current end-game layout and styling as the base for `EndGameViewRemote`
- existing remote challenge creation behaviour, seeded from completed match config
- existing **PlayerChallengeCard**
- existing PlayerChallengeCard states already used by Remote Matches
- existing accept / decline semantics
- existing **Ready** and **Lobby** transitions
- existing **RemoteLobbyView** behaviour for match starting
- existing countdown/start logic once both players are ready

---

## Top-Line Delivery Plan
### Task 1
Create `EndGameViewRemote` as a carbon copy of current end-game UI.

### Task 2
Route remote completed matches to `EndGameViewRemote`.

### Task 3
Verify:
- View Match Details works
- Back to Games works
- navigation remains stable

### Task 4
Only after Tasks 1–3 are stable, add replay/rematch UX using overlay + existing PlayerChallengeCard reuse.

### Task 5
Wire accepted replay back into existing Ready / Lobby flow.

### Task 6
Preserve voice continuity if safely achievable.

---

## Risks for This Phase
### Main risks
- remote replay logic leaking back into shared end-game code
- making end-game too stateful and difficult to reason about
- breaking match-details navigation while adding replay UI
- breaking Back to Games or end-of-match navigation flow
- introducing replay-specific states that duplicate existing PlayerChallengeCard behaviour
- destabilising voice/lobby flow that is currently working

### Risk reduction strategy
The main mitigation is:

> keep replay out of the shared end-game view, create `EndGameViewRemote` first, and verify that screen independently before adding replay behaviour.

---

## Constraints / Guardrails
### Architecture guardrails
- do not bypass server-authoritative state
- do not create client-only lifecycle truth
- do not push replay logic back into the shared local end-game view
- do not add fragile special-case navigation if existing routing can be reused

### Product guardrails
- replay should feel faster than starting a brand-new remote match manually
- but it does not need to be perfect if that introduces major risk
- prefer a slightly less magical UX that is much safer to ship

---

## Definition of Success for Phase 16
Phase 16 is successful when:

### Foundation success
- `EndGameViewRemote` exists
- remote completed matches use it
- **View Match Details** works correctly
- **Back to Games** works correctly
- the remote end-game flow is stable and cleanly separated from local

### Replay success
- replay works from `EndGameViewRemote`
- replay uses the same completed match config automatically
- replay presentation reuses the existing **PlayerChallengeCard** and its existing states
- both players can reach a new replay lobby deterministically
- lobby/start behaviour remains stable
- voice remains connected if safely achievable
- decline is handled clearly

---

## Working Assumption for Implementation
Unless a better low-risk option emerges, implementation should proceed with this assumption:

> First create `EndGameViewRemote` as a clean remote-only end-game surface. Then build replay as a new remote match seeded from the completed one, using the existing PlayerChallengeCard, its existing states, and the existing remote lifecycle as much as possible.

---

## Immediate Next Step for This Phase
The immediate next step is now:

1. create `EndGameViewRemote`
2. route remote match completion to it
3. verify View Match Details works
4. verify Back to Games works
5. only then begin replay/rematch implementation planning on top of that screen

---

## Notes for Future Decisions
If there is a tradeoff between:
- adding replay faster inside existing shared end-game code
- and creating a separate remote end-game surface first

then Phase 16 should prefer:

- separation
- reuse
- determinism
- speed to stable implementation
- lower regression risk