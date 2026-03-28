> Supporting reference for: remote-match-lifecycle  
> Apply when: working on the transition from ready state into lobby, countdown, and gameplay, including join behavior, lobby gating, readiness confirmation, countdown start, and gameplay entry  
> Do not apply to: early challenge creation/accept/decline/cancel behavior, local match flow, or generic navigation/realtime issues unless the bug is specifically in the ready-to-gameplay lifecycle flow

# Ready, Lobby, Gameplay Flow

## Purpose

This document defines the remote lifecycle flow after a match leaves the early challenge phase and becomes eligible to start.

It covers the sequence from:
- ready
- lobby entry
- lobby confirmation
- readiness gating
- countdown
- gameplay start

This is one of the most failure-prone parts of the remote match lifecycle because it is easy to accidentally:
- collapse ready and lobby into one state
- treat countdown as a separate persisted stage
- assume gameplay can start from local UI confidence alone
- ignore role-specific authoritative fields
- blur together UI phase and authoritative stage

This document is about the **match-start flow** between challenge completion and active gameplay.

## Core Rule

Always reason about this flow in the following order:

1. what authoritative lifecycle stage is the match in?
2. what start-flow sub-phase is the UI showing inside that stage?
3. what authoritative fields prove the match may progress?
4. what player role is being evaluated?
5. what transition is actually allowed next?

In short:

**ready is the entry gate, lobby is the start-flow stage, gameplay begins only after authoritative gating succeeds**

## Where This Flow Sits in the Lifecycle

This document covers the lifecycle after the challenge phase and before active gameplay.

Typical flow:

```text
ready → lobby → in_progress
```

with important sub-phases inside `lobby`, such as:
- joined or entered
- lobby view entered
- connecting
- voice ready
- countdown started

This is the phase where the match is no longer just a challenge, but is not yet active gameplay.

## Ready Stage

### Meaning

Ready means the match has successfully left the initial waiting-for-response challenge phase and is now eligible to enter the pre-game start flow.

It is the bridge between:
- challenge handling
- match start coordination

### Important rules

- ready is a real lifecycle stage
- ready is not lobby
- ready is not gameplay
- ready means the match is allowed to proceed into lobby flow if the correct next action happens

### Typical role experience

Both players may now see a more symmetric ready state than they saw during pending/sent asymmetry.

Typical allowed actions may include:
- join
- cancel, depending on the implementation

### Common mistake

Treating ready as “the match already started.”

It has not.  
It is only eligible to enter the next gated flow.

## Ready → Lobby Transition

### Meaning

The ready-to-lobby transition is the moment the match enters the pre-game coordination stage.

This is typically triggered by a join or enter action from the player who is proceeding into the match.

### Important rules

- the transition into lobby must be authoritatively confirmed
- a local button tap is not, by itself, proof that the match is now in lobby
- both sides must eventually converge on the same authoritative lobby-stage truth, even if they do not enter at the exact same visible moment

### What should happen next

After a correct ready → lobby transition:
- the match is now in the lobby stage
- the UI should stop behaving like a challenge card flow
- lobby-related gating fields and start-flow logic become relevant

### Common mistake

Treating “join button tapped” as identical to “lifecycle advanced to lobby.”

That only becomes true when authoritative state says so.

## Lobby Stage

### Meaning

Lobby is the authoritative pre-game stage where the match coordinates the final conditions required before gameplay can begin.

It is the stage between:
- being ready to start
- actually being in progress

### Important rules

- lobby is a real authoritative lifecycle stage
- many visible UI phases can exist inside lobby without changing the lifecycle stage
- both players may be in the same lobby stage while still having separate role-specific fields

### Typical lobby concerns

During lobby, the system may need to confirm things such as:
- each player has joined or entered
- each player has entered the lobby view
- readiness-related timestamps exist
- countdown may start
- gameplay is not yet allowed until the authoritative gates pass

### Common mistake

Treating connecting, ready-to-start, and countdown as separate persisted lifecycle stages.

They are often only sub-phases of lobby.

