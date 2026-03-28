> Supporting reference for: remote-match-lifecycle  
> Apply when: working on remote challenge creation, sent/pending card behavior, accept/decline/cancel actions, or any bug in the early remote lifecycle before lobby entry  
> Do not apply to: local match flow, lobby/countdown/gameplay start logic, or general realtime/navigation work unless the bug is specifically in the challenge-action phase

# Create, Accept, Decline, Cancel

## Purpose

This document defines the early remote lifecycle rules in Dart Freak:
- challenge creation
- outgoing vs incoming challenge presentation
- accept behavior
- decline behavior
- cancel behavior

This is the phase before lobby flow.

A lot of remote bugs happen here because the code accidentally:
- treats sent and pending as different authoritative stages
- assumes both players should have the same actions
- mixes up decline and cancel outcomes
- reasons from UI text instead of authoritative state
- forgets that replay requests re-enter this same challenge phase

This document is about the **challenge-action phase** of the remote lifecycle.

---

## Core Rule

In the early remote lifecycle, always reason in this order:

1. what authoritative challenge state is the match in?
2. is the current user challenger or receiver?
3. what challenge card should that role see?
4. what actions should that role be allowed to take?
5. what authoritative transition should happen next?

In short:

**authoritative challenge state first, role-specific actions second**

---

## Where This Phase Sits in the Lifecycle

This document covers the early lifecycle before lobby.

Typical flow:

```text
challenge creation → pending → ready
```

with early exits such as:
- decline-related outcome
- cancellation
- expiry

This is the phase where the two players are most visibly asymmetric.

---

## Challenge Creation

### Meaning

Challenge creation is the moment a new remote match record is created and enters the first actionable challenge stage.

This is the start of the remote lifecycle for that match.

### Typical owner

Challenge creation is usually owned by:
- the challenger
- a replay requester when replay creates a new match

### Important rule

Challenge creation is not just "show a card."

It means a new authoritative remote match now exists, and the client should derive the correct outgoing/incoming presentation from that.

### What should happen next

After creation:
- challenger should usually see an outgoing challenge presentation
- receiver should usually see an incoming challenge presentation
- the underlying authoritative stage is typically still one shared challenge state

### Challenge Creation UI Rule

After a challenge is created, the two players should usually not see identical UI.

Typical pattern:
- challenger sees sent
- receiver sees pending

This is one of the most important asymmetry rules in the feature.

If both sides are shown the same early-stage UI without a good reason, that is suspicious.

### Sent vs Pending Rule

The "sent" and "pending" distinction is usually a presentation distinction, not a lifecycle distinction.

Typical correct model:
- one authoritative challenge state
- challenger sees sent
- receiver sees pending

That means:
- do not build server truth around the word sent
- do not create business logic that assumes sent is its own authoritative lifecycle stage unless the implementation explicitly does that

The right reasoning is usually:

**pending lifecycle state + challenger role = sent presentation**

---

## Challenger Rules in the Challenge Phase

### What challenger usually sees

During the early challenge phase, challenger typically sees:
- an outgoing challenge card
- a waiting-for-response state
- a sent-style presentation rather than an incoming challenge UI

### What challenger is usually allowed to do

During this phase, challenger is usually allowed to:
- cancel the outgoing challenge

The challenger is usually not allowed to:
- accept the challenge
- decline the challenge

Those belong to the receiver side of the interaction.

---

## Receiver Rules in the Challenge Phase

### What receiver usually sees

During the early challenge phase, receiver typically sees:
- an incoming challenge card
- a pending-style presentation
- controls that treat the challenge as something they must respond to

### What receiver is usually allowed to do

During this phase, receiver is usually allowed to:
- accept the challenge
- decline the challenge

The receiver is usually not allowed to:
- cancel as the original sender of the challenge
- see the outgoing sent-style presentation

---

## Accept Rules

### Meaning

Accept is the receiver-side action that advances the challenge out of the waiting phase and into the next authoritative stage.

