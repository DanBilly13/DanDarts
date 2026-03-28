> Supporting reference for: debugging-guide  
> Apply when: collecting evidence for a Dart Freak bug, deciding what logs matter, interpreting existing logs, or debugging cases where guesses are replacing proof  
> Do not apply to: pure styling issues, copy edits, or trivial bugs where the broken layer is already obvious and no evidence gathering is needed

# Evidence and Logging

## Purpose

This document defines how to gather and use evidence when debugging Dart Freak.

It exists because many bad fixes start with weak evidence.

Typical bad debugging pattern:
- see a symptom
- assume the cause
- patch the nearest code
- add more logging afterward
- realize later the logs never actually proved the diagnosis

This document prevents that.

It explains:
- what counts as useful evidence
- what logs should prove
- how to read logs in the right order
- how to avoid drawing conclusions from weak signals

## Core Rule

Do not treat symptoms as proof.

Always collect evidence that answers these questions in order:

1. what exact behavior happened?
2. what authoritative truth should have been true?
3. what evidence proves whether that truth changed?
4. what evidence proves which layer failed?
5. what evidence proves the proposed fix is correcting the real problem?

In short:

**evidence should prove the layer, not just describe the symptom**

## What Good Evidence Looks Like

Good evidence is:
- specific
- ordered
- tied to a known layer
- able to confirm or falsify a diagnosis

Good evidence usually tells you one of these things:
- the authoritative state changed
- the authoritative state did not change
- the correct role was or was not used
- the correct transition did or did not complete
- the UI received or did not receive updated truth
- the UI mapped the truth correctly or incorrectly
- the route was authorized or unauthorized
- the stale actor was or was not the thing that acted

Good evidence helps eliminate possibilities, not multiply guesses.

## What Weak Evidence Looks Like

Weak evidence is:
- purely visual
- unordered
- uncoupled from authoritative truth
- unable to prove which layer failed

Examples of weak evidence:
- “the card looked wrong”
- “it felt late”
- “I think realtime didn’t fire”
- “the screen seemed stuck”
- “the button did nothing”
- “the overlay looked stale”

These may be valid symptoms, but they are not yet evidence of cause.

## The Evidence Ladder

Use this evidence ladder when debugging:

### 1. Symptom evidence
What exactly did the user see?

### 2. Truth evidence
What authoritative state actually existed?

### 3. Transition evidence
Did the expected lifecycle change really happen?

### 4. Mapping evidence
Did the UI interpret that truth correctly?

### 5. Delivery evidence
Did the right surface receive the updated truth?

### 6. Navigation/actor evidence
Did the correct owner or route execution happen from that truth?

The most useful logs help you climb this ladder in order.

## Best Kinds of Evidence in Dart Freak

The strongest evidence usually comes from a combination of:

- authoritative state/status/fields
- player role
- lifecycle moment
- expected transition
- current UI surface
- current visible UI
- route/overlay behavior
- timestamps and ordering
- before/after logs

You want evidence that can connect:
- what the match really was
to
- what the app showed
to
- what should have happened next

## Authoritative Truth Evidence

This is the most important evidence category.

You want proof of things like:
- what lifecycle state the match was really in
- whether the expected state transition completed
- what terminal reason really applied
- whether a new replay match actually existed
- which role-specific fields were actually present
- whether gameplay had really become in_progress

Good truth evidence is stronger than:
- UI labels
- card colors
- route presence
- local assumptions

### Key rule

If you do not know the authoritative truth yet, your diagnosis is still weak.

## Transition Evidence

Transition evidence answers questions like:
- did pending really become ready?
- did ready really become lobby?
- did lobby really become in_progress?
- did in_progress really become completed?
- did the replay request really create a new match?
- did cancel/decline/expiry really make the match non-actionable?

This matters because a user action is not proof that the transition succeeded.

Examples:
- tapping accept is not proof of ready
- tapping join is not proof of lobby
- countdown appearing is not proof of in_progress
- replay button tapped is not proof a new replay match exists

You need logs or evidence that show the transition result, not just the attempt.

## Role Evidence

Many bugs in Dart Freak depend on role:
- challenger
- receiver

So good evidence should often tell you:
- which role the current user was
- whether the code interpreted the role correctly
- whether the correct role-specific UI/actions/fields were being used

A lot of “wrong UI” bugs are really “wrong role evidence” bugs.

Examples:
- pending rendered like receiver UI for challenger
- wrong readiness field being checked
- wrong player name shown in a role-sensitive surface

If role matters, log it.

## Mapping Evidence

Mapping evidence answers:

**given the correct truth, what should the UI have shown?**

This is where you compare:
- authoritative state
- role
- surface
- actual UI

Good mapping evidence might show:
- authoritative state is ready
- user is challenger
- current surface is outgoing/ready list
- UI still rendering sent
- therefore mapping is wrong

Without that structure, logs often only prove that “something looked wrong,” not that mapping was the broken layer.

## Delivery Evidence

Delivery evidence answers:
- did the current surface get the updated truth?
- did one side update while another stayed stale?
- did one list refresh while another did not?
- did the overlay keep rendering old truth?

This is especially important for bugs that sound like:
- “it didn’t update”
- “one side changed and the other did not”
- “overlay stayed stale”
- “card was still live after cancel/decline”

Good delivery evidence should help distinguish:
- truth never changed
from
- truth changed but this surface did not receive it

## Navigation / Actor Evidence

