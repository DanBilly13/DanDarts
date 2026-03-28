> Supporting reference for: remote-match-lifecycle  
> Apply when: determining the canonical stage a remote match is in, reasoning about what transitions are valid next, or debugging cases where the UI seems to imply one stage but authoritative remote state implies another  
> Do not apply to: local match flow, generic realtime mechanics, or pure navigation issues unless the root problem is incorrect lifecycle staging

# Lifecycle Stages

## Purpose

This document defines the canonical stage model for remote matches in Dart Freak.

It exists because lifecycle bugs often come from one of these mistakes:
- collapsing multiple remote stages into one
- reasoning from card UI instead of authoritative stage
- treating temporary UI phases as persisted lifecycle stages
- assuming the next visible screen means the lifecycle already advanced

This document is the stage map.

## Core Rule

A remote match should always be reasoned about in terms of its **authoritative lifecycle stage** first.

That means:
- identify the real persisted stage
- identify any temporary derived UI phase layered on top
- then determine allowed actions and next transitions

In short:

**authoritative stage first, derived phase second**

## Two Kinds of Stage

Remote match lifecycle uses two different kinds of stage information.

### 1. Authoritative persisted stages

These are the real lifecycle stages backed by authoritative remote match state.

Examples:
- pending
- ready
- lobby
- in_progress
- completed
- cancelled
- expired

These are the stages that define what the match really is.

### 2. Derived UI/presentation phases

These are client-facing interpretations layered on top of authoritative state.

Examples:
- sent
- pending card
- ready card
- countdown phase
- connecting phase
- declined presentation
- hidden/removed from actionable UI

These are useful, but they are not the primary lifecycle truth.

## Temporary UI Phases Inside Lifecycle Stages

This is very important.

Some UI phases feel like lifecycle stages, but are often only temporary sub-phases layered on top of one authoritative stage.

Typical examples:
- sent
- pending card
- connecting
- countdown
- declined presentation
- hidden or removed presentation
- replay overlay visible state

These may be very important to the user experience, but they should not be confused with the core persisted lifecycle unless the implementation explicitly persists them as such.

## Canonical Remote Lifecycle Family

At the highest level, a normal remote match usually moves through this family of stages:
```text
pending → ready → lobby → in_progress → completed
```

There are also terminal branches such as:
- cancelled
- expired
- decline-related disappearance behavior
- replay creation from completed context

This is the backbone model.

## Stage 1 — Pending

### Meaning

A remote challenge exists, but it has not yet progressed to ready.

This is the first actionable remote challenge stage.

### Important notes

- challenger and receiver may see different presentation for this same stage
- challenger may see this as **sent**
- receiver may see this as **pending**
- this asymmetry is expected

### Typical allowed actions

Depending on role and context:
- challenger may cancel
- receiver may accept
- receiver may decline
- expiry may still occur

### Typical next transitions

- `pending → ready`
- `pending → cancelled`
- `pending → expired`
- pending may also disappear from actionable UI through decline, cancel, or expiry-related behavior depending on implementation details

### Common mistake

Treating **sent** as a real persisted stage.
It is usually a role-specific presentation of pending, not a distinct lifecycle stage.

## Stage 2 — Ready

### Meaning

The challenge has advanced past initial waiting and is now eligible for the next start-flow step.

This is the bridge stage between challenge-handling and match-start flow.

### Important notes

- ready is not gameplay
- ready is not lobby
- ready usually means the match is now joinable and able to proceed into lobby flow
- both sides may now see a much more symmetrical UI than in pending

### Typical allowed actions

Depending on implementation and context:
- join
- cancel
- possibly other ready-stage exits

### Typical next transitions

- `ready → lobby`
- `ready → cancelled`
- `ready → expired`

### Common mistake

Treating ready as "basically started."
It is only the stage that makes the next gated start-flow possible.

## Stage 3 — Lobby

### Meaning

The match has entered the pre-game start-flow stage.

This is where the app coordinates the conditions needed before gameplay can begin.

### Important notes

Lobby is usually not one simple binary experience.
It often contains multiple sub-phases such as:
- entered or joined
- lobby view entered
- connecting
- voice ready
- countdown started

These sub-phases may affect UI heavily, but the authoritative stage can still remain `lobby`.

That is important.

### Typical allowed actions

Depending on implementation:
- remain in lobby
- confirm presence or readiness-related steps
- abort or cancel in some cases
- continue toward countdown and gameplay gates

### Typical next transitions

- `lobby → in_progress`
- `lobby → cancelled`
- `lobby → expired` or other terminal handling depending on authoritative implementation

### Common mistake

Treating countdown or connecting UI as separate persisted lifecycle stages.
They are often **lobby sub-phases**, not separate authoritative stages.

## Stage 4 — In Progress

### Meaning

The remote match is now actively being played.

This is the gameplay stage.

### Important notes

- gameplay should only begin once authoritative state really confirms it
- current player and turn ownership plus gameplay writes now matter
- the match is no longer in challenge or start-flow staging

### Typical allowed actions

