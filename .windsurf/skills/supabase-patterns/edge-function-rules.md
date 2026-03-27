> Supporting reference for: supabase-patterns  
> Apply when: creating or editing Supabase Edge Functions for remote match flows  
> Do not apply to: local matches or client-side SwiftUI logic

# Edge Function Rules

## Purpose

Edge Functions are the authoritative write layer for remote match flows.

Use an Edge Function when logic needs to:
- validate the authenticated user
- read fresh server state before deciding
- write authoritative match state
- enforce role, status, or lifecycle rules
- handle idempotency or race conditions safely

Do not move this logic into SwiftUI views or client-side services.

---

## Deployment Note

Edge Functions are deployed by pasting directly into the Supabase dashboard editor.
Do not suggest CLI deployment steps or `supabase functions deploy` commands.


## Core Rule

The Edge Function must decide.

The client may request an action.
The Edge Function must:
1. authenticate
2. fetch fresh authoritative state
3. validate prerequisites
4. perform the write safely
5. return the result

---

## Standard Edge Function Flow

For remote match operations, use this order:

1. authenticate user
2. parse and validate request body
3. fetch fresh authoritative row(s)
4. determine caller role
5. validate match status and prerequisites
6. perform guarded/idempotent write
7. verify the outcome
8. return clear structured response
9. log the authoritative decision path

Do not skip the fresh fetch before the decision.

---

## What the Function Must Validate

Before writing, validate as needed:

- caller is authenticated
- caller is a participant in the match
- match exists
- match is in the expected status
- caller role matches the requested action
- required authoritative fields are present
- action is still allowed at this point in the lifecycle

Examples:
- only the receiver can accept a challenge
- only a participant can enter lobby
- countdown can only start from valid lobby state
- match start can only happen after countdown is active

---

## Fresh Read Rule

Always evaluate from fresh database state.

Do:
- fetch the current match row after any important write if a later decision depends on the updated state

Do not:
- decide based only on stale state fetched before the write
- assume the update is visible unless you re-read or use guarded write semantics correctly

Bad:
- fetch row
- update voice_ready
- decide countdown using old pre-update data

Good:
- fetch row
- update voice_ready
- fetch fresh row again
- decide countdown from the fresh row

---

## Guarded Write Rule

Use guarded writes for state transitions that must only happen once.

Pattern:
- update only where the row is still in the expected state
- check affected row count
- if zero rows changed, treat as benign race loss or invalid state depending on context

Examples:
- start countdown only where `lobby_countdown_started_at IS NULL`
- start match only where status is still `lobby`
- cancel only where status is still cancellable

---

## Idempotency Rule

If an action may be retried, make it idempotent where appropriate.

Good idempotent behavior:
- if a field is already set to the same intended outcome, return success
- if another caller already completed the same transition, return a benign success or already-done response

Examples:
- confirm voice ready when that side is already marked ready
- confirm lobby entered when that side is already marked entered

Do not:
- throw hard errors for safe repeats
- create duplicate transitions for repeated taps or retries

---

## Affected Row Count Rule

Never assume success just because `.update()` returned no error.

You must check:
- was a row actually updated
- if not, is that expected idempotency or an error

Use this distinction:
- **0 rows + expected idempotent/race condition** → benign result
- **0 rows + expected real state change** → failure or blocked result

Do not return fake success if no authoritative state changed.

---

## Response Shape Rule

Responses should be simple, explicit, and machine-friendly.

Prefer:
- `success: true/false`
- action-specific booleans
- explicit reason or message
- optional blockers when relevant

Examples:
- `voice_ready_recorded: true`
- `countdown_started: true`
- `already_started: true`
- `waiting_for: "voice"`
- `reason: "timeout"`

Do not return vague success messages without enough information to explain the outcome.

---

## Logging Rule

Log authoritative decision points, not noisy implementation chatter.

Prefer logs that show:
- function name
- match id
- evaluator path / trigger
- authoritative inputs
- computed blockers
- decision
- write result

Examples:
- fresh state
- derived booleans
- blockers array
- guarded write attempted
- result started / already_started / blocked

Do not rely on client logs to explain server decisions.

---

## Edge Function Ownership Rule

If a state transition matters, one server-side place must own the decision.

Good:
- one evaluator decides whether countdown can start
- multiple triggers may call it, but the decision logic stays in one place

Bad:
- duplicate prerequisite logic across multiple functions
- one path checking different requirements than another
- client deciding one part while server decides another

---

## What Good Looks Like

### Good: confirm-voice-ready
- authenticate caller
- fetch match
- verify caller is challenger or receiver
- write that side's `voice_ready_at`
- fetch fresh state if countdown decision depends on it
- evaluate countdown from fresh authoritative fields
- guarded write countdown if allowed
- return explicit result

### Good: maybe-start-countdown
- fetch fresh match
- evaluate same authoritative prerequisites as immediate path
- only relax the timeout-specific condition if deadline has passed
- use guarded write
- return explicit started / blocked / already-started result

---

## What Bad Looks Like

### Bad: client-authoritative transition
- client decides countdown should start
- client writes state directly
- server only mirrors it

### Bad: stale-read decision
- fetch row
- write field
- make second decision from the old object

### Bad: fake success
- update returns no error
- no rows changed
- function still returns success

### Bad: logic drift
- confirm-voice-ready checks one set of prerequisites
- maybe-start-countdown checks a different set
- bugs appear only in one path

---

## Edge Function vs Client

### Client may
- call the Edge Function
- show loading state
- optimistically show local UI state only if it can be safely rolled back
- refetch after response
- react to realtime notifications

### Client must not
- decide authoritative match transitions
- set authoritative remote lifecycle state directly
- assume local state is correct without refetch
- replace server validation with UI guards

---

## Debug Order for Edge Function Problems

When a remote flow breaks, debug in this order:

1. did the Edge Function run
2. did it authenticate the correct user
3. what fresh state did it read
4. what blockers did it compute
5. did the guarded write run
6. did the write affect a row
7. what response did it return
8. did the client refetch the updated row

Do not jump straight to realtime or UI until the authoritative write path is proven correct.

---

## Bottom Line

For remote matches, the Edge Function is where truth is checked, decided, and written.
If the server decision is not explicit, fresh, guarded, and verifiable, the implementation is not correct.