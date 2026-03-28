---
name: remote-match-lifecycle
description: app-specific remote match lifecycle rules for dart freak. use when working on remote challenge flow, sent/pending/ready card behavior, accept/decline/cancel logic, ready-to-lobby transitions, lobby/countdown/gameplay progression, challenger-vs-receiver behavior, replay lifecycle, expiry handling, terminal remote states, or any bug where a remote match moves to the wrong stage, does not move stage, or shows the wrong UI for one side. do not use for local match flow, generic realtime architecture, or generic navigation work unless the task is specifically about remote match lifecycle behavior.
---

# Remote Match Lifecycle

Use this skill when changing or debugging the **feature workflow** of remote matches in Dart Freak.

This is not the general server-authoritative skill and not the general realtime skill.  
This skill explains the actual remote match lifecycle: what stages exist, what each player should see, what actions are allowed, and what transitions are supposed to happen next.

## Scope

Apply this skill when working on:
- remote challenge creation
- sent / pending / ready card behavior
- accept / decline / cancel behavior
- ready state behavior
- lobby entry and eligibility
- countdown/start progression
- gameplay entry
- challenger vs receiver asymmetry
- replay lifecycle behavior
- expiry and terminal handling
- authoritative-state-to-UI mapping
- bugs where the lifecycle and the visible UI disagree

Do not use this skill for:
- local match lifecycle
- pure voice/WebRTC implementation details unless they change lifecycle progression
- generic navigation work unless the route bug is really caused by lifecycle truth
- generic realtime handling unless the problem is specifically a remote lifecycle transition problem
- general Supabase architecture questions that are not about remote match progression

## Core Model

Remote matches in Dart Freak use a **database-authoritative lifecycle with client-derived presentation**.

The key distinction is:

- authoritative match fields decide what stage the match is really in
- the client derives what card, overlay, or screen each player should see from that truth
- challenger and receiver may see different UI for the same authoritative match state
- replay reuses most of the same lifecycle, but has extra replay-specific behavior

That means:
- do not reason from the card first
- reason from authoritative stage first
- then map that stage to player-specific UI

## Core Rules

### 1. Lifecycle truth is authoritative
Remote lifecycle logic must be based on authoritative remote match state, not on optimistic UI or card appearance.

### 2. UI is derived
Card states like sent/pending/ready are presentation outcomes, not the lifecycle source of truth.

### 3. Challenger and receiver are intentionally asymmetric
The same match state may produce different visible UI and different allowed actions for challenger vs receiver.

### 4. Remote lifecycle is staged
Remote matches do not jump directly from “accepted” to gameplay.  
They progress through challenge state, ready state, lobby state, countdown/start gating, then gameplay.

### 5. Replay is not a separate universe
Replay usually follows the same broad lifecycle model as a normal remote match, but with replay-specific creation and entry behavior.

### 6. Terminal handling matters
Cancelled, declined, expired, completed, and removed-from-actionable-UI states must be reasoned about carefully.  
Do not assume “not visible” means “same terminal reason.”

## How To Reason About a Remote Match Change

When changing lifecycle code, answer these questions in order:

1. what authoritative stage is the match really in?
2. what player role is viewing it?
3. what UI should that role see for that stage?
4. what actions should be allowed from that stage?
5. what exact transition is supposed to happen next?
6. what authoritative field or server-owned step proves that transition really happened?

If those answers are vague, do not change the logic yet.

## Important Boundaries

This skill works together with other skills:

- use `supabase-patterns` for server-authoritative write rules, edge function rules, and remote field discipline
- use `realtime-patterns` for subscription/refetch behavior and stale-array problems
- use `swiftui-navigation` for push/pop ownership, stale instance protection, and route guards

This skill answers a different question:

**what stage should the remote match be in, and what should each side see/do at that stage?**

## Use Supporting References

Use the supporting docs as needed:

- `remote-match-overview.md` for the mental model
- `lifecycle-stages.md` for the canonical stage model
- `challenger-vs-receiver-rules.md` for role asymmetry
- `create-accept-decline-cancel.md` for challenge-card stage behavior
- `ready-lobby-gameplay-flow.md` for ready → lobby → gameplay progression
- `replay-lifecycle-rules.md` for replay-specific lifecycle behavior
- `expiry-and-terminal-states.md` for terminal/expiry handling
- `authoritative-state-and-ui-mapping.md` for stage-to-UI mapping
- `lifecycle-debug-order.md` for debugging sequence

## What This Skill Is Mainly Preventing

This skill is mainly here to stop these mistakes:

- treating card presentation as the lifecycle source of truth
- forgetting challenger/receiver asymmetry
- collapsing ready/lobby/countdown/gameplay into one blurry state
- handling replay like ordinary first-time flow without replay-specific checks
- confusing cancellation, decline, expiry, and completion
- changing UI behavior without checking the authoritative stage model first
- fixing a lifecycle bug at the wrong layer because the visible symptom was misleading

## Standard Working Pattern

For remote lifecycle work, use this pattern:

1. identify the authoritative lifecycle stage
2. identify the viewing player’s role
3. identify the expected UI and allowed actions for that role/stage
4. identify the exact server-owned transition that should happen next
5. validate that the client is reflecting the lifecycle correctly rather than inventing its own meaning

## Bottom Line

In Dart Freak, remote match behavior should always be reasoned about as:

**authoritative stage → player role → allowed UI/actions → next valid transition**

Not the other way around.