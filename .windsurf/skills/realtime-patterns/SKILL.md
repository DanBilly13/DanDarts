---
name: realtime-patterns
description: client-side realtime subscription and refetch rules for remote matches. use when working on supabase realtime subscriptions, replay status changes, stale remote cards or overlays, list reload behavior, fetchmatch vs loadmatches decisions, realtime-triggered navigation bugs, or any remote flow where something is not updating after a remote event. also use when adding or modifying subscription logic, or when tasks mention subscription, subscribe, realtime update, stale ui, replay update, card not updating, or overlay not dismissing. do not use for local matches.
---

# Realtime Patterns

Use this skill for **remote match realtime behavior only**.

Do not apply these rules to local matches.

Remote matches are server-authoritative.  
Realtime is a client trigger layer, not the source of truth.

## Core Rules

- Treat realtime as a **signal that something may have changed**.
- Refetch authoritative state before trusting the new state.
- Never drive long-lived remote UI from realtime payload alone.
- Never let realtime payloads directly own navigation.
- Prefer the smallest authoritative refetch that fits the problem.

## What This Skill Is For

Apply these rules when working on:
- adding or changing a realtime subscription
- deciding between `fetchMatch(...)`, `loadMatches(...)`, or forced reload
- replay status updates
- stale cards, stale overlays, or stale remote sections
- remote UI that does not update after a remote event
- bugs where a realtime event arrives but the screen still looks wrong
- navigation bugs caused by realtime-driven state changes

## What This Skill Prevents

Do not:
- patch remote lifecycle state directly from realtime payloads
- assume subscription payloads are complete or final
- navigate immediately from payload state
- skip authoritative refetch when remote UI correctness depends on it
- use local UI assumptions as proof of remote truth

## Standard Decision Order

When a realtime event arrives:

1. decide whether the event is relevant
2. decide whether the screen needs:
   - `fetchMatch(...)`
   - `loadMatches(...)`
   - forced `loadMatches(...)`
3. refetch authoritative state
4. update UI from authoritative state
5. only then allow downstream UI transitions or navigation

## Default Refetch Bias

- active remote lobby/gameplay screen → prefer `fetchMatch(...)`
- list/card/section state → prefer `loadMatches(...)`
- replay overlays or stale list-backed UI during remote flow → allow forced `loadMatches(...)`

Use the narrowest safe path.

## In-Remote-Flow Default

When already in remote flow:
- avoid broad reload churn by default
- prefer active match refetches

Break that default only when stale list-backed state would leave the UI wrong.

Examples:
- replay card/overlay depends on service arrays
- sent/pending/ready card must disappear or move
- cancellation or replay transition would otherwise remain stale

## Navigation Safety Rule

Realtime may trigger a refetch.  
Realtime must not directly own navigation.

Only navigate after:
- authoritative state confirms the transition
- the current screen instance is still valid
- local navigation guards agree

## Navigation Decision Order

When a realtime event might imply navigation:

1. check relevance — is this event for the current user, match, and screen?
2. choose authoritative refetch path — `fetchMatch(...)`, `loadMatches(...)`, or forced `loadMatches(...)`
3. refetch authoritative state
4. validate current screen context — instance still active, match identity still matches
5. validate navigation guards — not already navigating, not already in terminal unwind
6. navigate once — only after all of the above

Realtime may wake navigation up. It may not own navigation.

## Replay Rule

Replay is a special realtime case.

Replay flows may require:
- forced reloads even while in remote flow
- explicit handling for ready/cancelled transitions
- careful separation between active-match truth and list-backed replay truth

Do not treat replay as normal challenge-list behavior.

## Debugging Order

When a remote realtime bug happens, debug in this order:

1. did the realtime event arrive
2. was it relevant
3. what refetch path ran
4. was it skipped, throttled, or forced
5. did authoritative data actually change
6. did arrays or flow match update from that data
7. did UI render from the updated authoritative state
8. did navigation wait for authoritative confirmation

## Use Supporting References

Consult supporting docs as needed:

- `fetch-vs-load-vs-force-reload.md` for choosing the right refetch path
- `in-remote-flow-rules.md` for default skip behavior and override cases
- `replay-realtime-rules.md` for replay-specific exceptions
- `realtime-navigation-rules.md` for safe navigation after realtime changes
- `realtime-debug-order.md` for diagnosis sequence
- `realtime-logging-rules.md` for decision-level logging
- `realtime-as-trigger-not-truth.md` for the core subscription model

## Bottom Line

For remote matches, realtime is a wake-up signal.

It may tell the client to look.  
It does not tell the client what is true.