## Lobby Sub-Phases

These sub-phases are usually important to the user experience, but they are often not separate authoritative lifecycle stages.

Typical sub-phases include:
- lobby entered
- lobby view entered
- waiting for other player
- connecting
- voice ready
- countdown running

These matter for:
- UI messaging
- button availability
- progression gating
- debugging why gameplay did or did not start

But they should still usually be understood as happening **inside** the authoritative lobby stage unless the implementation explicitly persists them as separate lifecycle states.

## Lobby View Entered Rule

### Meaning

One important lobby sub-phase is the moment a player is confirmed to have actually entered the lobby view.

This is different from merely:
- having a ready match
- having tapped join
- seeing a route begin to change locally

### Why it matters

A remote match often needs more than simple stage entry.  
It may need proof that each side has actually reached the lobby experience.

### Typical effect

When lobby-view-entered behavior is correctly recorded:
- the system can tell which players have truly arrived in the lobby
- later readiness or countdown logic can rely on that truth
- the match-start flow becomes less guessy and more authoritative

### Common mistake

Assuming a successful navigation push automatically means all authoritative “player entered lobby” conditions are satisfied.

Those are not always the same thing.

## Role-Specific Lobby Fields

Even when both players are visually in the same lobby flow, authoritative field interpretation is still role-specific.

Typical examples include separate fields for:
- challenger entered or joined
- receiver entered or joined
- challenger lobby view entered
- receiver lobby view entered
- challenger readiness
- receiver readiness

This means:
- lobby UI may look symmetric
- but the authoritative evidence is still asymmetric per player

Do not lose role identity just because the screen is shared.

## Readiness Gating Rule

Gameplay should not start just because both users appear to be “basically here.”

The app should reason from authoritative readiness gates.

Typical questions include:
- has each player reached the required lobby participation state?
- has each player completed the required readiness step?
- do the authoritative readiness fields now allow the next transition?
- is this still lobby, or has the match truly advanced?

### Common mistake

Starting gameplay from:
- local UI confidence
- a single visual state change
- one player’s readiness alone
- a realtime hint without authoritative confirmation

Gameplay start should be gated, not assumed.

## Voice-Ready / Connection-Ready Phase

Depending on the implementation, there may be readiness checks related to connection or voice setup before countdown or gameplay may begin.

These should be treated as:
- important gating inputs
- role-specific readiness evidence
- sub-phase logic inside lobby

They should **not** automatically be treated as:
- proof that the lifecycle left lobby
- proof that gameplay may start without further validation

### Key rule

Connection or voice readiness may be necessary for progression, but it is not necessarily the same thing as gameplay authorization.

## Countdown Rule

### Meaning

Countdown is typically the final visible start phase before gameplay begins.

### Important rules

- countdown is often a UI-visible sub-phase inside the authoritative lobby stage
- countdown is not automatically its own persisted lifecycle stage
- countdown should begin only after the required authoritative gates have passed
- countdown ending does not matter unless the authoritative start conditions still hold

### What countdown usually means

Countdown usually means:
- the system believes required pre-game conditions have been satisfied
- gameplay start is about to be attempted or completed
- the players are still not yet in active gameplay until authoritative progression confirms it

### Common mistake

Treating countdown UI as equivalent to `in_progress`.

It usually is not.  
It is often only the final lobby sub-phase before gameplay begins.

## Lobby → In Progress Transition

### Meaning

This is the authoritative transition from pre-game coordination into active gameplay.

This is one of the most important lifecycle transitions in the feature.

### Important rules

- gameplay should only begin once authoritative state confirms it
- a countdown finishing locally is not enough
- a single visual change is not enough
- readiness evidence must already exist
- the current transition still has to be valid for this match and these players

### What should happen next

After a correct lobby → in_progress transition:
- the authoritative lifecycle stage is now `in_progress`
- gameplay UI becomes valid
- the match is no longer in challenge/start-flow staging
- turn/current-player logic becomes active

### Common mistake

Pushing gameplay while the authoritative lifecycle is still lobby.

