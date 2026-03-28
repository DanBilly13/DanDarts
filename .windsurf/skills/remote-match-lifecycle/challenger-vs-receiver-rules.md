> Supporting reference for: remote-match-lifecycle  
> Apply when: working on any remote match behavior where challenger and receiver should see different UI, have different allowed actions, or follow different lifecycle responsibilities  
> Do not apply to: local match flow, generic navigation rules, or remote logic that is not role-dependent

# Challenger vs Receiver Rules

## Purpose

This document defines the role asymmetry rules for remote matches in Dart Freak.

A large number of remote match bugs happen because code accidentally assumes:
- both players should see the same UI at the same time
- both players should be allowed to do the same actions
- both players should own the same transitions
- both players should react identically to lifecycle changes

That is not how this feature works.

Remote matches are intentionally asymmetric in important places.  
This document explains those differences.

## Core Rule

For any remote lifecycle stage, always ask:

1. is this user the **challenger** or the **receiver**?
2. what should that role see?
3. what should that role be allowed to do?
4. what should the other role see and be allowed to do?
5. is the current UI/action difference intentional or actually a bug?

In short:

**same match state does not always mean same player experience**

## Role Definitions

### Challenger

The challenger is the player who creates the remote challenge.

This role typically:
- initiates the first challenge
- sees outgoing challenge presentation
- may own early cancellation behavior
- often remains the starting player in match-start flow, depending on authoritative rules
- may see “sent” where the other player sees “pending”

### Receiver

The receiver is the player who receives the remote challenge.

This role typically:
- decides whether to accept or decline the incoming challenge
- sees incoming challenge presentation
- may own acceptance/decline actions that the challenger does not have
- may see “pending” where the challenger sees “sent”

These roles matter even when the underlying match record is the same.

## Core Asymmetry Principle

Remote role differences usually appear in three places:

### 1. Presentation asymmetry
The same authoritative state can render differently for challenger and receiver.

### 2. Action asymmetry
One role may have actions the other does not.

### 3. Transition asymmetry
One role may be responsible for triggering or observing a transition differently from the other role.

A correct implementation must preserve all three where intended.

## Pending Stage Rules

The pending stage is one of the clearest examples of role asymmetry.

### Challenger in pending

The challenger usually sees:
- an outgoing challenge state
- often presented as **sent**

Typical challenger actions:
- cancel challenge
- wait for receiver response

The challenger should **not** usually see:
- accept
- decline

### Receiver in pending

The receiver usually sees:
- an incoming challenge state
- often presented as **pending**

Typical receiver actions:
- accept challenge
- decline challenge

The receiver should **not** usually see:
- sent presentation
- outgoing-only controls

### Key rule

If both players see identical pending UI, that is suspicious.

Pending is usually intentionally asymmetric.

## Sent vs Pending Presentation Rule

This is one of the most important role-mapping rules in the system.

A common correct pattern is:

- same authoritative lifecycle stage
- challenger sees **sent**
- receiver sees **pending**

This means:
- **sent** is usually not a separate persisted lifecycle stage
- it is usually a role-derived presentation of the same underlying challenge state

Do not build lifecycle logic as if “sent” and “pending” are two different authoritative states unless the implementation truly models them that way.

## Ready Stage Rules

The ready stage is usually more symmetric than pending, but still requires role awareness.

### Challenger in ready

The challenger usually sees:
- ready card / ready state
- ability to proceed into the next flow step
- possibly cancel depending on implementation

### Receiver in ready

The receiver usually sees:
- ready card / ready state
- ability to proceed into the next flow step
- possibly cancel depending on implementation

### Key rule

Ready is often the point where the UI becomes more symmetric.

But “more symmetric” does not mean “all lifecycle responsibility is now identical.”  
Role still matters in later flow decisions and field interpretation.

## Lobby Stage Rules

Once both players are in lobby flow, the UI may look more similar, but role still matters.

### Shared lobby similarities

Both players may:
- enter the same lobby screen
- confirm lobby presence
- participate in connection/readiness steps
- wait for countdown/start flow
- see similar lobby UI

### Role-sensitive lobby differences

Even when the screen is similar, role may still matter for:
- which authoritative fields belong to which player
- which side set which readiness timestamp
- how per-player lobby-entered state is interpreted
- which player becomes current player first
- logging, debugging, and field ownership

### Key rule

Lobby UI may look symmetric while the underlying authoritative fields remain role-specific.

Do not lose track of which per-player fields belong to challenger vs receiver just because both are on the same screen.

## Gameplay Stage Rules

Gameplay often feels visually more symmetric, but remote role identity still matters.

### Shared gameplay similarities

Both players may:
- see gameplay UI
- participate in the same match
- be subject to the same win condition
- transition toward the same completed terminal state

### Role-specific gameplay meaning

Role still matters for:
- player identity mapping
- current player interpretation
- turn ownership
- challenger/receiver field relationships
- replay creation context
- debugging issues where “wrong player” data appears

### Key rule

Do not confuse “same gameplay screen” with “role no longer matters.”

The role relationship still exists throughout the match.

## Completed Stage Rules

Completed usually becomes more symmetric again, but replay and post-match behavior may still be role-sensitive.

### Shared completion behavior

Both players may:
- see end-game results
- exit the match
- view history/result information
- potentially request replay depending on the implementation

### Role-sensitive completion meaning

Role may still matter for:
- how the result is narrated
- who was challenger vs receiver in the completed record
- replay ownership and replay creation context
- which side initiated the replay request
- how the next replay match assigns roles

### Key rule

Completion is not a license to forget roles.  
It is just a more symmetric presentation stage.

## Accept Rules

Acceptance is usually a receiver-owned action.

### Receiver responsibilities