Usually this means the match moves into ready.

### Ownership

Accept is usually a receiver-owned action.

That means:
- receiver triggers accept
- challenger does not accept their own outgoing challenge
- challenger instead reacts to the authoritative stage change after the receiver accepts

### What accept should do

A correct accept flow should:
- update authoritative remote match state
- make the challenge no longer just a waiting challenge
- produce the correct next-stage UI for both roles
- remove the need for receiver to keep seeing accept/decline controls

### Typical next result

- `pending → ready`

### Common mistake

Treating accept as:
- a local UI toggle
- a receiver-only visual change
- something that does not need the challenger UI to update

Accept is a shared lifecycle transition with asymmetric before/after UI.

### After Accept

Once acceptance succeeds:
- receiver should usually stop seeing incoming challenge controls
- challenger should usually stop seeing "waiting for response"
- both players should usually move toward a more symmetric ready-stage presentation

This does not mean the match is already in gameplay.
It means the challenge phase has successfully advanced.

---

## Decline Rules

### Meaning

Decline is the receiver-side action that rejects the incoming challenge.

This is usually a terminal early-stage outcome for that match.

### Ownership

Decline is usually a receiver-owned action.

That means:
- receiver declines
- challenger does not decline
- challenger experiences the result of the receiver's decline

### What decline should do

A correct decline flow should:
- end the challenge's actionable waiting state
- remove or transition the receiver's incoming challenge UI
- produce the correct corresponding result for the challenger's outgoing challenge UI
- keep the authoritative outcome and the presentation outcome aligned

### Important caution

Be careful not to assume that "declined" is always a distinct persisted lifecycle stage.

Depending on implementation, decline may be:
- a true authoritative terminal status
- a UI presentation/result layered on top of another terminal path
- a brief presentation state before disappearance

So when implementing or debugging decline, always separate:
- authoritative result
- client presentation
- removal timing

### Receiver experience after decline

After declining, receiver should generally:
- stop seeing the challenge as actionable
- no longer see accept/decline controls
- usually see the card disappear or transition briefly before removal

### Challenger experience after decline

After the receiver declines, challenger should generally:
- stop seeing the outgoing challenge as still waiting
- see the appropriate decline/removal outcome
- not remain stuck with a live "sent" card forever

This is one of the most common bug areas:
- receiver updates correctly
- challenger does not

That is almost always wrong unless the implementation explicitly intends a temporary presentation state.

---

## Decline vs Cancel

This distinction matters a lot.

**Decline**
- usually owned by receiver
- rejects an incoming challenge

**Cancel**
- usually owned by challenger in the early phase
- withdraws an outgoing challenge

These are not the same user action, even if they may both end the match's actionable early state.

Do not flatten them into one concept just because the UI result eventually becomes "challenge gone."

---

## Cancel Rules

### Meaning

Cancel is usually the outgoing-side action that withdraws a challenge before or during the early pre-lobby phase.

### Ownership

In the early challenge phase, cancel is usually a challenger-owned action.

That means:
- challenger cancels the outgoing challenge
- receiver does not "cancel" the incoming challenge in the same sense
- receiver instead accepts or declines

Later lifecycle stages may have more symmetric cancellation/abort behavior, but this document is about the early challenge phase.

### What cancel should do

A correct cancel flow should:
- end the outgoing challenge's actionable state
- remove or transition the challenger's sent/outgoing UI
- remove or transition the receiver's incoming UI
- keep both sides consistent with the authoritative result

### Common bug pattern

A very common bug is:
- challenger cancels
- challenger UI updates correctly
- receiver UI does not update, or vice versa

That means one side is still rendering stale challenge-phase meaning after the authoritative outcome changed.

---

## Accept vs Cancel Ownership Rule

These actions should usually stay role-separated in the early challenge phase:
- challenger creates and can usually cancel
- receiver can usually accept or decline

If code allows both sides to perform all three actions in the challenge phase without clear design intent, that is suspicious.

