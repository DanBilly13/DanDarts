> Supporting reference for: supabase-patterns  
> Apply when: working on realtime subscriptions, match updates, or remote flow synchronization  
> Do not apply to: local matches or client-side state that is not realtime-backedn

# Realtime Rules

## Purpose

Realtime is a trigger layer for remote matches.

Use realtime to:
- detect that something may have changed
- wake up the client
- trigger a refetch of authoritative state
- update UI only after authoritative state is re-read

Do not use realtime as the source of truth.

---

## Core Rule

Realtime tells the client **something changed**.

Realtime does **not** tell the client the full authoritative truth.

The correct pattern is:

1. receive realtime event
2. decide whether it is relevant
3. trigger authoritative refetch
4. update UI from fetched state

---

## What Realtime Is For

Realtime is good for:
- prompting a refetch
- removing stale waiting states
- reacting quickly to challenge lifecycle changes
- reacting quickly to lobby / countdown / start transitions
- waking the correct screen when a remote match changes

Realtime is not good for:
- final lifecycle decisions
- deriving authoritative match state from payload alone
- skipping the refetch step
- patching local state and assuming it is correct

---

## Realtime as Trigger, Not Truth

The payload may be incomplete, out of order, duplicated, or observed at awkward times in the client lifecycle.

That means:

- use realtime to notice a possible change
- use fetchMatch or loadMatches to confirm the real state
- render from the refetched match model

Bad:
- “Realtime said status is lobby, so I’ll just set the local model to lobby and continue”

Good:
- “Realtime fired, so I’ll refetch the match and only continue if the fetched state confirms lobby”

---

## Preferred Realtime Flow

For remote match updates, use this order:

1. receive realtime insert/update/delete
2. confirm the event belongs to the current user / current match / relevant list
3. classify whether it should trigger:
   - single-match refetch
   - list reload
   - forced list reload
4. refetch authoritative state
5. update UI from refetched state
6. ignore the realtime payload once the refetch completes

---

## Single Match vs List Reload

Use the smallest authoritative refetch that fits the situation.

### Use `fetchMatch(...)` when:
- already inside a remote flow
- a single active match is being viewed
- the lobby/gameplay screen needs the latest state
- you only care about one match

### Use `loadMatches(...)` when:
- challenge lists may have changed
- cards in pending / ready / sent sections may need to move
- a match may need to appear or disappear from the lists
- replay cards or sent challenge cards depend on array classification

### Use forced list reload when:
- the normal “skip while in remote flow” rule would otherwise leave stale arrays in place
- a replay card / overlay must update from service arrays
- a list-backed UI must reflect a remote cancellation / ready transition immediately

---

## Override Rule: When to Break the Default

Default behavior:
- while in remote flow, prefer `fetchMatch(...)`
- avoid broad `loadMatches(...)` reloads that churn list state unnecessarily

Override this default only when stale list-backed data would break the UX.

Force a list reload when:
- replay UI depends on service arrays being current
- a sent / pending / ready card must disappear or move immediately
- a remote cancellation or replay status change would otherwise leave stale arrays on screen
- the current screen is polling or rendering from service arrays rather than a single fetched match

In other words:

- active match screen truth → prefer `fetchMatch(...)`
- list / card / replay overlay truth → force `loadMatches(...)` if needed

This override should be:
- explicit
- narrow
- logged
- justified by a concrete stale-array risk

Do not force reload just because a realtime event arrived.
Force reload only when the UI depends on list-backed authoritative state.

---

## Relevance Rule

Do not react to every realtime event.

Check whether the event is relevant to:
- the authenticated user
- the current match
- the current screen
- replay vs non-replay context
- the list bucket the match belongs to

Ignore irrelevant events early.

This keeps the UI stable and avoids unnecessary churn.

---

## No Direct State Mutation From Payload

Do not build remote lifecycle behavior directly from realtime payloads.

Avoid patterns like:
- setting local status directly from payload
- setting countdown locally from payload
- deciding navigation from payload alone
- removing cards from arrays only because a payload arrived

Instead:
- trigger refetch
- classify from authoritative fetched state
- then update local UI

---

## Realtime Ordering Rule

Assume events can arrive:
- before the screen is ready
- during navigation
- during another write
- out of order
- more than once

