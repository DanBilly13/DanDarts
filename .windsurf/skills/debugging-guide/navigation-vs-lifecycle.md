> Supporting reference for: debugging-guide  
> Apply when: debugging Dart Freak bugs where the symptom looks like a navigation problem — wrong screen, duplicate push, missing push, stuck overlay, bad dismissal, or premature/late route change — but it is unclear whether the real cause is navigation logic or incorrect remote lifecycle truth  
> Do not apply to: pure local UI navigation polish, simple router wiring changes with no diagnostic uncertainty, or bugs where the lifecycle truth is already confirmed correct and the issue is clearly only route execution

# Navigation vs Lifecycle

## Purpose

This document explains one of the most important debugging distinctions in Dart Freak:

**is this really a navigation bug, or is navigation only reflecting a broken lifecycle decision?**

A lot of debugging goes wrong because route symptoms get blamed on navigation too early.

Symptoms like:
- gameplay pushed too early
- lobby never pushed
- overlay did not dismiss
- replay screen opened at the wrong time
- duplicate push happened
- user stayed on the wrong screen
- screen dismissed too soon or too late

do **not** automatically mean the navigation layer is wrong.

Sometimes:
- the lifecycle truth is wrong
- the lifecycle truth is right, but the transition was evaluated too early
- the UI is mapping the lifecycle incorrectly
- a stale view/request is still acting
- navigation is simply executing a bad upstream decision

This document exists to separate those cases.

## Core Rule

Always ask these questions in order:

1. **What authoritative lifecycle truth should be true right now?**
2. **Given that truth, should navigation happen at all?**
3. **If yes, is the wrong thing happening in route execution?**

In short:

**lifecycle authorizes navigation; navigation executes it**

Do not debug route symptoms as pure navigation bugs until lifecycle truth is confirmed.

## The Three-Layer Model

When a route-related symptom appears, separate the problem into these layers:

### 1. Lifecycle authorization layer
Should the user actually move screens yet?

### 2. Navigation decision layer
Did the correct owner decide to request the route change?

### 3. Navigation execution layer
Did the router/push/pop/dismiss actually happen correctly?

A good diagnosis places the bug in one of these layers.

## What Counts as a Lifecycle-Authorized Navigation

A navigation is lifecycle-authorized only when the underlying lifecycle truth says the route change is valid.

Examples:
- ready may authorize join/lobby entry, but not gameplay
- lobby may authorize start-flow UI, but not necessarily gameplay yet
- in_progress authorizes gameplay UI
- completed authorizes end-game/history context
- cancelled/expired may authorize dismissal or removal from actionable UI
- replay ready may authorize replay lobby entry, but not replay gameplay yet

If the lifecycle truth does not authorize the route, then pushing that route is not a navigation success.  
It is a lifecycle mistake expressed through navigation.

## What a Real Navigation Bug Looks Like

A true navigation bug is more like:
- the correct lifecycle truth is known
- the correct owner requested the route change
- but the router/push/pop/dismiss behavior itself is wrong

Examples:
- correct gameplay transition was authorized, but the route pushed twice
- correct dismissal was authorized, but overlay did not dismiss
- correct route was requested, but the stack did not move
- correct popToRoot + push sequence was requested, but the wrong route order happened

These are real navigation-layer issues.

## What a Lifecycle Bug Disguised as Navigation Looks Like

A lifecycle bug disguised as navigation looks like:
- gameplay opened too early because the match was not really in_progress
- lobby never opened because the authoritative transition never actually left ready
- replay UI stayed open because the replay was still authoritatively actionable, or because the app never confirmed otherwise
- completed route did not appear because the match never actually reached completed truth
- overlay dismissed based on UI assumption instead of authoritative terminal reason

These are not route-execution problems first.  
They are lifecycle/transition/truth problems.

## The First Question

Whenever someone says:
- “it navigated wrong”
- “it pushed too early”
- “it didn’t open the next screen”
- “the overlay is stuck”
- “the wrong screen is showing”

the first question is:

**Should navigation have happened yet, according to authoritative lifecycle truth?**

If the answer is no:
- this is not primarily a navigation bug

If the answer is yes:
- continue to navigation-layer diagnosis

This is the single most important rule in this document.

## Lifecycle Before Navigation

Navigation should always be downstream of lifecycle truth.

Correct order:
1. authoritative state becomes correct
2. the correct owner interprets that truth
3. the route change becomes allowed
4. navigation executes

Wrong order:
1. local UI looks close enough
2. push route optimistically
3. hope authoritative truth catches up

That second pattern is the source of many “navigation bugs” that are not actually navigation bugs.

## Common Lifecycle-First Examples

### Example 1 — Gameplay pushed too early

Symptom:
- gameplay screen opened
- but match was not really in_progress yet

Wrong conclusion:
- navigation pushed too early

Better diagnosis:
- lifecycle authorization was wrong
- navigation merely executed a route that should not have been requested yet

### Example 2 — Lobby never opened

Symptom:
- join tapped
- user still sees ready UI

Wrong conclusion:
- router is broken

Better first question:
- did authoritative truth actually move into lobby?
- if not, navigation was never authorized

### Example 3 — Replay opened wrong route

Symptom:
- replay flow seems to jump incorrectly

Wrong conclusion:
- replay navigation bug

Better first questions:
- was a new replay match actually created?
- what lifecycle stage is the new replay match in?
- is the app trying to route from old-match context instead of new-match lifecycle truth?

## Common True Navigation Examples

### Example 1 — Duplicate push after correct truth

Symptom:
- authoritative in_progress is correct
- gameplay should open
- but it pushed twice

This is likely a true navigation/owner/duplicate-trigger problem.

### Example 2 — Dismissal authorized but not executed

