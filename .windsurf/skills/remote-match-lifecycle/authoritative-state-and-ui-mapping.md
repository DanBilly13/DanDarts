> Supporting reference for: remote-match-lifecycle  
> Apply when: mapping authoritative remote match state to cards, overlays, lists, screens, and allowed actions, or debugging cases where the database truth and visible UI do not match  
> Do not apply to: local match UI, generic styling work, or remote logic where the problem is not specifically state-to-UI interpretation

# Authoritative State and UI Mapping

## Purpose

This document defines how authoritative remote match state should map to visible UI in Dart Freak.

This is one of the most important references in the remote lifecycle skill set because many bugs are not actually:
- server write bugs
- realtime bugs
- navigation bugs

They are **mapping bugs**.

That means:
- the authoritative state is correct
- but the wrong card, overlay, button set, list placement, or screen is shown

This document exists to prevent mistakes such as:
- treating UI labels as lifecycle truth
- showing the wrong card for challenger vs receiver
- keeping a match in an actionable list after it is no longer actionable
- showing gameplay-adjacent UI while the lifecycle is still only ready or lobby
- removing a match for the wrong reason
- flattening role-based mapping into one shared UI model

## Core Rule

Always map UI in this order:

1. identify the **authoritative lifecycle state**
2. identify the **current player role**
3. identify the **current surface** the user is looking at
4. derive the correct UI from that combination

In short:

**authoritative state → role → surface → UI**

Not:
- UI label → assumed state
- card appearance → assumed lifecycle truth
- one side’s UI → assumed correct UI for the other side

## The Four Inputs to Correct UI

Correct UI mapping depends on four things together:

### 1. Authoritative lifecycle state
Examples:
- pending
- ready
- lobby
- in_progress
- completed
- cancelled
- expired

### 2. Role
- challenger
- receiver

### 3. Surface
Examples:
- sent/outgoing challenge list
- pending/incoming challenge list
- ready list
- active match route
- replay overlay
- end-game screen
- history

### 4. Temporary presentation logic
Examples:
- brief declined state
- brief cancelled state
- fade-out
- overlay dismissal
- loading/processing state

You need all four to map UI correctly.

## Source of Truth Rule

The source of truth is the authoritative remote match state.

That means:
- database-backed lifecycle stage
- authoritative fields that define progression
- role identity
- authoritative visibility/eligibility logic

The source of truth is **not**:
- the current button title
- whatever card is still visible
- a stale overlay object
- one side’s last-seen UI
- a local view assumption that “it probably moved already”

UI must be derived from authoritative truth, not the other way around.

## Mapping Categories

A remote match usually maps to UI in these categories:

### Card presentation
Examples:
- sent
- pending
- ready
- declined
- cancelled
- hidden

### List placement
Examples:
- sent list
- pending list
- ready list
- active flow
- history
- removed from actionable lists

### Screen/route context
Examples:
- challenge cards
- lobby screen
- gameplay screen
- end-game screen
- replay overlay

### Action availability
Examples:
- accept
- decline
- cancel
- join
- none

A correct UI mapping must get all of these right together.

## Pending State Mapping

### Authoritative meaning

Pending is the early challenge stage before acceptance.

### Challenger mapping

For challenger, pending usually maps to:
- **sent** card presentation
- outgoing challenge surface
- waiting-for-response copy
- cancel action
- not accept/decline controls

Typical placement:
- sent or outgoing list

### Receiver mapping

For receiver, pending usually maps to:
- **pending** card presentation
- incoming challenge surface
- accept and decline controls
- not outgoing sent semantics

Typical placement:
- pending or incoming list

### Key rule

One authoritative pending state can correctly produce two different visible cards.

That is expected.

## Sent Is Usually Presentation, Not Lifecycle

This deserves its own rule.

“Sent” is usually:
- a challenger-facing card state
- a presentation of pending
- not a separate authoritative lifecycle stage

So if code or docs start doing this:
- pending for receiver
- sent as a different authoritative stage for challenger

that is usually the wrong model unless the implementation explicitly stores it that way.

The safer mapping is:

**pending + challenger + outgoing surface = sent**

## Ready State Mapping

### Authoritative meaning

Ready means the challenge phase is complete and the match may proceed into the start-flow.

### Typical challenger mapping

For challenger, ready usually maps to:
- ready card presentation
- join action
- possible cancel action depending on implementation
- no more waiting-for-response semantics

### Typical receiver mapping

For receiver, ready usually maps to:
- ready card presentation
- join action
- possible cancel action depending on implementation
- no more accept/decline semantics

### Typical placement

Ready matches usually belong in:
- ready list
- joinable match surface
- not pending/sent lists anymore

### Key rule

