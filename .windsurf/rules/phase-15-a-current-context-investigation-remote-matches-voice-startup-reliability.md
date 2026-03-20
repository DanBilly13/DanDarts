---
trigger: always_on
---


# phase-15-a-current-context-investigation-remote-matches—voice-startup-reliability

## Project Overview
This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**.

A remote match is a **live, synchronous, server-authoritative 1v1 game** backed by Supabase, with realtime updates, edge functions, and push-driven entry into the remote flow.

The intended lifecycle remains:

**Pending / Sent → Ready → Lobby → In Progress → Completed / Expired / Cancelled**

Voice chat is attached to that remote flow and should behave like the rest of the system:
- deterministic
- state-driven
- resilient to timing variance
- cleaned up fully when flow exits

The original rebuild principles still apply and remain important:

**Lifecycle → State → Writes → Realtime → Hardening → Edge Cases**

However, based on what has now been observed, this phase must begin with a stricter investigation step before making more bootstrap changes.

---

# Why Phase 15 Needs an Investigation Sub-Phase First

The original Phase 15 framing focused on **voice startup reliability** and assumed the main issue was a signalling/bootstrap race.

That may still be partly true.

But newer evidence suggests the real problem may be broader:

> Voice startup may be failing because the surrounding remote-flow lifecycle is not always starting from a truly clean client state.

A particularly important clue is:

> Voice appears to work reliably after a **clean build**, but not always after repeated normal runs.

That is a strong signal that the app may be suffering from one or more of the following:
- stale in-memory state surviving between matches
- incomplete cleanup after flow exit
- duplicate subscriptions / observers / timers
- duplicated or recreated view/view-model/service ownership
- race-prone interaction between remote flow state and voice bootstrap state

So before doing more voice-specific fixes, we need to answer a more fundamental question:

> **What exactly is being reset by a clean build that normal app usage is failing to reset?**

That is the purpose of **Phase 15-A**.

---

# What We Still Believe Is True

A lot of the Remote Matches system is working.

Healthy runs show that:
- challenge creation works
- receiver accept works
- lobby entry works
- match start works
- gameplay can progress correctly
- server-authoritative scoring and turn switching work
- end-game flow works
- voice can succeed end-to-end in at least some runs

Healthy voice runs have already shown:
- audio session setup succeeds
- signalling channel subscription succeeds
- offer / answer can complete
- ICE candidates exchange correctly
- remote audio can connect
- WebRTC can reach connected state

So the problem still does **not** look like:

> “Voice is fundamentally broken.”

The problem now looks more like:

> “Voice startup reliability may be a symptom of unstable lifecycle / cleanup / ownership underneath the voice layer.”

---

# Updated Working Theory

## The current issue may not be only a handshake problem

The earlier theory was:
- `voice_ready` timing is race-prone
- `voice_request_offer` seems more reliable
- challenger should probably only create the offer from one canonical trigger

That is still a valid theory.

But it may not be the whole story.

The newer concern is:

> The system may be entering Phase 15 with a contaminated runtime state, and voice bootstrap is simply the first place that instability becomes visible.

Examples of the kinds of contamination we now need to investigate:
- old signalling channels still alive
- old peer/session state still retained
- old timers or async tasks still running
- stale dedupe or message-processing state
- lingering “in flow” / “entering flow” / “processing” / “freeze” state
- repeated subscriptions causing duplicated events
- multiple UI instances or lifecycle owners reacting to the same match

If any of that is true, then further voice bootstrap tweaks alone may just dig the project into a deeper hole.

---

# Core Question for Phase 15-A

## What survives between runs that should not survive?

This sub-phase is an investigation phase.

It exists to answer these questions before more implementation changes are made:

### 1. Why does voice often work after a clean build?
We need to identify what that clean build is resetting.

### 2. Is the failure caused by stale voice state, stale remote-flow state, or both?
We need to know whether the issue is isolated to `VoiceChatService` or is caused by contamination in the wider remote match lifecycle.

### 3. Are duplicate owners still present somewhere?
Even after previous hardening, we need to prove whether there is still more than one active owner for parts of the remote flow.

### 4. Are subscriptions / timers / observers being fully cleaned up?
If not, the next run may be inheriting old behavior.

### 5. Are we fixing the wrong layer?
If the real root cause is lifecycle contamination, then further signalling tweaks alone are the wrong move.

---

# What Phase 15-A Must Establish

## 1. Whether clean build success points to stale client state
We need to compare behavior across:
- clean build
- app relaunch without clean build
- force-quit and reopen
- repeated match attempts in one installed session
- manual in-app reset of remote/voice state, if available

### Goal
Determine whether the reliability improvement comes from resetting client state rather than from any true protocol fix.