Only after truth, transition, mapping, and delivery are understood should you rely on route/actor evidence.

This evidence helps answer:
- was navigation actually authorized?
- did the correct owner request the route?
- did the router push/pop correctly?
- did a stale instance or stale async callback act instead?
- did an overlay dismissal execute when it should have?

Good actor/navigation evidence is useful, but it is not usually the first evidence you need for a remote bug.

## The Best Logging Order

When adding or reading logs, prefer this order:

1. lifecycle moment
2. authoritative truth
3. role
4. expected transition
5. result of transition
6. expected UI mapping
7. actual UI/surface result
8. delivery/realtime behavior
9. navigation/dismiss/owner behavior

That ordering mirrors the real diagnostic ladder.

Logs that start too late in the chain often create confusion.

## What Good Logs Should Prove

A good log line should help answer at least one specific question.

Examples:
- what state was the match in?
- what role was the current user?
- what transition was attempted?
- did the authoritative transition succeed?
- what did the current surface think the match was?
- why was a card shown or hidden?
- why did the overlay stay visible or dismiss?
- why did navigation happen or not happen?

A log that does not help answer a concrete question is usually noise.

## Good Logging Characteristics

Good logs are:

### Specific
They name the real thing:
- state
- role
- transition
- decision
- surface

### Ordered
They show sequence clearly.

### Comparative
They show before/after or expected/actual when useful.

### Minimal but meaningful
They are not giant dumps with no interpretation.

### Layer-aware
They make it clear whether they are talking about:
- truth
- transition
- mapping
- delivery
- navigation

## Bad Logging Characteristics

Bad logs are:

### Too vague
- “updated”
- “done”
- “handled”
- “route changed”
- “card gone”

### Too late
Only logging the final symptom with no earlier evidence.

### Too noisy
Huge repeated dumps that hide the important moment.

### Too UI-first
Logs that describe only how something looked, not what truth caused it.

### Too assumption-heavy
Logs that label something as “cancelled” or “ready” without proving the authoritative basis for that label.

## The Difference Between Logs and Diagnosis

Logs are raw evidence.  
Diagnosis is the explanation built from them.

Do not confuse these.

Bad debugging often does this:
- read one log line
- jump to diagnosis
- stop gathering evidence

Good debugging does this:
- gather logs across the relevant ladder
- confirm or falsify the broken-layer hypothesis
- only then explain what is broken

A single dramatic log line is rarely enough by itself.

## Good Evidence Examples

### Good example: stale card after accept

Useful evidence:
- authoritative state became ready
- current user is challenger
- correct mapping for challenger + ready should be ready card
- current surface still renders sent
- therefore truth is correct, mapping or delivery is wrong

### Good example: no lobby entry after join

Useful evidence:
- join action attempted
- authoritative state stayed ready
- no authoritative proof of lobby transition
- therefore not primarily a navigation bug

### Good example: overlay should dismiss

Useful evidence:
- authoritative truth says replay is no longer actionable
- current surface is replay overlay
- intended mapping says overlay should dismiss
- overlay still visible with stale data
- therefore delivery, stale-surface, or dismiss execution bug

### Good example: completed vanished

Useful evidence:
- authoritative truth is completed
- current surface is end-game/history-capable
- mapping should preserve completion meaning
- UI hid it like cancelled/expired
- therefore mapping bug

## Bad Evidence Examples

### Bad example: accept bug
- “user tapped accept”
- “card did not change”

Missing:
- authoritative truth
- role
- expected mapping
- whether truth changed at all

### Bad example: replay bug
- “overlay looked wrong”
- “it probably needs a delay”

Missing:
- whether new replay match exists
- replay lifecycle stage
- whether overlay had fresh truth

### Bad example: navigation bug
- “screen didn’t move”

Missing:
- whether navigation was even authorized by lifecycle truth

## What To Collect Before Suggesting a Fix

Before proposing a fix, try to gather evidence for:

1. exact lifecycle moment
2. authoritative state
3. current user role
4. expected next transition or expected mapping
5. proof that the transition did or did not happen
6. actual current surface behavior
7. whether this is truth, mapping, delivery, navigation, or stale actor

If you cannot fill those in, your fix is probably still guessy.

## When to Add More Logs

Add more logs when:
- you cannot tell which layer failed
- the current logs show only symptoms, not truth
- two plausible diagnoses still remain
- one side updates and the other stays stale
- replay old-match vs new-match identity is unclear
- terminal reason is unclear
- role interpretation is unclear

Do not add logs just because debugging feels hard.  
Add logs to answer missing questions.

## What Not To Infer Too Early

Do not infer these without proof:
- “realtime broke”
- “navigation broke”
- “the state must be cancelled”
- “the match must be in progress”
- “this overlay is stale because dismiss failed”
- “accept succeeded”
- “join succeeded”
- “replay exists”

All of those need evidence.

## Relationship to Other Docs

Use this doc when the main question is:

**what evidence do I need, and how should I read the logs?**

Use it with:
- `debug-order-overview.md` for the general diagnostic ladder
- `remote-debug-order.md` for remote-specific diagnosis
- `lifecycle-vs-mapping.md` to distinguish truth from interpretation
- `realtime-vs-truth.md` to distinguish stale delivery from unchanged truth
- `navigation-vs-lifecycle.md` when the symptom looks route-related

This doc answers:

**what proof should I gather before deciding what is broken?**

## Bottom Line

In Dart Freak, good logs do not just describe what looked wrong.

They prove which layer was wrong.