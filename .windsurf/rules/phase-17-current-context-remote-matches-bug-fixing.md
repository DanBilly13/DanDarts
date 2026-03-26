---
trigger: model_decision
---

# phase-17-current-context-remote-matches-bug-fixing

## Project Overview

This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**.

The app already has a strong Local Match experience. The Remote Match feature extends that experience so two players can play asynchronously, with server-backed state, challenge flows, lobby handling, countdown/start logic, and gameplay synchronization.

At this stage, the goal is **not** to redesign the feature. The goal is to **stabilize it**.

---

## What the App Supports

### Local Matches
Local Matches are played on one device.
They are immediate, self-contained, and do not depend on server state, realtime updates, invites, or network timing.

Local matches are the simpler and more stable baseline experience:
- no challenge flow
- no lobby handshake
- no remote synchronization
- no server-authoritative turn flow
- no replay coordination between devices

### Remote Matches
Remote Matches are multiplayer matches between two devices and rely on Supabase-backed state.

A Remote Match includes:
- challenge creation
- pending / sent / ready card states
- accept / join flows
- remote lobby entry
- voice connection / readiness flow
- countdown to match start
- server-authoritative match start
- remote gameplay sync
- replay flows
- cancellation / decline / expiry handling
- navigation into and out of remote gameplay

Because Remote Matches depend on networked state, realtime updates, and multi-step coordination between two players, they are significantly more complex than Local Matches.

---

## Current Phase

## Phase 17 Goal: Remote Matches Bug Testing and Fixing

Phase 17 is focused on **testing, identifying, and fixing bugs** in the Remote Matches feature.

This phase is intentionally focused on:
- reliability
- state consistency
- edge cases
- UI correctness
- navigation correctness
- realtime correctness
- replay correctness
- lobby/countdown/start stability

This phase is **not** primarily about adding new remote features.
It is about making the existing remote feature stable and production-ready.

---

## Current Position of the Feature

Remote Matches are now broadly working end-to-end.

The feature currently supports the full intended journey:
- create challenge
- receive challenge
- accept / join
- enter lobby
- complete pre-match coordination
- start remote gameplay
- play the match
- finish the match
- request replay
- handle replay flows

A large amount of the heavy architecture is already in place.

However, because this feature has many moving parts, bugs still surface in:
- race conditions
- realtime timing
- replay transitions
- lobby state updates
- challenge card behavior
- cancellation handling
- edge-case UI state
- simultaneous user actions

---

## Working Style for Phase 17

To keep context smaller and cleaner:
- this document should remain high-level
- it should not become a running log of every bug
- it should not store long fix histories
- it should not hold detailed patch plans for individual issues

Instead:
- each bug should be investigated directly in chat
- each fix should be planned directly in chat
- only stable, high-level context belongs here

This keeps the working context lightweight and avoids token bloat.

---

## Phase 17 Rules of Engagement

When working on bugs in this phase:
1. Treat the remote feature as fundamentally implemented, but still being stabilized.
2. Prefer focused fixes over broad refactors unless a root-cause refactor is clearly needed.
3. Preserve working flows whenever possible.
4. Investigate the exact failing state before proposing fixes.
5. Keep bug plans scoped to one issue at a time.
6. Use logs and observed behavior to identify the true source of failure.
7. Avoid bloating the persistent context doc with issue-by-issue detail.
8. In the event that we need to update any edge functions we are using the supabase editor so I will copy and paste them in.,

---

## Summary

Phase 17 is the **Remote Matches stabilization phase**.

The app already has:
- a working Local Match experience
- a mostly working Remote Match experience

The current priority is:
- bug testing
- bug isolation
- bug fixing
- making remote play reliable across normal flows and edge cases

Detailed bug plans will be handled directly in chat, one issue at a time.