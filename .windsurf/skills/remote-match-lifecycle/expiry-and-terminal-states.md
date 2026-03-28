> Supporting reference for: remote-match-lifecycle  
> Apply when: working on expiry behavior, cancelled/completed terminal outcomes, decline-related disappearance, removal from actionable UI, or any bug where a remote match ends or disappears incorrectly for one or both players  
> Do not apply to: normal stage progression before termination, local match flow, or generic realtime/navigation work unless the bug is specifically about terminal lifecycle outcomes

# Expiry and Terminal States

## Purpose

This document defines how remote matches end, expire, or otherwise leave actionable UI in Dart Freak.

This part of the lifecycle is easy to get wrong because many different outcomes can all look similar at the UI layer:

- the card disappears
- the card fades out
- the overlay dismisses
- the match leaves actionable lists
- the match moves to history
- the match is no longer joinable

Those visible results do **not** all mean the same thing.

This document exists to prevent mistakes such as:
- treating all removals as cancellation
- treating decline as identical to expiry
- treating completed matches as simply “gone”
- confusing authoritative terminal reason with client presentation timing
- forgetting that one side may update correctly while the other stays stale
- collapsing “hidden from actionable UI” into one vague lifecycle concept

## Core Rule

When a remote match stops being actionable, always separate:

1. the **authoritative terminal or expiry reason**
2. the **expected UI outcome**
3. the **timing/presentation of removal**

In short:

**terminal reason first, UI result second, fade/disappearance behavior third**

## Terminal vs Non-Actionable

These are not always the same thing.

### Terminal state

A terminal state means the remote match lifecycle has ended for that match.

Typical examples:
- completed
- cancelled
- expired

### Non-actionable UI outcome

A non-actionable UI outcome means:
- the user can no longer act on the match from that surface
- the card may disappear
- the overlay may dismiss
- the match may move to history
- the match may become hidden

A non-actionable UI result is often caused by a terminal state, but the UI behavior still needs to be reasoned about separately.

## Main Terminal Outcomes

The main terminal outcome categories in remote lifecycle are usually:

- completed
- cancelled
- expired
- decline-related outcome or disappearance behavior

These should not be flattened into one generic “ended” concept.

## Completed

### Meaning

Completed means the remote match finished normally through gameplay.

This is the normal successful terminal state.

### What it means lifecycle-wise

- the match reached its intended end
- gameplay is over
- the same match should not re-enter active gameplay
- post-match context such as history or replay may now become relevant

### Expected UI outcome

Completed matches usually:
- leave active/actionable remote flow
- move into history or result views
- may remain visible in end-game or history contexts
- may expose replay affordances from completed context

### Important rule

Completed is not the same as:
- cancelled
- expired
- declined
- hidden

A completed match has a specific terminal meaning and should usually remain meaningful in history/results.

### Common mistake

Treating completed as if it should simply disappear from the app the same way a cancelled or expired challenge might disappear from actionable cards.

That is usually wrong.

## Cancelled

### Meaning

Cancelled means the remote match was manually ended or withdrawn through a cancellation path.

This is a terminal outcome, but not a successful gameplay completion.

### Typical contexts

Cancellation may happen in different lifecycle stages, such as:
- early challenge phase
- ready phase
- lobby/start-flow phase
- possibly later phases if the implementation allows abort-like behavior

### Expected UI outcome

Cancelled matches usually:
- stop being actionable
- stop looking live
- disappear from challenge/actionable surfaces
- may briefly present a cancelled/removal state depending on the UI design

### Important rule

Cancelled means:
- the lifecycle ended by cancellation
- not by normal gameplay completion
- not by timeout

### Common mistake

Using “cancelled” as a catch-all explanation for any match that vanished from the UI.

Do not do that.  
The removal reason must still be distinguished authoritatively.

## Expired

### Meaning

Expired means the match or challenge timed out under lifecycle timing rules.

This is a terminal timeout outcome, not a manual user action.

### Typical contexts

Expiry may happen in different pre-terminal phases depending on the implementation, such as:
- challenge waiting phase
- ready phase
- lobby/start-flow phase

