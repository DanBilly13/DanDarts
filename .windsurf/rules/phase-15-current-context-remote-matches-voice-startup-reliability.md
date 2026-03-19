---
trigger: always_on
---

# phase-15-current-context-remote-matches—voice-startup-reliability

## Project Overview
This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**.

A remote match is a **live, synchronous, server-authoritative 1v1 game** backed by Supabase, with realtime updates, edge functions, and push-driven entry into the remote flow.

The feature is designed around a deterministic lifecycle:

**Pending / Sent → Ready → Lobby → In Progress → Completed / Expired / Cancelled**

Voice chat is attached to that remote flow and should behave like the rest of the system:
- deterministic
- state-driven
- resilient to timing variance
- cleaned up when flow exits

The original rebuild guidance still applies:

**Lifecycle → State → Writes → Realtime → Hardening → Edge Cases**

That same principle now needs to be applied more explicitly to **voice signalling bootstrap**.

---

# Where the Project Stands Before Phase 15

A large amount of Remote Matches is already working:
- Challenges can be created
- Receiver can accept
- Match can move through lobby into gameplay
- Gameplay scoring and turn switching work off authoritative server state
- End game flow works
- Abort handling is now being hardened as a proper terminal-state flow event
- Voice session setup, signalling, and WebRTC can all work successfully in healthy runs

From recent logs, voice is **not fundamentally broken**:
- audio session setup succeeds
- routing to speaker succeeds
- signalling channels subscribe successfully
- offer / answer / ICE / remote audio track all work in good runs
- WebRTC reaches `ICE connected` in successful sessions

So the current issue is not “voice does not work at all.”

The current issue is **intermittent voice startup reliability**.

---

# Phase 15 Goal
## Make voice bootstrap deterministic and remove timing-sensitive signalling races

The main goal of Phase 15 is to stabilize the voice connection startup path in remote lobby/gameplay.

In plain terms:

> Voice should not depend on lucky message timing to connect.

If both players are in a valid voice-eligible remote flow, the signalling handshake should converge consistently.

If a handshake attempt becomes invalid or stalls, it should fail cleanly and predictably rather than remaining half-started.

---

# Current Problem We Are Fixing
## Voice connection startup is timing-sensitive and intermittently stalls

Recent logs show two important patterns:

### Healthy run
The full voice flow completes:
- session starts
- signalling subscribes
- offer / answer exchange completes
- ICE candidates are exchanged
- remote audio track is received
- `ICE connected` is reached

### Failing / flaky run
The flow can stall early:
- local voice session starts
- signalling channel subscribes
- one side sends `voice_ready`
- challenger waits for receiver readiness
- handshake does not always progress deterministically

In at least one successful recovery run, the connection only progressed after:
- receiver sent `voice_request_offer`
- challenger treated that as the actual trigger
- challenger created and sent offer
- answer and ICE then completed successfully

That strongly suggests the current bootstrap logic is too timing-sensitive and sometimes relies on fallback behavior to recover.

---

# Root Cause
## Voice startup currently depends on overlapping signalling paths instead of one deterministic bootstrap sequence

The likely root issue is:

> Voice negotiation can currently advance from multiple loosely-coordinated readiness messages, and the system depends too much on both sides being subscribed and listening at exactly the right moment.

Examples from current behavior:
- `voice_ready` exists as a readiness signal
- challenger may wait for receiver readiness before creating an offer
- `voice_request_offer` exists as a later recovery trigger
- successful runs suggest the fallback trigger may be more reliable than the original implicit readiness sequencing

This creates a race-prone bootstrap path:
- one side may send readiness before the other is fully listening
- the normal offer trigger may not happen
- fallback may rescue some runs, but not all
- the handshake is therefore nondeterministic

---

# What Phase 15 Must Accomplish

## 1. Standardize one handshake trigger
We need one clear, official trigger for offer creation.

The most promising current candidate is:

- both sides establish signalling/session state
- receiver explicitly sends `voice_request_offer`
- challenger creates offer only from that trigger

That appears more deterministic than relying on `voice_ready` timing alone.

### Goal
Remove ambiguity about what event actually causes the challenger to generate the offer.

---

## 2. Add hard guards around voice bootstrap state
The voice layer should not progress just because one message arrived.

It should verify things like:
- active session exists
- match ID matches active flow
- session ID is valid/current
- peer identity is correct
- signalling channel subscription is active
- current bootstrap state allows the next step

### Goal
Stop accidental progression from stale, duplicate, or out-of-order signalling messages.

---

## 3. Improve logs so the exact bootstrap state is visible
We need clearer voice-specific lifecycle logs, similar in spirit to the stronger flow logs added in earlier phases.

The logs should make it easy to answer:
- did session creation succeed?
- did channel subscription succeed?
- which side is waiting for what?
- what exact trigger caused offer creation?
- was a message ignored because it was stale / duplicate / unexpected?
- did the system recover through fallback or through the primary path?

### Goal
Make it obvious why a run succeeded or stalled.

---

## 4. Retest across several runs instead of trusting one success
Because this looks timing-sensitive, one good run does not prove the problem is solved.

We need repeated runs to confirm the handshake has become deterministic.