- take turns
- submit gameplay actions
- continue normal remote match progression
- possibly abort or cancel depending on implementation

### Typical next transitions

- `in_progress → completed`
- `in_progress → cancelled`
- other terminal exits if explicitly supported

### Common mistake

Pushing gameplay because the UI "looks ready" while the authoritative lifecycle is still lobby.

## Stage 5 — Completed

### Meaning

The remote match finished normally.

This is the normal successful terminal stage.

### Important notes

- completed usually moves the match out of actionable active UI
- it may move into history
- it may allow replay creation from end-game context
- completed is different from cancelled or expired

### Typical allowed actions

Depending on context:
- view result or history
- request replay
- leave flow
- return to app lists

### Typical next transitions

- no further lifecycle progression for the same match
- replay may create a **new** remote match from this outcome

### Common mistake

Treating replay as the same match continuing.
Replay usually creates a new match in the same lifecycle family.

## Terminal Stage — Cancelled

### Meaning

The match was manually ended or invalidated through a cancellation path.

### Important notes

- cancelled is terminal
- cancelled is not the same as completed
- cancelled is not the same as expired
- UI may remove the match from actionable surfaces quickly, but that presentation behavior is still downstream of this terminal meaning

### Typical next transitions

- none for this match

### Common mistake

Treating all terminal removals as "cancelled."
Cancelled is only one specific terminal reason.

## Terminal Stage — Expired

### Meaning

The match or challenge timed out according to lifecycle timing rules.

### Important notes

- expired is terminal
- expired is distinct from cancelled and completed
- different lifecycle windows may expire at different stages depending on implementation
- some UI may simply remove expired matches from actionable lists

### Typical next transitions

- none for this match

### Common mistake

Confusing UI disappearance with terminal reason.
Removal from UI does not tell you by itself whether the match expired, cancelled, or was otherwise reclassified.

## Decline-Related Handling

### Meaning

Receiver decline behavior often matters early in lifecycle, especially from the pending stage.

### Important note

Be careful here:

**decline presentation and decline outcome are not always the same thing as a distinct persisted lifecycle stage.**

Depending on implementation:
- decline may be represented as a true authoritative terminal outcome
- or decline may be handled as a UI presentation or result layered on top of another terminal path
- or decline may briefly appear in UI before disappearing

So do not assume "declined" is always a canonical persisted stage unless the implementation clearly treats it that way.

### Practical rule

When debugging or documenting decline behavior, separate:
- authoritative persisted result
- brief client presentation state
- removal or disappearance behavior

This prevents a lot of confusion.

## Replay Lifecycle Position

Replay is not usually a separate stage within the same match.

Instead, replay usually starts from:
- an already completed remote match context
- then creates a **new** remote match
- which re-enters the same broad lifecycle family

So conceptually:
```text
completed (old match) → replay request → new remote match begins lifecycle again
```

That new replay match may then follow stages such as:
- pending
- ready
- lobby
- in_progress
- completed

Replay is a lifecycle reuse pattern, not just an internal sub-stage of completion.

## Good Mental Model

Use this mental model.

### Authoritative lifecycle stage

What is the remote match really, according to authoritative state?

### Derived phase

What temporary or role-specific presentation is layered on top?

### Allowed actions

What may this player do from here?

### Next valid transitions

What authoritative transition could happen next?

That is the correct order.

## Bad Mental Model

Avoid these.

### Bad

"The challenger sees sent, so the lifecycle stage is sent."

### Better

"The lifecycle stage is pending, and the challenger sees the sent presentation for it."

### Bad

"The lobby countdown means the match left lobby."

### Better

"The match may still be in authoritative lobby while the client is showing a countdown sub-phase."

### Bad

"The decline card means declined is definitely a canonical persisted stage."

### Better

"Decline may be a terminal outcome, a presentation state, or both depending on implementation details."

## Stage Checklist

Before changing lifecycle logic, ask:

1. what authoritative stage is the match in?
2. is this a persisted stage or a derived UI phase?
3. what role is viewing it?
4. what actions are valid from this stage?
5. what authoritative transition can happen next?
6. is the client currently presenting that stage correctly?

If you cannot answer these, the lifecycle change is probably under-specified.

## Relationship to Other Docs

This doc defines the stage model.

Use it with:
- `challenger-vs-receiver-rules.md` for player asymmetry
- `create-accept-decline-cancel.md` for early lifecycle transitions
- `ready-lobby-gameplay-flow.md` for start-flow stages after ready
- `expiry-and-terminal-states.md` for terminal meanings
- `authoritative-state-and-ui-mapping.md` for stage-to-UI behavior
- `replay-lifecycle-rules.md` for replay-specific lifecycle behavior

This doc answers:

**what stage is the match really in?**

The others answer:
- what each player sees
- what actions are allowed
- how specific transitions behave

## Bottom Line

A remote match in Dart Freak should always be reasoned about as a real authoritative stage first.

The persisted lifecycle stage is the truth.
The visible UI phase is a derived interpretation layered on top.