### Expected UI outcome

Expired matches usually:
- stop being actionable
- disappear from challenge/start-flow surfaces
- may be removed from visible lists quickly
- may have different presentation timing than cancellation or decline

### Important rule

Expired is distinct from:
- cancelled
- completed
- decline-related disappearance

### Common mistake

Confusing:
- “the card disappeared after some time”
with
- “the match was cancelled”

Timeout and manual cancellation are different lifecycle outcomes.

## Decline-Related Outcome

### Meaning

Decline is an early-phase receiver-side refusal outcome.

This needs careful handling because in many implementations, decline is partly a lifecycle outcome and partly a presentation/removal behavior.

### Important caution

Do **not** assume that “declined” is always a canonical persisted terminal stage.

Depending on implementation, decline may be:
- a true authoritative terminal result
- a client presentation layered on top of another terminal outcome
- a brief visible state before the card disappears
- an action whose most important visible result is removal from the actionable challenge UI

### Practical rule

When reasoning about decline, always separate:
- who performed the decline action
- what authoritative result was recorded
- what the declining player sees afterward
- what the other player sees afterward
- whether a brief declined presentation is expected before removal

### Common bug pattern

- receiver declines
- receiver UI resolves correctly
- challenger still sees a stale outgoing card

That usually means the authoritative decline outcome and the cross-player UI update are not aligned.

## Hidden / Removed From Actionable UI

This is a presentation outcome, not automatically a lifecycle category.

A match may leave actionable UI because it is:
- completed
- cancelled
- expired
- declined or decline-resolved
- moved into another lifecycle surface
- no longer eligible for that specific list

### Important rule

“Hidden” is not the same thing as “terminal reason.”

Always ask:
- why is it hidden?
- is it completed, cancelled, expired, decline-resolved, or just moved elsewhere?

### Common mistake

Using “hidden” as if it explains lifecycle truth.

It only explains presentation outcome.

## Fade-Out / Brief Presentation Rule

Sometimes the correct UX is not immediate hard removal.

A match may:
- briefly show cancelled
- briefly show declined
- briefly fade
- then disappear

This does **not** change the authoritative lifecycle meaning.

It only changes presentation timing.

### Important rule

Always separate:
- authoritative state
- role-specific UI state
- fade/removal timing

A brief declined or cancelled card does not mean there is a new lifecycle stage called “fading.”  
It means the UI is choosing to present a terminal outcome briefly before removal.

## One-Side Updated / Other-Side Stale Rule

A very common terminal-state bug is:

- one player sees the correct terminal result
- the other player keeps seeing an outdated actionable card or overlay

This is especially common for:
- decline
- cancel
- replay cancel
- remote challenge removal

### Correct rule

When a terminal or non-actionable outcome happens, both sides should converge correctly on the new truth.

That does **not** always mean the exact same UI timing, but it does mean:
- neither side should remain in stale actionable state
- both sides should eventually render the same authoritative outcome correctly for their role and surface

## Completed vs Removed

These should never be conflated.

### Completed
- finished through gameplay
- usually meaningful in history/end-game/replay context
- not just “gone”

### Removed from actionable UI
- may happen for many reasons
- says nothing by itself about whether the match completed, cancelled, expired, or declined

This distinction is extremely important.

## Cancelled vs Expired

These should also never be conflated.

### Cancelled
- user-driven or action-driven termination
- someone actively ended or withdrew the match

### Expired
- time-driven termination
- lifecycle window elapsed

The visible outcome may both be “card no longer actionable,” but the lifecycle meaning is different.

## Decline vs Cancel

These are especially easy to blur in early lifecycle handling.

### Decline
- usually receiver-owned refusal of incoming challenge
- requester experiences the result

### Cancel
- usually requester/challenger-owned withdrawal of outgoing challenge in early phase
- recipient experiences the result

Even if the eventual UI outcome is “challenge gone,” the action ownership and lifecycle meaning are different.

## Terminal Outcome by Surface

The same terminal result may behave differently depending on where the user is looking.

Examples:
- challenge list
- ready list
- active match surface
- replay overlay
- history
- end-game screen

### Important rule