Symptom:
- authoritative terminal/non-actionable truth is correct
- overlay should dismiss
- but overlay remains visible

This may now be a navigation/overlay execution problem or stale-surface problem, not a lifecycle truth problem.

### Example 3 — Correct route requested, wrong stack behavior

Symptom:
- lifecycle truth and route authorization are correct
- but push/pop ordering is wrong

This is a true route execution issue.

## Navigation Symptom vs Lifecycle Symptom

Use this quick split.

### Likely lifecycle-first symptom
- pushed too early
- did not become eligible to push
- wrong phase showed next screen
- replay flow skipped stages
- completed route missing because completion truth unclear

### Likely navigation-first symptom
- duplicate push after correct truth
- pop/push ordering broken
- correct dismissal did not execute
- correct owner requested route, but wrong route behavior followed

This is a heuristic, not absolute — but it is a useful first pass.

## The Diagnosis Test

Use this test whenever navigation looks wrong.

### Question 1
What authoritative lifecycle state should be true right now?

### Question 2
Is that lifecycle truth actually true?

If no:
- lifecycle/transition bug

If yes:
- continue

### Question 3
Given that truth, should the user actually change route/screen/surface right now?

If no:
- lifecycle authorization bug, not navigation bug

If yes:
- continue

### Question 4
Did the correct owner request the route change?

If no:
- ownership/stale-actor/navigation-decision bug

If yes:
- continue

### Question 5
Did the router/overlay/dismiss execution behave correctly?

If no:
- navigation execution bug

That is the core classifier.

## Ownership Matters Here Too

A lot of apparent navigation bugs are really **wrong-owner** bugs.

Examples:
- lifecycle truth changed correctly
- but the wrong view/observer tried to navigate
- or multiple owners tried to navigate
- or a stale instance still acted

That is not purely lifecycle truth, but it is also not purely router execution.

So after lifecycle truth is confirmed, ask:
- who was supposed to decide this route change?
- did the correct owner do it?
- did another stale actor also act?

This is often the real explanation behind duplicate pushes or mistimed transitions.

## Replay-Specific Warning

Replay bugs are especially easy to misclassify as navigation bugs because replay combines:
- old completed match context
- new replay match lifecycle
- overlay UI
- route transitions
- possible dismissal rules

So if replay navigation feels wrong, first ask:
1. am I reasoning from old-match context or new replay-match truth?
2. what lifecycle stage is the new replay match really in?
3. should navigation actually happen yet?
4. if yes, is the wrong owner or wrong execution layer acting?

This prevents a lot of false “navigation bug” diagnoses.

## Terminal-State Warning

Dismissals are especially easy to misclassify.

Symptoms like:
- overlay stayed open
- card did not disappear
- user did not leave current screen

may be caused by:
- terminal truth never changed
- wrong terminal reason interpretation
- stale surface still rendering old truth
- navigation/dismissal execution failure

So always separate:
- should this be non-actionable yet?
from
- did the dismiss/remove/navigation actually execute?

## Stale Actor vs Navigation

Some route bugs are not lifecycle bugs and not router bugs either.

They are stale-actor bugs:
- old view instance still pushing
- old async completion still dismissing
- old callback still navigating after ownership changed

That means:
- lifecycle truth may be correct
- route target may even be correct
- but the actor triggering it is wrong

So after confirming lifecycle authorization, also ask:
- was the correct current actor doing the navigation?

## Good Questions To Ask

Ask:
- what authoritative lifecycle truth should be true right now?
- does that truth actually authorize navigation yet?
- if yes, who should own the route decision?
- did the correct owner act?
- if yes, did the route execution itself go wrong?
- is this lifecycle, ownership, stale actor, or true navigation execution?

These questions separate the layers cleanly.

## Bad Questions To Ask

Avoid starting with:
- “should we just push from here instead?”
- “can we add a delay before navigation?”
- “should we dismiss the overlay manually?”
- “maybe NavigationStack is weird”
- “can we just force the route now?”
- “maybe this should open gameplay when countdown starts”

Those questions often skip lifecycle authorization entirely.

## Good Debug Examples

### Good example: gameplay opened too early

- authoritative truth checked: still lobby
- gameplay should not have opened yet
- diagnosis: lifecycle authorization bug, not route execution bug

### Good example: route never changed

- authoritative truth checked: still ready
- lobby was never authoritatively reached
- diagnosis: lifecycle/transition bug, not router bug

### Good example: correct truth, duplicate push

- authoritative truth checked: in_progress
- gameplay should open
- correct transition authorized
- route pushed twice
- diagnosis: navigation ownership/execution bug

### Good example: correct terminal truth, overlay still visible

- authoritative truth checked: replay no longer actionable
- overlay should dismiss
- if surface has fresh truth and still stays open:
- diagnosis: navigation/overlay execution or stale-surface bug

## Relationship to Other Docs

Use this doc when the symptom looks route-related and the main question is:

**is navigation actually broken, or is navigation only reflecting a broken lifecycle decision?**

Use it with:
- `remote-debug-order.md` for the full remote debug ladder
- `lifecycle-vs-mapping.md` to distinguish lifecycle truth from UI interpretation
- `realtime-vs-truth.md` when the symptom is stale or did-not-update
- `evidence-and-logging.md` for what proof to collect
- `swiftui-navigation` skill docs for navigation ownership and execution rules
- `remote-match-lifecycle` docs for what the lifecycle should actually authorize

This doc answers:

**is this really a navigation bug, or is it a lifecycle bug showing up through navigation?**

## Bottom Line

In Dart Freak, route symptoms are not automatically navigation bugs.

First verify that lifecycle truth actually authorizes the route.  
Then verify the correct owner requested it.  
Only then debug route execution itself.