That usually means the UI raced ahead of lifecycle truth.

## Current Player Rule

When gameplay starts, current-player meaning becomes important.

That means:
- there is now a meaningful active player or turn owner
- this should come from authoritative match truth
- the app should not invent turn ownership just because gameplay UI was pushed

This matters especially at the exact moment gameplay begins, because bugs here can make the wrong user appear to have the opening turn.

## Role Symmetry vs Role-Specific Fields

This phase often looks more symmetric than the early challenge phase.

That is true at the UI level:
- both players may see the same lobby
- both may see the same countdown
- both may see the same gameplay shell

But it is still role-sensitive underneath because:
- each player contributes separate authoritative readiness evidence
- each player maps to separate challenger/receiver fields
- current player and field ownership still matter

A common mistake is assuming this phase is now role-neutral just because the screens look similar.

It is not.

## Start-Flow Mental Model

A good mental model for this phase is:

```text
ready
→ authoritative lobby entry
→ per-player lobby participation confirmed
→ per-player readiness confirmed
→ countdown sub-phase
→ authoritative in_progress
→ gameplay
```

That model is much safer than:

```text
ready → join → gameplay
```

The second model is too simple and causes bugs.

## Good Patterns

### Good: ready stays distinct from lobby

- match becomes ready
- UI shows ready-stage behavior
- join action occurs
- authoritative state advances to lobby
- lobby sub-phase logic begins

### Good: lobby contains sub-phases

- match is authoritatively in lobby
- UI may show waiting / connecting / voice-ready / countdown
- lifecycle does not pretend those are separate persisted stages unless they truly are

### Good: gameplay starts only after authoritative confirmation

- countdown or readiness sequence completes
- authoritative transition succeeds
- lifecycle becomes in_progress
- gameplay UI is now valid

### Good: both players update from shared authoritative progression

- both players may experience different local timing
- but both eventually converge on the same authoritative lobby/in_progress truth
- UI differences do not change the lifecycle meaning

## Bad Patterns

### Bad: ready treated as gameplay-adjacent enough to skip lobby

- match becomes ready
- app behaves as if start-flow already completed

### Bad: join tap treated as proof of lobby truth

- user taps join
- app assumes lifecycle is now lobby without authoritative confirmation

### Bad: countdown treated as in_progress

- countdown begins
- gameplay UI is shown before authoritative lifecycle transition

### Bad: local readiness treated as globally sufficient

- one player completes readiness
- app assumes match can progress without both sides’ authoritative gating

### Bad: shared UI used to ignore role-specific fields

- both players are on same lobby screen
- code stops caring which readiness field belongs to which side

## Checklist for This Phase

Before changing ready/lobby/gameplay flow, ask:

1. is the match currently ready, lobby, or in_progress?
2. is the UI showing a true lifecycle stage or just a lobby sub-phase?
3. what authoritative fields prove the next step is allowed?
4. has each player contributed the required role-specific evidence?
5. is gameplay truly authorized, or only visually imminent?
6. will both players converge correctly on the same authoritative progression?

If those answers are unclear, the change is probably unsafe.

## Relationship to Other Docs

Use this doc for the transition from challenge completion into match start and gameplay.

Use it with:
- `lifecycle-stages.md` for the canonical stage model
- `challenger-vs-receiver-rules.md` for role asymmetry
- `create-accept-decline-cancel.md` for early challenge-phase behavior
- `authoritative-state-and-ui-mapping.md` for exact lifecycle-to-UI interpretation
- `expiry-and-terminal-states.md` for what happens when the flow does not successfully start
- `replay-lifecycle-rules.md` for replay-specific variants of the same start-flow pattern

This doc answers:

**how does a match progress from ready into lobby and then into active gameplay?**

## Bottom Line

In Dart Freak, the path to gameplay is staged and gated.

Ready is not gameplay.  
Lobby is not gameplay.  
Countdown is not gameplay.  
Gameplay begins only when the authoritative lifecycle truly becomes `in_progress`.