---

## 2. Whether there are duplicate lifecycle owners
We need to prove or disprove the following for a single match attempt:
- one active remote flow owner
- one active voice session owner
- one signalling channel subscription per match/session
- one gameplay view model per active match
- one authoritative fetch/update pipeline per match

### Goal
Confirm that one match attempt produces one clean execution path.

---

## 3. Whether cleanup is genuinely complete on exit
When a match exits or transitions, we need to verify cleanup of:
- voice session state
- peer connection state
- signalling channel subscription
- timers
- delayed tasks
- flow latches
- processing markers
- UI freeze state
- active match references
- any cached message/session identifiers

### Goal
Prove that the next run starts from zero rather than from leftovers.

---

## 4. Whether voice bootstrap is still race-prone after state is clean
Only after the above is understood should we revisit the handshake itself.

At that point we can answer:
- is `voice_request_offer` still the correct canonical trigger?
- is `voice_ready` only informational?
- are out-of-order or duplicate messages still a problem in an otherwise clean run?

### Goal
Separate true bootstrap design issues from contaminated-state effects.

---

# Updated Problem Statement

## The problem is now framed as an investigation, not just a fix

The old framing was:

> Make voice bootstrap deterministic and remove signalling races.

The updated Phase 15-A framing is:

> Investigate why voice startup becomes unreliable across repeated runs, with special focus on stale client state, incomplete cleanup, duplicate lifecycle ownership, and the clean-build clue.

This means the question is no longer just:
- “what should trigger offer creation?”

It is now also:
- “what old state is still alive when the next run starts?”
- “are multiple parts of the app still trying to own the same match lifecycle?”
- “is voice unreliability actually downstream of lifecycle contamination?”

---

# Investigation Hypotheses

## Hypothesis A — stale voice state survives between runs
Possible examples:
- old session IDs retained
- stale signalling channel still attached
- dedupe/handshake flags not reset
- peer connection state not fully torn down
- late callbacks from prior sessions affecting new ones

### What would support this hypothesis
- clean build fixes the issue
- manual voice reset also fixes it
- logs show unexpected voice events arriving from older context

---

## Hypothesis B — stale remote-flow state survives between runs
Possible examples:
- `isInRemoteFlow` / `isEnteringFlow` / nav-in-flight state persisting too long
- active match references not fully cleared
- delayed fetch/load work still running after flow exit
- freeze/processing/accept state surviving beyond intended scope

### What would support this hypothesis
- a fresh app launch improves behavior without code changes
- next-run issues correlate with previous-run cleanup paths
- logs show old flow tasks/subscriptions still firing

---

## Hypothesis C — duplicate owners still exist in some paths
Possible examples:
- repeated view/view-model initialization for same match
- multiple listeners for same broadcast event
- repeated fetch/update pipelines for same active match
- duplicate card/UI layers still reacting during in-flow states

### What would support this hypothesis
- multiple init/deinit imbalances
- multiple event handlers reacting to one message
- duplicate lifecycle logs for one match attempt

---

## Hypothesis D — bootstrap protocol still has a real race even in clean state
This remains possible.

Possible examples:
- readiness sent before peer is listening
- canonical offer trigger still ambiguous
- duplicate or out-of-order signalling still advances state incorrectly

### What would support this hypothesis
- failures still occur even after confirmed clean state and clean ownership
- message-order logs still show nondeterministic handshake progression

---

# Recommended Phase 15-A Investigation Plan

## Step 1 — Freeze implementation changes
Do not add more workaround logic until the investigation has been completed.

### Deliverable
A stable investigation branch/state where observations are not being confused by new speculative fixes.

---

## Step 2 — Instrument identity and ownership more aggressively
Add or verify logs for:
- voice session instance IDs
- signalling channel instance IDs
- peer connection instance IDs
- lobby view instance IDs
- gameplay view instance IDs
- gameplay VM instance IDs
- remote flow enter/exit ownership
- subscription attach/detach counts
- timer/task creation and cancellation

### Deliverable
A single-run trace showing exactly how many owners/instances exist.

---

## Step 3 — Run comparative startup tests
Run the same scenario under several conditions:

### Test A — Clean build
Baseline healthy run.

### Test B — Normal rerun without clean build
See whether reliability drops.

### Test C — Force-quit and reopen
Test whether app relaunch alone restores reliability.

### Test D — Manual in-app reset then rerun
If possible, explicitly clear remote + voice state and compare to clean build behavior.

### Deliverable
A matrix showing which reset level restores reliability.

---

