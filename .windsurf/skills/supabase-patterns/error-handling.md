> Supporting reference for: supabase-patterns  
> Apply when: handling errors in remote match flows across Edge Functions, RPC calls, realtime-triggered refetches, and client UI  
> Do not apply to: local matches or local-only game logic

# Error Handling

## Purpose

Remote match error handling must protect correctness first, UX second.

The goal is:
- do not corrupt authoritative state
- do not fake success
- do not leave the client stuck in a false local state
- return enough information to diagnose what failed
- allow safe retry where appropriate

---

## Core Rule

If the server did not authoritatively change state, do not report success.

If the client does not know whether the state changed, it must refetch.

---

## Error Handling Priorities

Use this order:

1. preserve authoritative correctness
2. distinguish real failure from benign duplicate/race loss
3. return explicit outcome
4. refetch authoritative state when needed
5. show calm, actionable UI feedback

Do not optimize for “clean UI” by hiding real failures.

---

## Error Categories

Think in these categories:

### 1. Validation / blocked state
The request was understood, but the action is not allowed now.

Examples:
- caller is not a participant
- match is not in the required status
- prerequisites are missing
- countdown already started
- match already started

These should usually return a structured blocked/already-done result, not a vague internal error.

### 2. Idempotent repeat
The exact intended state is already true.

Examples:
- voice already confirmed
- lobby already entered
- countdown already started by another caller

These should usually return benign success or already-done.

### 3. Race condition / lost write
Another concurrent caller changed state first.

Examples:
- guarded update affects 0 rows because another path won
- status changed between fetch and write

These should usually return benign already-started / already-updated if the resulting state is acceptable.

### 4. Real server failure
The function could not complete due to an actual backend problem.

Examples:
- query error
- permission failure
- malformed data
- missing required row unexpectedly
- write error
- timeout / network failure between layers

These should be logged clearly and surfaced as failure.

### 5. Client sync uncertainty
The server may have changed state, but the client is not sure yet.

Examples:
- request succeeded but UI state is stale
- realtime arrived but refetch was skipped
- request timed out client-side after server may have completed

These require authoritative refetch, not guessing.

---

## Edge Function Rules

### Do
- validate auth first
- validate request shape
- fetch fresh authoritative state
- use guarded writes where needed
- check affected row count
- return explicit result type
- log the reason for blocked / already-done / failed

### Do not
- return success after 0-row update unless it is explicitly treated as idempotent or race-safe
- swallow errors and continue
- return fake success because “the UI expects it”
- blur blocked state and real failure together

---

## Affected Row Count Rule

A write with no error is not automatically success.

Interpret it deliberately:

### Good
- `0 rows changed` + guarded update + another caller already completed transition  
  → benign already-started / already-done

### Good
- `0 rows changed` + expected authoritative change that did not happen  
  → failure or blocked result

### Bad
- `0 rows changed`  
  → return success without explanation

---

## Idempotency Rule

Safe repeats should not become errors.

Examples:
- user retries `confirm-voice-ready`
- lobby-enter call repeats
- countdown start request re-runs after another trigger already started it

Preferred behavior:
- return success with explicit already-done semantics
- do not create duplicate state transitions
- do not punish harmless retries

But:
- idempotency is not a license to ignore incorrect state
- only return idempotent success when the intended authoritative state is already true

---

## Race Condition Rule

Concurrency is expected in remote flows.

Handle it explicitly:
- use guarded updates
- expect duplicate triggers
- interpret race loss based on authoritative result

Good:
- “another caller already started countdown”
- “match already transitioned”
- “voice flag was already set”

Bad:
- generic 500 error for a benign race
- repeated retries that create more churn
- client inventing fallback state locally

---

## Client-Side Rules

### Client may
- show loading state
- optimistically update rollback-safe UI state
- show a blocked message
- retry safe actions
- refetch after uncertain outcomes