### Goal
Prove the fix is reliable across multiple attempts, not just occasionally successful.

---

# Recommended Phase 15 Implementation Plan

## Step 1 — Trace the current voice bootstrap sequence
Before changing logic, confirm the actual current sequence for both roles:
- voice session creation
- signalling subscription
- readiness messages
- offer trigger
- answer path
- ICE exchange

Pay special attention to:
- challenger path
- receiver path
- whether `voice_request_offer` is acting as fallback or as the real reliable trigger

### Deliverable
A confirmed “current handshake sequence” for both challenger and receiver.

---

## Step 2 — Choose one official offer-creation trigger
Stabilize the flow by defining one canonical rule for when the challenger creates an offer.

Recommended direction:
- receiver explicitly requests the offer
- challenger creates offer only on that request
- any earlier readiness messaging becomes either informational or unnecessary

### Deliverable
A single deterministic handshake rule that both roles follow.

---

## Step 3 — Add hard bootstrap guards
Before acting on inbound signalling messages, check:
- active session still exists
- current match is still voice-eligible
- sender/recipient are valid
- session ID is current
- current bootstrap state allows the event

This should prevent out-of-order, duplicate, or stale messages from changing flow state incorrectly.

### Deliverable
Explicit guardrails around signalling progression.

---

## Step 4 — Add stronger voice lifecycle logging
Add logs for:
- session start
- subscription confirmed
- waiting state
- request-offer sent/received
- offer created/sent
- answer received/applied
- ICE state progression
- ignored message reasons
- timeout / reset reasons

### Deliverable
A readable voice bootstrap trace that explains every run.

---

## Step 5 — Retest multiple runs
Run repeated tests with the same two users and same general flow.

At minimum verify:
- healthy lobby entry
- voice start on both roles
- repeated successful negotiation across several fresh matches
- no dependence on “lucky” timing

### Deliverable
Evidence that the handshake is stable across repeated runs.

---

# File Areas Most Likely to Change

## `VoiceChatService.swift`
Most likely changes:
- bootstrap sequencing
- canonical offer trigger behavior
- stricter signalling guards
- startup/reset logging

## signalling / broadcast handling layer
Most likely changes:
- validation rules for inbound voice messages
- dedupe / stale-message rejection
- role-specific trigger behavior

## possibly lobby voice startup call sites
Only if needed to ensure:
- session starts at the correct moment
- signalling subscription is definitely active before first required message

---

# Coding Rules for Phase 15

## Rule 1 — One deterministic bootstrap path
Do not keep multiple loosely competing startup paths unless one is clearly primary and the others are clearly guarded.

## Rule 2 — Messages are triggers, not proof that state is valid
A message arriving does not by itself mean the voice layer should advance.

## Rule 3 — Guard before progressing
Every inbound signalling step should validate:
- active session
- match/session identity
- expected sender
- allowed current state

## Rule 4 — Stabilize first, optimize second
Do not over-engineer a full voice state machine unless the smaller deterministic fix is insufficient.

## Rule 5 — Prefer minimal structural clarity over more fallback hacks
The goal is not to add more rescue behavior.
The goal is to make the primary path reliable enough that fallback is rarely or never needed.

---

# Acceptance Criteria for Phase 15

## Core correctness
- Voice bootstrap uses one clear offer trigger
- Challenger does not depend on ambiguous readiness timing
- Receiver and challenger converge reliably across repeated runs

## Reliability
- Voice connects consistently across several fresh match attempts
- Successful runs do not depend on lucky timing
- Stalled runs, if any, are diagnosable from logs

## Guarding
- Stale / duplicate / unexpected signalling messages do not incorrectly advance bootstrap state
- Match/session identity is checked before applying signalling events

## Diagnostics
- Logs clearly show:
  - who is waiting
  - which trigger advanced the handshake
  - why a message was accepted or ignored
  - whether the run followed the primary path or a recovery path

---

# Practical Test Scenarios

## Scenario A — Healthy fresh connection
- Start a new remote match
- Enter lobby on both devices
- Voice bootstrap completes cleanly
- Offer/answer/ICE connect successfully

## Scenario B — Repeated fresh matches
- Run several new matches in a row
- Verify voice startup remains stable across repeated attempts

## Scenario C — Delayed peer readiness
- One side arrives slightly later
- Handshake still converges deterministically
- No silent stall waiting forever for an implicit readiness condition

## Scenario D — Out-of-order / duplicate signalling
- Verify unexpected or repeated messages do not break session state
- Logs clearly show they were ignored or handled safely

## Scenario E — Match exit / abort during active voice
- Match becomes terminal
- voice session shuts down cleanly
- no stale signalling continues after flow exit

---

# Summary for W
Phase 15 is a **voice bootstrap hardening phase**.

The issue is not that voice is fundamentally broken.
The issue is that startup appears **timing-sensitive and intermittently nondeterministic**, with at least some successful runs relying on `voice_request_offer` to rescue or complete the handshake.

So the plan is:
1. standardize one handshake trigger
2. add a few hard guards
3. add better logs
4. retest several runs

The desired end state is simple:

> Voice connection startup should converge reliably from one deterministic handshake path rather than depending on timing luck.
