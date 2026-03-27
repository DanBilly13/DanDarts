> Supporting reference for: supabase-patterns  
> Apply when: working on remote match state, lifecycle checks, lobby/countdown/start logic, card classification, or debugging remote state mismatches  
> Do not apply to: local matches or client-side UI state not backed by authoritative fields

# Authoritative Remote Fields

## Purpose

These are the fields that matter when reasoning about remote match state.

This document exists to stop two common mistakes:
1. trusting derived client UI state over authoritative backend state
2. checking the wrong field when debugging or writing Edge Function logic

If a remote behavior is wrong, inspect these fields first.

---

## Core Rule

For remote matches, authoritative truth lives in the canonical match row and any directly related authoritative records.

Not in:
- temporary SwiftUI view state
- local booleans derived earlier in the flow
- realtime payload assumptions
- card presentation state
- navigation state

If a remote screen looks wrong, first ask:

**Which authoritative field should prove this state?**

---

## Primary Authoritative Match Fields

These fields are the main remote lifecycle fields that the client and edge functions should reason from.

### Identity / ownership
- `id`
- `challenger_id`
- `receiver_id`
- `is_replay`
- `replay_source_match_id`

Use these to determine:
- who owns which role
- whether the match is a replay
- whether the current user is allowed to act on the match

---

### Core lifecycle
- `remote_status`
- `current_player_id`

Use these to determine:
- whether the match is pending / ready / lobby / in_progress / completed / cancelled
- whose turn it is once gameplay begins

Do not infer lifecycle stage from UI or route alone.

---

### Challenge window / readiness window
- `challenge_expires_at`
- `join_window_expires_at`
- `voice_connect_deadline`

Use these to determine:
- whether the initial challenge expired
- whether a ready match can still be joined
- whether the lobby voice window has timed out

Deadlines must be evaluated from authoritative timestamps, not local timers alone.

---

## Authoritative Lobby Fields

These fields determine whether the lobby is truly ready to proceed.

### Lobby joined
- `challenger_lobby_joined_at`
- `receiver_lobby_joined_at`

Meaning:
- each player has authoritatively entered the lobby flow on the server side

Use these for:
- confirming both players actually joined the lobby flow
- countdown/start eligibility checks

Do not replace these with local onAppear assumptions.

---

### Lobby view entered
- `challenger_lobby_view_entered_at`
- `receiver_lobby_view_entered_at`

Meaning:
- each player has authoritatively reached the lobby UI and confirmed view entry

Use these for:
- guarding countdown start
- proving the player truly reached the lobby screen
- debugging “why didn’t countdown start yet?”

These are commonly confused with `*_lobby_joined_at`.  
They are not the same thing.

---

### Voice readiness
- `challenger_voice_ready_at`
- `receiver_voice_ready_at`

Meaning:
- each player has authoritatively confirmed voice readiness to the server

Use these for:
- immediate countdown eligibility
- replay rebind readiness checks
- debugging whether the lobby is blocked on voice vs something else

Do not rely on local WebRTC state alone when countdown logic is server-authoritative.

---

### Countdown start
- `lobby_countdown_started_at`

Meaning:
- the server has authoritatively started the lobby countdown

Use this for:
- entering countdown phase
- deciding whether countdown already started
- preventing duplicate countdown starts
- determining whether fallback already succeeded

If this is `nil`, the countdown has not authoritatively started, no matter what the local UI thinks.

---

## Authoritative Gameplay Fields

### Turn ownership
- `current_player_id`

Meaning:
- whose turn the server says it is

Use this for:
- turn gating
- gameplay UI correctness
- post-countdown transition checks

Do not derive turn ownership from who started the match or who is currently viewing the screen.

---

### Terminal / completion state
Depending on your schema and supporting records, this usually includes:
- `remote_status`
- match completion timestamps / winner fields if present
- server-authored visit / turn records
- end-of-match result data

Use these to determine:
- whether the match is truly completed
- whether replay should be allowed
- whether end game UI is justified

---

## Card / List Classification Fields

Cards should be classified from authoritative match state, especially:

- `remote_status`
- `challenge_expires_at`
- `join_window_expires_at`
- `is_replay`
- role fields (`challenger_id`, `receiver_id`)
- cancellation / decline state if represented in authoritative status or related records

Use these to decide whether a match belongs in:
- pending
- ready
- sent
- active
- hidden

Do not classify cards from stale cached arrays or previously derived presentation state.

---

## Common Field Groupings by Decision

### 1. Can this user act on the match?
Check:
- `challenger_id`
- `receiver_id`
- current authenticated user
- `remote_status`

---

### 2. Should this card appear in a list?
Check:
- `remote_status`
- role ownership
- expiry fields
- replay flags where relevant

---

### 3. Can countdown start?
Check:
- `remote_status == lobby`
- `challenger_lobby_joined_at`
- `receiver_lobby_joined_at`
- `challenger_lobby_view_entered_at`
- `receiver_lobby_view_entered_at`
- `challenger_voice_ready_at`
- `receiver_voice_ready_at`
- `lobby_countdown_started_at`

Fallback countdown may also check:
- `voice_connect_deadline`

---

### 4. Can match start?
Check:
- `remote_status`
- `lobby_countdown_started_at`
- `current_player_id` if your flow sets it as part of authoritative start prep
- any additional server prerequisites required by `start-match-if-ready`

Do not start from a local countdown timer alone.

