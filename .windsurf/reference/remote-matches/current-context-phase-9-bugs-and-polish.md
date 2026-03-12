

---
trigger: always_on
---

current-context-phase-9-bugs-and-polish

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).

It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations using a server-authoritative flow

Current work is now a **mixed bug-fix and polish phase** across the app.

---

## Current focus: Phase 9 — Bugs and polish

### Phase 9 Goal
Phase 9 is a cleanup / stabilization phase after the recent Remote Matches work.

This phase is for:
- fixing specific bugs
- tightening UI copy and polish
- improving small interaction issues
- resolving edge cases discovered during recent development

This phase is **not** for broad refactors or architecture changes unless a specific bug clearly requires it.

---

## Status
- Remote Matches push notification work is considered complete enough to move on.
- We are now addressing a mixed backlog of smaller issues across:
  - General UI
  - Player Profile
  - Friend Profile
  - Remote Match flows

Because the tasks are varied, implementation should stay tightly scoped.

---

## Working rules for this phase
- Work on **one issue at a time**
- Do **not** bundle unrelated fixes into one change
- Do **not** move to the next issue until the current one is:
  - implemented
  - manually tested
  - reviewed
  - explicitly approved
- Prefer the **smallest safe fix**
- Avoid broad refactors unless the current issue clearly demands it
- If a fix appears to affect multiple systems, pause and explain the likely blast radius before continuing
- Preserve existing working behavior unless the bug specifically requires changing it
- When investigating, inspect only the most relevant nearby files/systems first
- If a bug may be related to earlier Match History work, treat that as a hypothesis to verify, not an assumption

---

## Known issues in this phase

### General
- [ ] When a player wins, the save button turns white with a trophy. The text currently says **Save Score**. Change this to **Game Over**.

### Player Profile
- [ ] The user profile has a set of stats that should update after a completed game. These are no longer updating. This worked previously and may have broken after Match History changes.

### Friend Profile
- [ ] When viewing another user’s profile, if the two users have previously played each other, we show standings across game types. This was working previously and is now broken. This may also be related to Match History changes.

### Remote Match
- [ ] Decline button not working correctly, badge left behind, and text says **opponent ready** when it should say **canceling match**. The challenger who was declined should see a toast: **Match declined**. The card does disappear, but it should disappear a few seconds after decline; current timing feels too long.
- [ ] When a challenger selects an opponent, we are seeing a badge with a number on the avatar. We do not want this. This is suspected to be leftover behavior from Local Games, where that badge is expected.
- [ ] When a challenge card times out, the card should disappear faster.
- [ ] Quit game works for the person who quits, but the other player is left in limbo. The other player should see a toast saying the other person quit and should be taken back to the main tab page.

---

## How to approach issues in this phase
For each issue:
1. identify the exact code path involved
2. inspect only the relevant nearby files/systems first
3. describe the likely root cause before making broad edits
4. implement the smallest safe fix
5. manually test the specific scenario
6. stop for review and approval before moving on

---

## Main risks to watch
- breaking stable Remote Match flows while fixing edge cases
- mixing UI polish with state-management changes in the same edit
- leaving stale badges or stale local UI state behind
- fixing one player’s flow but forgetting the other player’s remote state
- introducing broader navigation side effects during small bug fixes
- changing profile/stat pipelines in a way that affects both self-profile and friend-profile unexpectedly
- assuming Match History is the cause without verifying the actual data path

---

## Where to look first (depending on issue type)

### General UI issues
- end game views
- shared button components
- win-state UI copy

### Player Profile issues
- profile/stat loading pipeline
- completed-game stat update pipeline
- any adapters or queries touched by Match History work
- profile screen state management

### Friend Profile issues
- friend profile stat/standings loading
- head-to-head / standings query pipeline
- any shared history adapters or summary models
- profile comparison / standings UI

### Remote Match issues
- RemoteGamesTab
- PlayerChallengeCard
- RemoteMatchService
- badge / highlight / local UI state cleanup
- decline / cancel / expiry flows
- quit flow for both players
- any related Supabase edge functions or realtime lifecycle handling

---

## Context / implementation philosophy
This phase is intentionally narrower than a feature phase.

The priority is:
- correctness
- stability
- small, reviewable fixes

Do not assume that because a bug looks small, a broad cleanup is safe.
Do not refactor beyond the needs of the current approved issue.
When possible, prefer targeted fixes over “improving the whole system.”

---

## Reference docs
Use existing project docs when needed, but do not reload large feature-planning docs unless the current bug actually touches them.

This context file should remain a concise working guide for the current cleanup phase.