The receiver typically owns:
- accept challenge
- decline challenge

### Challenger responsibilities

The challenger typically does not own:
- accept challenge
- decline challenge

The challenger instead waits for the receiver’s decision and then reacts to the authoritative stage change.

### Key rule

If challenger-side code is trying to “accept” its own outgoing challenge, that is suspicious unless the implementation has a very specific replay or edge-case path.

## Decline Rules

Decline is usually a receiver-owned action.

### Receiver responsibilities

The receiver may:
- decline an incoming challenge
- trigger the decline outcome for that remote match

### Challenger experience

The challenger usually does not decline.  
Instead, the challenger experiences the result of the receiver’s decline through:
- updated card state
- disappearance/fade/removal behavior
- possibly a brief declined presentation depending on implementation

### Key rule

Decline ownership and decline presentation are not the same thing.

Receiver owns the action.  
Challenger experiences the consequence.

## Cancel Rules

Cancel behavior is usually more challenger-heavy early, but may become more symmetric later depending on stage.

### Early-stage cancel

In early challenge flow, challenger often owns cancellation of the outgoing challenge.

Typical example:
- challenger sent challenge
- challenger cancels before receiver accepts

### Later-stage cancel

In later stages such as ready or lobby, cancel/abort behavior may become more symmetric depending on implementation.

### Key rule

Do not assume cancel is always symmetric or always challenger-only.

The correct answer depends on:
- lifecycle stage
- role
- current authoritative transition rules

## Expiry Rules

Expiry is role-sensitive in presentation, even when the underlying timeout logic is shared.

### Challenger expiry experience

The challenger may see:
- sent challenge disappear
- ready/lobby item expire out of actionable UI
- different copy/timing expectations depending on the current stage

### Receiver expiry experience

The receiver may see:
- pending challenge disappear
- incoming opportunity removed
- different presentation wording and timing compared with challenger

### Key rule

Even when the underlying expiry is one authoritative terminal outcome, challenger and receiver may still experience different visible UI before removal.

## Replay Rules

Replay is especially important for role interpretation.

### Replay creation

A replay may be requested from completed match context, but the role mapping of the new replay match still matters.

Questions to keep straight:
- who requested the replay?
- who is challenger in the new replay match?
- who is receiver in the new replay match?
- should the original challenger remain challenger?
- what should each side see while replay is pending/ready?

### Replay presentation asymmetry

Replay often reuses the same broad role rules:
- outgoing replay request may look like **sent** to challenger
- incoming replay request may look like **pending** to receiver

### Key rule

Do not treat replay as role-neutral just because it starts from a completed match.

Replay usually re-enters the same asymmetric lifecycle family.

## Field Ownership Rule

Many authoritative fields are role-specific even when the UI is shared.

Examples of role-bound fields often include:
- challenger-specific timestamps
- receiver-specific timestamps
- challenger/receiver ids
- challenger/receiver lobby-entered fields
- challenger/receiver voice-ready fields

This means:

- the UI may look shared
- but the field interpretation is still role-specific

A common bug pattern is mixing up challenger and receiver field ownership when rendering or evaluating state.

## UI Mapping Rule

When mapping authoritative state to UI, always include player role in the mapping.

Never ask only:
- “what does this state show?”

Always ask:
- “what does this state show for challenger?”
- “what does this state show for receiver?”

That applies to:
- cards
- overlays
- action buttons
- fade/removal behavior
- terminal state presentation

## Good Examples

### Good: pending card mapping

- authoritative state is pending
- challenger sees sent
- receiver sees pending
- challenger gets cancel
- receiver gets accept/decline

### Good: ready mapping

- authoritative state is ready
- both players may see ready
- both may be able to join
- role still remains important for field interpretation

### Good: receiver decline behavior

- receiver declines incoming challenge
- authoritative outcome changes
- receiver’s pending card disappears or transitions appropriately
- challenger sees the corresponding decline/cancel/remove outcome on their side

## Bad Examples

### Bad: forcing symmetry where asymmetry is intended

- both players shown pending
- both players shown sent
- both players given accept
- both players given decline

### Bad: using presentation to infer role truth

- card says sent
- code assumes lifecycle stage is sent rather than pending + challenger

### Bad: forgetting role when reading fields

- receiver field rendered for challenger
- challenger field rendered for receiver
- ready/lobby evaluation uses wrong side’s timestamps

### Bad: replay treated as roleless

- replay request shown identically with no outgoing/incoming distinction
- new replay match role assignment ignored
- replay UI built as if both users are in the same position

## Role Checklist

Before changing remote lifecycle behavior, ask:

1. is the current user challenger or receiver?
2. what should this role see right now?
3. what should the other role see right now?
4. what actions are valid for this role?
5. is this asymmetry intentional?
6. am I accidentally flattening role differences into one shared UI/action model?

If those answers are unclear, the change is probably unsafe.

## Relationship to Other Docs

Use this doc for role asymmetry.

Use it with:
- `lifecycle-stages.md` for canonical stage reasoning
- `create-accept-decline-cancel.md` for early challenge actions
- `ready-lobby-gameplay-flow.md` for start-flow behavior after ready
- `authoritative-state-and-ui-mapping.md` for detailed state-to-UI mapping
- `replay-lifecycle-rules.md` for replay-specific lifecycle differences
- `expiry-and-terminal-states.md` for terminal presentation and removal behavior

This doc answers:

**how do challenger and receiver differ at each stage?**

The other docs answer:
- what the stage is
- what transitions exist
- what authoritative truth drives the UI

## Bottom Line

In Dart Freak remote matches, challenger and receiver are not interchangeable.

The same authoritative match may produce different UI, different actions, and different responsibilities depending on which role is looking at it.