> Supporting reference for: supabase-patterns
> Apply when: working on any remote match flow
> Do not apply to: local matche

# Server-Authoritative Remote Rules

Use these rules whenever working on **remote matches** backed by Supabase.

Do **not** apply these rules to local matches.

## Core Principle

For remote matches, the **server and canonical database row are authoritative**.

The client is responsible for:
- rendering UI
- sending user intents
- refetching server state
- reacting to authoritative updates

The client is **not** responsible for inventing or finalizing remote match state on its own.

## What This Means in Practice

### The client may
- call an Edge Function or RPC
- show loading / pending UI
- optimistically show non-authoritative presentation state when safe
- refetch the match after server-side writes
- react to authoritative row changes from a refetch or validated realtime flow

### The client must not
- locally decide that a remote match has advanced to a new authoritative state
- mark remote lifecycle steps complete without a server write
- trust stale in-memory state over a fresh server fetch
- use realtime payloads as the final source of truth for critical decisions

## Remote Match Authority Rule

If a remote match changes lifecycle state, turn state, readiness state, countdown state, completion state, cancellation state, or replay state, that change must be represented by a **server-side write** to the authoritative row or authoritative related tables.

If it is not written authoritatively, it is not real yet.

## Canonical Read Pattern

When a remote action matters, use this pattern:

1. User action happens in the client
2. Client calls the server
3. Server validates role, match status, and prerequisites
4. Server writes authoritative state
5. Client refetches canonical state
6. UI updates from canonical state

This pattern is preferred over:
- client-only transitions
- chained local assumptions
- using realtime payload fields as the final decision source

## Realtime Rule

Realtime is a **trigger**, not the source of truth.

Use realtime to:
- know that something changed
- know which match may need refreshing
- trigger a refetch

Do not use realtime alone to:
- finalize navigation
- finalize lifecycle transitions
- finalize countdown / start / completion decisions
- finalize who owns the turn

## Server-Side Decision Rule

Any important remote decision should be evaluated on the server from fresh authoritative data.

Examples:
- whether a challenge can be accepted
- whether a lobby countdown can start
- whether a match can start
- whether a replay request is still valid
- whether a sent / pending / ready card should transition to cancelled, declined, expired, or hidden

## Client-Side UI Rule

The client can have temporary UI state, but that state is only for presentation.

Examples of acceptable local UI state:
- spinner visibility
- disabled buttons
- temporary fade-out animation flags
- toast / banner state
- local sheet / alert presentation
- optimistic “processing” state while a request is in flight

Examples of unacceptable local authoritative state:
- deciding a remote match is now in progress without server confirmation
- deciding countdown has started without authoritative fields
- deciding a challenge is cancelled only because a button was tapped
- deciding a replay is valid without checking server state

## Refetch Rule

After a meaningful remote write, refetch the canonical match.

Do this especially after:
- create challenge
- accept / decline / cancel
- enter lobby
- confirm lobby entered
- confirm voice ready
- maybe-start-countdown
- start-match-if-ready
- save visit
- complete match
- create replay
- accept replay
- cancel replay

## Single-Owner Rule

For each authoritative transition, prefer **one clear server-side owner** of the write.

Multiple triggers may exist, but the authoritative decision logic should not drift across multiple places.

Good:
- multiple callers
- one evaluator / one writer

Bad:
- duplicated decision logic in several functions
- slightly different blockers in different paths
- one path writing fields another path assumes but does not verify

## Validation Rule

Before writing remote state, the server should validate:
- authenticated user
- participant role
- current match status
- required prerequisite fields
- race conditions / stale state where relevant

When useful, verify affected row count so the server knows whether a guarded write actually succeeded.

## Idempotency Rule

If a user action can plausibly be repeated, make the server path idempotent where possible.

Examples:
- confirm voice ready
- confirm lobby entered
- safe retry for countdown start attempts
- safe retry for cancel / decline where state may already have changed

Idempotent success is better than fragile duplicate failure when the final authoritative state is already correct.

## Race-Safety Rule

When two devices or two triggers may act at nearly the same time:
- fetch fresh state
- evaluate from authoritative fields
- use guarded updates
- inspect affected row count
- treat “already updated by another winner” as a benign outcome when appropriate

## Remote vs Local Reminder

Local matches are not governed by these server-authoritative rules.

Local match logic can be device-local because the device is the only authority there.

Remote match logic must assume:
- multiple devices
- network delay
- duplicate triggers
- stale local memory
- replay / reconnect / realtime timing issues

## Default Debug Order

When a remote bug appears, debug in this order:

1. Did the client trigger the intended server call?
2. Did the server validate and write the authoritative state?
3. Did the client refetch the canonical row?
4. Did realtime only assist discovery, rather than replace the refetch?
5. Is the UI rendering from canonical state or from stale local assumptions?

## What Good Looks Like

A healthy remote flow usually looks like this:

- client sends intent
- server validates
- server writes authoritative state
- client refetches
- UI advances from canonical data
- realtime helps other clients notice and refresh

## What Bad Looks Like

Common failure patterns:
- “it should be true by now” logic in SwiftUI
- using cached match state after a server write
- trusting a realtime payload without refetch
- duplicated server-side blockers in multiple functions
- local UI moving ahead before the canonical row proves it

## Bottom Line

For remote matches:

**write on the server, verify on the server, refetch on the client, render from canonical state.**