Do not assume a terminal outcome always means:
- immediate full disappearance from everywhere

Instead ask:
- from which UI surface should it disappear?
- from which UI surface should it persist?
- should it move into history?
- should an overlay dismiss?
- should a card briefly show terminal presentation before removal?

## History Rule

History is not just another removal surface.

A completed match may:
- leave actionable flow
- remain visible in history
- remain available for result inspection
- become the source context for replay

This makes history fundamentally different from:
- cancellation disappearance
- expiry disappearance
- decline disappearance

### Key rule

Completed terminal outcomes usually still retain historical meaning.  
Cancelled or expired challenge-phase matches may not have the same visible persistence.

## Replay Terminal Rule

Replay uses the same general terminal concepts, but they belong to the **new replay match**, not the old completed one.

That means:
- replay can be cancelled
- replay can be declined
- replay can expire
- replay can complete normally

These outcomes should not rewrite the lifecycle meaning of the old completed match.

### Important rule

Always keep the two match identities separate:
- old completed match
- new replay match

## Terminal Reason vs UI Copy

Do not let UI labels become your lifecycle model.

For example:
- “Cancelled”
- “Declined”
- “Expired”
- “Match unavailable”
- “No longer available”

These are user-facing presentation labels.  
They may be correct or helpful, but they are not the authoritative lifecycle model by themselves.

Always map:
- authoritative outcome
- role/surface
- intended presentation copy

in that order.

## Good Patterns

### Good: completed moves to history

- gameplay ends normally
- authoritative state becomes completed
- active gameplay flow ends
- match remains meaningful in history/end-game context

### Good: cancelled removes actionability on both sides

- authoritative cancellation occurs
- both players stop seeing it as actionable
- presentation may differ slightly by surface/timing
- no side remains stuck in stale live state

### Good: expired challenge disappears correctly

- timeout occurs
- authoritative state becomes expired
- match stops being actionable
- card disappears from active challenge surfaces

### Good: decline resolves both sides

- receiver declines
- authoritative outcome updates appropriately
- receiver stops seeing incoming actionable challenge
- challenger stops seeing stale outgoing challenge
- optional brief declined presentation may occur before removal

## Bad Patterns

### Bad: all removals treated as cancellation

- card disappears
- code/documentation assumes cancelled without proof

### Bad: completed treated like a vanished card

- match finishes normally
- app removes all meaning/history context as if the match never mattered

### Bad: one side updates, other side stays stale

- decline/cancel/expiry happens
- only one player resolves correctly

### Bad: fade-out treated as lifecycle truth

- brief terminal presentation exists
- code assumes there is now a special persisted lifecycle stage called fade or removed

### Bad: replay failure mutates old match meaning

- replay cancelled or declined
- app behaves as if old completed match was undone

## Terminal-State Checklist

Before changing expiry or terminal-state handling, ask:

1. what is the authoritative terminal or non-actionable reason?
2. is this completed, cancelled, expired, or decline-related?
3. should the match disappear, fade briefly, move to history, or dismiss an overlay?
4. should both players resolve to the correct non-actionable state?
5. am I accidentally using UI disappearance as proof of lifecycle reason?
6. am I keeping old-match vs replay-match identity separate where needed?

If those answers are unclear, the terminal-state change is probably unsafe.

## Relationship to Other Docs

Use this doc for terminal and expiry behavior.

Use it with:
- `lifecycle-stages.md` for canonical stage reasoning
- `create-accept-decline-cancel.md` for early-phase decline/cancel behavior
- `challenger-vs-receiver-rules.md` for role-specific outcomes
- `authoritative-state-and-ui-mapping.md` for exact lifecycle-to-UI interpretation
- `ready-lobby-gameplay-flow.md` for what happens before a match becomes terminal
- `replay-lifecycle-rules.md` for replay-specific terminal handling

This doc answers:

**what does it mean for a remote match to expire, complete, cancel, decline, or otherwise stop being actionable?**

## Bottom Line

In Dart Freak, “the match disappeared” is not a lifecycle explanation.

Always identify the real terminal or expiry reason first, then map the correct UI outcome from that.