Ready is often visually more symmetric than pending, but it is still not gameplay.

Do not map ready to gameplay-adjacent UI too early.

## Lobby State Mapping

### Authoritative meaning

Lobby is the start-flow stage before gameplay.

### Typical UI mapping

Lobby should usually map to:
- lobby screen or active route context
- not ordinary challenge-card behavior
- not pending/ready list semantics
- sub-phase UI such as waiting, connecting, ready checks, countdown, etc.

### Typical role experience

Both players may see a very similar lobby UI, but the mapping still depends on:
- role-specific fields
- role-specific readiness evidence
- current active flow context

### Key rule

Once the match is authoritatively lobby, the UI should stop behaving like a challenge card workflow.

If the app still treats it primarily as a card-phase match, that is suspicious.

## Lobby Sub-Phase Mapping

Within the authoritative lobby stage, the UI may need to distinguish temporary sub-phases such as:
- waiting for other player
- entered but not confirmed
- lobby view entered
- connecting
- voice ready
- countdown

These are usually:
- real UI distinctions
- not separate persisted lifecycle stages

### Key rule

Map these as **sub-phase UI inside lobby**, not as a rewrite of the lifecycle stage, unless the implementation explicitly persists them as separate states.

## Countdown Mapping

### Authoritative meaning

Countdown is usually the last visible pre-game UI phase before gameplay begins.

### Correct UI mapping

Countdown usually maps to:
- active lobby/start-flow context
- countdown visuals
- no challenge-phase actions
- not yet gameplay screen semantics unless and until the authoritative state becomes in_progress

### Key rule

Countdown is often a presentation phase inside lobby.

Do not map countdown to:
- gameplay turn ownership
- in_progress-only controls
- full gameplay state

unless the lifecycle has actually advanced.

## In Progress Mapping

### Authoritative meaning

In progress means the match is actively being played.

### Typical UI mapping

In progress should usually map to:
- gameplay screen
- active turn logic
- current-player interpretation
- gameplay actions and scoring flow
- not challenge cards
- not ready/lobby copy

### Key rule

Gameplay UI should only map from authoritative in_progress truth.

Do not map into gameplay just because:
- countdown finished locally
- the match “looks basically started”
- one side advanced their UI optimistically

## Completed Mapping

### Authoritative meaning

Completed means the match finished normally.

### Typical UI mapping

Completed usually maps to:
- end-game screen
- result/history context
- replay affordance if supported
- not active gameplay
- not actionable challenge/list state

### Typical placement

Completed matches often belong in:
- end-game flow
- history
- result surfaces

They usually do **not** belong in:
- pending
- ready
- sent
- lobby
- active gameplay surfaces

### Key rule

Completed should not map to disappearance-only behavior unless the specific surface is intentionally temporary.

Completed usually retains historical meaning.

## Cancelled Mapping

### Authoritative meaning

Cancelled means the match ended through cancellation, not normal completion.

### Typical UI mapping

Cancelled usually maps to:
- no longer actionable
- removal from challenge/ready/live surfaces
- possibly brief cancelled presentation before disappearance
- not history in the same way a completed match may be shown

### Surface-specific caution

On some surfaces, cancelled may:
- disappear immediately
- show brief cancelled copy
- fade out before removal
- dismiss overlay

Those are presentation timing choices, not lifecycle rewrites.

## Expired Mapping

### Authoritative meaning

Expired means the match timed out.

### Typical UI mapping

Expired usually maps to:
- no longer actionable
- removal from active challenge/start-flow surfaces
- possible expiry-specific copy
- not active gameplay
- not successful completion history

### Key rule

Expired and cancelled may both disappear from actionable UI, but they should still not be treated as the same lifecycle reason.

## Decline-Related Mapping

### Meaning

Decline-related UI is one of the easiest areas to get wrong because it may mix:
- authoritative result
- brief presentation
- disappearance timing

### Receiver mapping

After receiver declines, the receiver should typically:
- stop seeing an actionable incoming challenge
- stop seeing accept/decline controls
- either see brief declined presentation or immediate removal, depending on UI design

### Challenger mapping

After the receiver declines, challenger should typically:
- stop seeing the outgoing challenge as still live
- not remain stuck in sent/waiting state
- either see corresponding decline/removal presentation or have the card disappear appropriately

### Key rule

Even if the decline presentation differs between sides, both sides should converge on the same authoritative non-actionable truth.

## Hidden / Removed Mapping

Hidden is a presentation result, not a lifecycle state.

A match may be hidden because it is:
- completed and moved elsewhere
- cancelled
- expired
- decline-resolved
- no longer belongs on this surface
- moved into active match flow or history

### Key rule

Always ask:

**hidden because of what?**