So:
- make handlers idempotent
- allow benign duplicates
- use guards for active flow / match identity / navigation state
- prefer authoritative refetch over clever local reconciliation

---

## In-Remote-Flow Rule

When already inside a remote match flow, be careful with broad list reloads.

Default behavior:
- prefer `fetchMatch(flow)` for the active match
- avoid unnecessary list churn while the user is in lobby/gameplay

Exception:
- if a list-backed replay/sent/pending UI must update and stale arrays would break UX, force the list reload explicitly

This exception should be deliberate, narrow, and logged.

---

## Navigation Rule

Realtime must not own navigation by itself.

Realtime may:
- trigger authoritative refetch
- clear waiting states
- make the latest status visible

Navigation should only happen after:
- authoritative state is confirmed
- the screen verifies the match is in the expected state
- local guards agree the current screen instance is still valid

Bad:
- payload says `in_progress` → immediately push gameplay

Good:
- realtime fires → fetchMatch confirms `in_progress` → current screen validates → then navigate

---

## Card/List Classification Rule

Challenge cards should be classified from authoritative match state, not retained as stale UI assumptions.

Good:
- reload arrays
- classify each match into pending / ready / sent / hidden
- render from those arrays

Bad:
- keep an old card on-screen because a refetch was skipped
- infer a cancelled/declined/accepted state from stale arrays

---

## Replay-Specific Rule

Replay flows often depend on service arrays and overlays.

That means replay status changes may require:
- forced list reloads even while in remote flow
- explicit polling safeguards only when needed
- careful rebinding of existing voice session state
- authoritative refetch before navigation or dismissal

If replay UI is backed by arrays, stale arrays are a bug.

---

## Optimistic UI Rule

If using optimistic UI around realtime-driven flows:
- keep it temporary
- make it rollback-safe
- let authoritative refetch win
- never let optimistic state become long-term truth

Optimistic UI is for perceived responsiveness, not correctness.

---

## What Good Looks Like

### Good: challenge accepted
- realtime update arrives
- client sees relevant status change
- triggers list reload
- reload moves match from sent/pending to ready
- UI updates from arrays

### Good: lobby countdown
- realtime update arrives
- client refetches active match
- fetched match shows countdown started
- lobby phase changes to countdown

### Good: replay cancelled remotely
- realtime update arrives
- client forces list reload because replay overlay depends on list-backed state
- match disappears or becomes cancelled in authoritative arrays
- overlay dismisses from authoritative result

---

## What Bad Looks Like

### Bad: payload-driven UI truth
- realtime payload says cancelled
- client changes local status without refetch
- arrays remain stale
- another screen disagrees

### Bad: skipped reload causing stale UI
- realtime event arrives
- handler skips reload because “in remote flow”
- list-backed overlay never updates
- UI appears stuck

### Bad: duplicate local reconciliation
- realtime mutates local model
- refetch later mutates it again
- UI flickers or enters conflicting states

---

## Logging Rule

Log realtime handling at the decision level.

Useful logs:
- event type
- match id
- replay vs non-replay
- relevance decision
- chosen action: ignore / fetchMatch / loadMatches / forced loadMatches
- whether reload was skipped or forced
- resulting authoritative status after refetch

Avoid noisy logs that dump every payload field unless actively debugging a specific issue.

---

## Debug Order for Realtime Problems

When realtime behavior looks wrong, debug in this order:

1. did the realtime event arrive
2. was it considered relevant
3. what refetch path was chosen
4. was that refetch skipped, throttled, or forced
5. did authoritative data actually change
6. did arrays / flowMatch update from that data
7. did the UI render from the updated authoritative model

Do not start by blaming SwiftUI rendering if the refetch never happened.

---

## Client May / Must Not

### Client may
- subscribe to realtime
- filter events
- trigger refetch
- keep temporary optimistic UI
- use guards to avoid stale navigation or duplicate handling

### Client must not
- treat realtime as final truth
- skip authoritative refetch for important lifecycle state
- navigate solely from payload
- keep stale arrays when the screen depends on refreshed arrays

---

## Bottom Line

Realtime is the doorbell, not the person at the door.  
When it rings, refetch the authoritative state and trust that — not the bell.