### Client must not
- assume write success without confirmation
- keep optimistic state if the write failed
- invent authoritative remote state
- hide failures that require refetch or rollback

---

## Rollback Rule

If the client uses optimistic UI, it must be reversible.

Good:
- mark a card as cancelling
- if request fails, restore the card
- show error
- allow retry

Bad:
- remove the card permanently before authoritative confirmation
- never restore on failure
- leave local flags stuck in “processing”

---

## Refetch Rule After Errors

Refetch when:
- the client is unsure whether the write succeeded
- a request times out client-side
- realtime and UI disagree
- race loss may have still resulted in acceptable authoritative state
- blocked result might have been caused by stale local assumptions

Do not refetch blindly after every single error.
Refetch when it clarifies authoritative truth.

---

## Response Shape Rule

Error and non-success responses should still be structured.

Prefer fields like:
- `success`
- `error`
- `reason`
- `already_started`
- `already_done`
- `waiting_for`
- `blockers`

Examples:
- `reason: "already_started"`
- `waiting_for: "voice"`
- `blockers: ["receiver_view_entered_false"]`

Do not force the client to parse human prose to understand what happened.

---

## Logging Rule

Log the decision, not just the crash.

Useful error logs include:
- function name
- match id
- user id or caller role when relevant
- authoritative inputs
- blockers
- guarded write result
- exact database error message
- whether the result was failure, blocked, or benign race/idempotent

Bad:
- “unexpected error”
- “update failed”
- no match id
- no decision context

---

## UI Messaging Rule

User-facing messages should be:
- calm
- short
- actionable
- honest

Good:
- “Failed to cancel challenge. Please try again.”
- “Match already started.”
- “Waiting for other player.”
- “Voice unavailable.”

Bad:
- raw database errors
- technical backend jargon
- scary messages for benign race conditions

---

## Retry Rule

Retry only when the action is safe to retry.

Usually safe:
- confirming voice ready
- confirming lobby entered
- refetching match/list state
- cancelling a sent challenge if server says still cancellable

Usually not safe without fresh state:
- starting countdown manually from client
- starting match without refetch
- replay/navigation decisions based on old UI state

If the action depends on current match status, always refetch before retry.

---

## What Good Looks Like

### Good: confirm voice ready
- if already set → return idempotent success
- if write succeeds → continue
- if countdown race lost → return benign already-started
- if real write error → return failure and log it

### Good: cancel sent challenge
- optimistic “cancelling” UI
- server validates cancellable status
- success → fade out
- failure → restore UI and show retryable message

### Good: replay cancellation on receiver
- realtime arrives
- arrays refetch
- overlay sees authoritative removal/cancelled state
- dismisses cleanly
- no fake local guesswork

---

## What Bad Looks Like

### Bad: fake success
- edge function returns success
- no rows changed
- authoritative state stayed the same

### Bad: swallowed backend failure
- request errors
- UI silently continues as if state changed

### Bad: stale local truth
- request failed
- local card removed anyway
- no rollback
- no refetch

### Bad: generic 500 for benign race
- countdown already started by another caller
- function throws instead of returning already-started

---

## Debug Order for Error Problems

When something “failed,” debug in this order:

1. did the request reach the server
2. did auth pass
3. what fresh state was read
4. what validation/blockers were computed
5. did the guarded write run
6. how many rows changed
7. was the result failure, blocked, idempotent, or race-safe
8. did the client refetch / rollback correctly

Do not start with UI rendering until the authoritative result is known.

---

## Error Handling for Local vs Remote

These rules are primarily for remote match flows.

For local matches:
- the device is usually the only authority
- realtime/race/idempotent server patterns usually do not apply the same way

Do not blindly apply remote server-authoritative handling to local-only game logic.

---

## Bottom Line

A remote flow error is not just “something went wrong.”  
It is one of four things: blocked, already done, race lost, or truly failed.  
Handle those differently, or the app will lie to itself.