## Step 4 — Audit cleanup on flow exit
For one full successful match and one aborted/interrupted match, verify cleanup of:
- signalling unsubscribe
- peer connection close
- audio session state reset
- flowMatch clear
- activeMatch clear/update correctness
- timers cancelled
- delayed tasks cancelled or ignored
- processing/freeze/latch state cleared
- dedupe/bootstrap state cleared

### Deliverable
A definitive list of what is and is not reset after exit.

---

## Step 5 — Decide whether Phase 15 proper is really a voice-only fix
After investigation, choose one of these routes:

### Route A — Mostly stale-state / lifecycle problem
Rewrite the next phase around cleanup, ownership, and deterministic reset.

### Route B — Mostly bootstrap protocol problem
Return to the original plan and harden the signalling path.

### Route C — Mixed problem
Do a small cleanup/ownership hardening pass first, then do the canonical bootstrap pass.

### Deliverable
A justified decision on the real next implementation phase.

---

# What We Are Explicitly Not Assuming Yet

Until Phase 15-A is complete, we should avoid assuming that:
- `voice_request_offer` alone is the full answer
- the fix is only inside `VoiceChatService.swift`
- the current issue is purely signalling timing
- repeated logs are harmless
- clean-build success means the protocol is solved

The investigation exists specifically to avoid those assumptions.

---

# File Areas Most Likely Involved in Phase 15-A

## `VoiceChatService.swift`
Investigation targets:
- session lifecycle
- bootstrap state reset
- signalling subscription ownership
- teardown completeness

## signalling / broadcast handling layer
Investigation targets:
- duplicate listeners
- stale message handling
- dedupe state reset
- session/match validation

## `RemoteMatchService.swift`
Investigation targets:
- flow enter/exit cleanup
- active match ownership
- load/fetch overlap
- lingering in-flow state

## lobby / gameplay call sites
Investigation targets:
- duplicate startup paths
- repeated initialization
- task/timer cleanup
- view lifecycle correctness

---

# Coding Rules for Phase 15-A

## Rule 1 — Investigate before redesigning again
Do not add more structural fixes until the evidence clearly identifies the layer at fault.

## Rule 2 — Prove ownership counts
For any suspected duplicate behavior, log enough identity data to prove whether it is one owner or many.

## Rule 3 — Treat clean-build success as a clue, not as proof of a fix
A clean build that “makes it work” is evidence of reset behavior, not evidence that the system is correct.

## Rule 4 — Prefer explicit reset evidence over intuition
We need to know exactly what is cleared on exit and what is not.

## Rule 5 — Keep the original remote-matches rebuild philosophy
Lifecycle determinism still comes before harder realtime and voice behavior.

---

# Acceptance Criteria for Phase 15-A

## Investigation completeness
- We can explain why clean build improves reliability, or prove that it does not.
- We know whether stale voice state, stale remote-flow state, duplicate ownership, or bootstrap timing is the main issue.

## Ownership clarity
- We can prove how many active instances/subscriptions exist in a single run.
- We can prove whether duplicate owners are present or absent.

## Cleanup clarity
- We can list what is reset correctly on exit.
- We can list what is not reset correctly on exit.

## Decision readiness
- We can clearly justify the next implementation phase.
- We are no longer guessing whether the issue is “voice only” or “lifecycle plus voice.”

---

# Practical Test Scenarios for Phase 15-A

## Scenario A — Clean build baseline
- Clean build
- Start fresh remote match
- Observe voice startup path
- Capture full lifecycle/ownership logs

## Scenario B — Repeated match without clean build
- Complete or exit a match
- Start another without clean build
- Compare behavior against baseline

## Scenario C — Force-quit/relaunch rerun
- Repeat same test after relaunch
- Compare whether reliability returns

## Scenario D — Manual reset comparison
- Trigger explicit voice/flow cleanup if possible
- Compare with clean-build behavior

## Scenario E — Exit-path audit
- Successful completion path
- Abort/interrupted path
- Confirm all state cleanup steps

---

# Summary for W
Phase 15-A is an **investigation phase** that sits in front of the original voice startup reliability work.

The original concern was valid:
- voice startup appears timing-sensitive
- `voice_request_offer` looks more reliable than loosely coordinated readiness timing

But newer evidence adds a bigger concern:

> If voice only becomes flaky after repeated normal runs, and becomes reliable again after a clean build, then stale client state or incomplete cleanup may be the real problem underneath the signalling symptoms.

So Phase 15-A is about answering this first:

1. what is being reset by a clean build?
2. what stale state survives between runs?
3. are duplicate owners/subscriptions still present?
4. is the real issue lifecycle contamination, bootstrap timing, or both?

Only once those answers are known should the next fix phase be defined.

The desired end state of Phase 15-A is simple:

> We stop guessing which layer is broken, and we prove whether the next fix should target cleanup/ownership, signalling bootstrap, or both.