Do not treat hidden as if it is its own authoritative lifecycle explanation.

## Action Button Mapping Rule

Buttons should map from authoritative state and role, not just from what looks convenient.

Examples:
- pending + challenger → cancel
- pending + receiver → accept/decline
- ready + either role → join, maybe cancel depending on implementation
- lobby → start-flow-specific controls, not challenge-phase controls
- in_progress → gameplay controls, not join/accept/decline
- completed/cancelled/expired → no challenge-phase actions

### Key rule

If the action set does not line up with lifecycle state and role, the UI mapping is wrong even if the card looks visually plausible.

## List Placement Rule

A remote match should appear in the correct UI collection based on authoritative state and role.

Typical examples:
- pending + challenger → sent/outgoing list
- pending + receiver → pending/incoming list
- ready → ready list
- lobby/in_progress → active route/active match context, not challenge lists
- completed → history/end-game/result contexts
- cancelled/expired/decline-resolved → removed from actionable lists

### Key rule

Wrong list placement is a lifecycle-mapping bug.

Even if the card contents look right, the placement can still be wrong.

## Overlay Mapping Rule

When overlays are involved, especially replay overlays, the overlay should still map from authoritative truth plus surface context.

That means:
- overlay visible does not equal lifecycle stage
- overlay disappearance does not explain terminal reason
- overlay should stop presenting stale actionable UI once authoritative truth says it is no longer valid

A stale overlay is often a state-to-UI mapping bug, not necessarily a navigation bug.

## Surface Matters Rule

The same authoritative state may map differently depending on the surface.

Examples:
- completed on end-game screen
- completed in history
- cancelled in a list
- cancelled in an overlay
- ready in a challenge list
- lobby in an active route

So do not ask only:
- what does this state mean?

Also ask:
- where is the user seeing it?

Correct mapping is always:
- state
- role
- surface

## Good Mapping Patterns

### Good: pending maps asymmetrically

- authoritative state is pending
- challenger sees sent in outgoing list with cancel
- receiver sees pending in incoming list with accept/decline

### Good: ready moves out of challenge asymmetry

- authoritative state becomes ready
- both players stop seeing early challenge semantics
- both see ready-appropriate UI and actions

### Good: lobby maps to active start-flow UI

- authoritative state is lobby
- UI shows lobby/start-flow screen
- countdown/waiting/connectivity are sub-phases of lobby
- no one still sees challenge-phase buttons

### Good: completed retains result/history meaning

- authoritative state becomes completed
- gameplay ends
- result/history/end-game surfaces become relevant
- match does not just vanish as if it never happened

### Good: cancelled removes actionability

- authoritative state becomes cancelled
- match stops appearing as live/actionable
- any brief cancelled/fade behavior is just presentation timing

## Bad Mapping Patterns

### Bad: UI label treated as state truth

- card says sent
- code assumes lifecycle stage is sent instead of pending + challenger

### Bad: same pending UI for both roles

- both players shown the same incoming/outgoing semantics
- role asymmetry lost

### Bad: ready mapped like gameplay

- joinable ready state shown with gameplay-adjacent behavior
- lifecycle distinction lost

### Bad: countdown mapped like in_progress

- countdown starts
- UI behaves as if gameplay is already active

### Bad: completed treated like removed noise

- match completes normally
- app behaves as if it should be hidden exactly like cancelled/expired challenge items

### Bad: hidden used as terminal explanation

- card disappears
- code/docs treat hidden as the lifecycle reason

## Mapping Checklist

Before changing remote UI mapping, ask:

1. what is the authoritative lifecycle state?
2. what role is looking at it?
3. what surface is rendering it?
4. what card, overlay, screen, or list should that combination produce?
5. what actions should be available?
6. am I accidentally deriving truth from UI instead of deriving UI from truth?

If those answers are unclear, the mapping change is probably unsafe.

## Relationship to Other Docs

Use this doc when the problem is:

**given the authoritative state, what should the UI actually show?**

Use it with:
- `lifecycle-stages.md` for the canonical stage model
- `challenger-vs-receiver-rules.md` for role asymmetry
- `create-accept-decline-cancel.md` for early challenge-phase transitions
- `ready-lobby-gameplay-flow.md` for start-flow mapping after ready
- `expiry-and-terminal-states.md` for terminal/non-actionable meaning
- `replay-lifecycle-rules.md` for replay-specific state-to-UI behavior

This doc answers:

**how should authoritative remote lifecycle truth map to visible UI?**

## Bottom Line

In Dart Freak remote matches, the UI should never invent lifecycle meaning.

The authoritative state is the truth.  
Role and surface shape the interpretation.  
The visible card, overlay, list, and actions must be derived from that.