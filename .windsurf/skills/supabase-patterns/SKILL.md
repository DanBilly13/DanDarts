---
name: supabase-patterns
description: use for remote-match server architecture, edge functions, rpc flows, realtime-triggered refetch, authoritative database writes, idempotency, and race-safe supabase patterns. do not use for local-only match logic or pure client-side ui work.
---

# Supabase Patterns

Use this skill for remote-match backend and client/server coordination work.

Do not use this skill for local matches, local game logic, or purely presentational SwiftUI changes.

## Core Rule
Treat the server and database row as authoritative for remote matches.
The client may render, trigger actions, and refetch, but must not invent authoritative remote state locally.

## Remote vs Local
- Local matches are device-local gameplay flows. Do not apply Supabase authority rules there.
- Remote matches are server-authoritative flows backed by Supabase tables, edge functions, RPCs, and realtime notifications.

## Rules
- Write authoritative remote state on the server, not in the client.
- Use realtime as a trigger to refetch authoritative state, not as the final source of truth.
- After server writes, refetch canonical match state.
- Make remote-write functions idempotent when repeat calls are plausible.
- Guard race-prone writes with narrow `where` clauses and affected-row checks.
- Prefer one authoritative writer for a state transition.
- Log decision inputs and blockers at the server boundary when debugging state transitions.

## Edge Function / RPC Patterns
- Validate the caller and participant role first.
- Fetch the canonical row before deciding.
- Apply the write with explicit guards.
- Verify the write actually changed the intended row when needed.
- Return success only when the authoritative write succeeded or the request is safely idempotent.

## Realtime Pattern
- Use realtime events to trigger refetch.
- Do not assume the realtime payload alone is enough to drive final remote UI state.
- If a remote flow is sensitive, refetch the canonical match row before advancing UI.

## Debug Order
For remote-match bugs, debug in this order:
1. lifecycle trigger
2. server write
3. authoritative refetch
4. realtime propagation

## What Not to Do
- Do not mutate remote authoritative state only in SwiftUI view state.
- Do not treat realtime as the source of truth.
- Do not apply remote Supabase rules to local-only match flows.
- Do not add duplicate server-side writers for the same transition without a single clear owner.