---

## Replay Uses the Same Early Challenge Logic

Replay requests usually re-enter this same challenge phase.

That means replay often follows the same broad rules:
- replay requester becomes the outgoing side
- outgoing replay request may show as sent
- incoming replay request may show as pending
- receiver may accept or decline
- requester may cancel before it progresses

Do not treat replay creation as bypassing the challenge-action phase unless the implementation explicitly does that.

---

## Expiry During the Challenge Phase

Expiry may also end the challenge before it ever reaches ready.

When that happens:
- challenger's outgoing card should no longer remain actionable
- receiver's incoming card should no longer remain actionable
- both sides should stop treating the challenge as something that can still be accepted or cancelled

Even if the UI presentation differs slightly before removal, the challenge should no longer behave as live.

---

## Authoritative Truth vs Presentation in This Phase

This phase is especially vulnerable to reasoning mistakes because the UI labels are very human-readable:
- sent
- pending
- accepted
- declined
- cancelled

But the implementation should still be reasoned from:
- authoritative challenge state
- role
- allowed actions
- next authoritative transition

Not from UI wording alone.

A card saying "waiting for response" is not the source of truth.
It is a derived presentation of the challenge state.

---

## Good Patterns

### Good: creation maps asymmetrically
- challenge is created
- challenger sees sent
- receiver sees pending
- same underlying lifecycle state
- different correct role-based presentation

### Good: receiver accepts
- receiver taps accept
- authoritative state advances
- receiver no longer sees accept/decline
- challenger no longer sees waiting-only sent state
- both progress toward ready-stage behavior

### Good: receiver declines
- receiver taps decline
- authoritative result updates
- receiver challenge disappears or transitions appropriately
- challenger outgoing challenge also resolves appropriately
- neither side remains stuck in actionable challenge state

### Good: challenger cancels
- challenger taps cancel
- authoritative result updates
- challenger outgoing card resolves
- receiver incoming card also resolves
- both sides stay consistent

---

## Bad Patterns

### Bad: sent treated as authoritative state
- code assumes sent is a distinct lifecycle stage
- business logic branches off UI wording instead of authoritative state + role

### Bad: receiver updates, challenger stuck
- receiver declines or accepts
- receiver UI changes
- challenger card remains in outdated sent state

### Bad: challenger allowed to accept
- outgoing challenge UI offers accept/decline semantics to the creator
- role ownership is broken

### Bad: receiver allowed to cancel outgoing challenge as if they were the sender
- role-specific action boundaries are lost

### Bad: decline and cancel collapsed into one vague "remove card" behavior
- action ownership disappears
- lifecycle meaning becomes unclear
- bugs become harder to diagnose

---

## Challenge-Phase Checklist

Before changing creation/accept/decline/cancel logic, ask:

1. what authoritative challenge state is the match in?
2. is this user challenger or receiver?
3. should they see sent or pending-style UI?
4. should they be allowed to accept, decline, or cancel?
5. what authoritative transition should happen next?
6. will both sides update correctly after that transition?

If those answers are unclear, the change is probably unsafe.

---

## Relationship to Other Docs

Use this doc for the challenge-action phase of remote lifecycle.

Use it with:
- `lifecycle-stages.md` for overall stage reasoning
- `challenger-vs-receiver-rules.md` for role asymmetry
- `ready-lobby-gameplay-flow.md` for behavior after ready
- `authoritative-state-and-ui-mapping.md` for exact stage-to-UI interpretation
- `expiry-and-terminal-states.md` for what happens when the challenge ends instead of progressing
- `replay-lifecycle-rules.md` for replay-specific differences layered on top of the same early flow

This doc answers:

**how do create, accept, decline, and cancel behave in the early remote challenge phase?**

---

## Bottom Line

In Dart Freak, the early remote challenge phase is intentionally asymmetric.

The challenger usually sends and cancels.
The receiver usually accepts or declines.
And both sides must update correctly from the same authoritative transition.