---

### 5. Why is the lobby stuck?
Check in this order:
- `remote_status`
- `challenger_lobby_joined_at`
- `receiver_lobby_joined_at`
- `challenger_lobby_view_entered_at`
- `receiver_lobby_view_entered_at`
- `challenger_voice_ready_at`
- `receiver_voice_ready_at`
- `voice_connect_deadline`
- `lobby_countdown_started_at`
- `current_player_id`

This usually reveals the blocker immediately.

---

## Field Meaning Reference

### `remote_status`
Canonical remote lifecycle stage.

Typical meanings:
- `pending` → challenge sent, awaiting response
- `ready` → accepted / joinable
- `lobby` → both users entering or inside lobby flow
- `in_progress` → gameplay active
- `completed` → match finished
- `cancelled` / equivalent → match no longer actionable

Always trust this over route or UI assumptions.

---

### `current_player_id`
Canonical current turn owner or pre-start owner when used by your flow.

Important:
- this may remain `nil` before the authoritative transition that sets turn ownership
- if your countdown/start architecture sets this during countdown start, that write is authoritative

---

### `*_lobby_joined_at`
Proof that the player entered the lobby flow.

Not the same as:
- view appeared
- voice connected
- countdown started

---

### `*_lobby_view_entered_at`
Proof that the player reached the lobby screen and that the server knows it.

This is stronger than a local view lifecycle event.

---

### `*_voice_ready_at`
Proof that the server knows the player is ready from the voice perspective.

This matters more than:
- local peer connection assumptions
- local “connected” booleans
- local replay rebind assumptions

---

### `lobby_countdown_started_at`
The single authoritative proof that countdown began.

If this is absent, countdown did not start.
If this is present, any client still showing “connecting” is stale.

---

### `voice_connect_deadline`
The authoritative deadline for lobby voice readiness fallback behavior.

Used to distinguish:
- “still waiting normally”
- “fallback path is now allowed”

---

## Client May / Must Not

### Client may
- derive temporary UI presentation from authoritative fields
- compute booleans like `bothJoined` or `bothVoiceReady`
- show loading/connecting/countdown phases based on these fields
- trigger refetch when these fields may have changed

### Client must not
- invent replacements for these fields locally
- continue a lifecycle transition if the authoritative fields do not support it
- confuse `joined` with `view_entered`
- treat local voice connection as equivalent to `*_voice_ready_at`
- treat local timer progression as equivalent to `lobby_countdown_started_at`

---

## Edge Function Rules

When an Edge Function makes a remote lifecycle decision, it should read the exact authoritative fields required for that decision.

Do not:
- read too little and guess the rest
- use stale data from before a write
- mix joined/view/voice fields incorrectly
- write success logs that are not backed by the row state

If an Edge Function decides:
- countdown start
- lobby readiness
- match start
- cancellation visibility
- replay readiness

it should fetch the fields that prove that decision.

---

## Debugging Rule

When debugging a remote bug, name the missing or incorrect authoritative field explicitly.

Good:
- “countdown didn’t start because `receiver_lobby_view_entered_at` was still nil”
- “UI stayed stale because arrays were not reloaded after `remote_status` changed to cancelled”
- “voice looked connected locally, but `challenger_voice_ready_at` never persisted”

Bad:
- “the lobby is bugged”
- “realtime is weird”
- “SwiftUI didn’t update”

---

## What Good Looks Like

### Good: countdown debugging
- fetch authoritative row
- inspect joined / view_entered / voice_ready / countdown_started_at
- identify exact blocker
- fix the write/refetch logic around that field

### Good: replay debugging
- check `is_replay`
- check authoritative status transitions
- check whether arrays refetched from those fields
- verify overlay state follows authoritative result

### Good: turn debugging
- check `current_player_id`
- compare with authenticated user
- verify gameplay UI is derived from that, not local memory

---

## What Bad Looks Like

### Bad: wrong field
- using `*_lobby_joined_at` as proof the player entered the lobby view

### Bad: stale inference
- assuming countdown started because local phase changed, even though `lobby_countdown_started_at` is nil

### Bad: local truth over server truth
- assuming voice is ready because WebRTC connected locally, even though `*_voice_ready_at` was never written

### Bad: UI-derived lifecycle
- using card state or navigation route as proof of authoritative match status

---

## Minimum Field Sets by Feature

### Sent / pending / ready challenge cards
Usually need:
- `id`
- `challenger_id`
- `receiver_id`
- `remote_status`
- `challenge_expires_at`
- `join_window_expires_at`
- `is_replay`

### Lobby readiness / countdown
Need:
- `remote_status`
- `challenger_lobby_joined_at`
- `receiver_lobby_joined_at`
- `challenger_lobby_view_entered_at`
- `receiver_lobby_view_entered_at`
- `challenger_voice_ready_at`
- `receiver_voice_ready_at`
- `voice_connect_deadline`
- `lobby_countdown_started_at`
- `challenger_id` when needed for authoritative current-player setup

### Match start
Need:
- `remote_status`
- `lobby_countdown_started_at`
- `current_player_id`
- any server-owned start prerequisites required by your start function

### Gameplay turn UI
Need:
- `remote_status`
- `current_player_id`
- authoritative visit/turn records as applicable

---

## Bottom Line

If remote behavior matters, there is a field that proves it.  
Find that field first.  
Do not let the client argue with the row.