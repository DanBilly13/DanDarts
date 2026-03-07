---
trigger: always_on
---
# remote-matches-current-context-phase-7-match-history-stage-2

## Project Overview
This project adds **Remote Matches** to an existing iOS darts app that already supports **Local Matches**. A remote match is a turn-based asynchronous game backed by Supabase (DB + Realtime + Edge Functions + RPC). The app must support:
- Creating challenges and accepting/joining matches
- Playing remote turns with server-authoritative state
- Showing match results + match history consistently across Remote + Local

Phase 7 is focused on **Match History** reliability and correctness.

---

## Phase 7 Goal: Match History
Make match history behave consistently across:
1) **End Game View** (immediately after a match completes) - This is complete
2) **Match History Tab** (list of past matches; tapping a card opens details) - This is not working

We want the same “Match Details” screen to show correct data whether you arrive from End Game or from the History list.

---

## Current Status (What Works)
### ✅ End Game Match Details Works
- **Remote match history/details works** when viewed from the **End Game view**.
- **Local match history/details works** when viewed from the **End Game view**.

This means:
- Remote pipeline (RPC + match_throws inserts + match completion + fetching turns) is now working end-to-end in at least one entry point.
- The UI rendering for details is capable of displaying correct match history when the view receives the right `MatchResult` / turns payload.

### ✅ Local Match History Used to Work From History Tab
- Historically, local match history has been solid from the Match History tab.
- Somewhere during the remote-match work, that path likely got disrupted (routing or data loading path divergence).

---

## Current Bug (Phase 7 Blocking Issue)
### ❌ Match History Tab → Match Card → Details shows NO match history data
When tapping a match card inside the **Match History tab**, the destination view appears but shows **no match history / turn data**.

Important nuance:
- This is not a DB insertion problem (remote `match_throws` exist and end-game can display them).
- This is almost certainly a **navigation + data-loading path mismatch**: the “from history tab” entry point is not loading the same data that “from end game” loads.

---

## Likely Root Cause (High Confidence)
There are now multiple pathways to open match details:

1) **EndGameView path**
   - Has the freshest match id + often triggers a direct fetch.
   - Correctly hydrates the match result and loads turns/throws.

2) **MatchHistoryTab path**
   - May be navigating with an incomplete object (e.g., just `MatchSummary`)
   - Or using a different loader that does not call the “load turns” function
   - Or expecting local-only fields that no longer exist / no longer populate

Symptoms match one of these:
- The history tab is using an older match-loading function that does not fetch `match_throws` / turns.
- The history tab navigates to a details view but the details view never triggers a load, because it expects preloaded data.
- The router/NavigationStack path changed and the destination now receives a different parameter type or loses the match id.

---

## Salient Changes Made Recently (Context That Matters)
A number of changes were implemented to make Remote Matches reliable, and these changes may have unintentionally broken the history-tab flow:

### 1) Navigation / Routing adjustments
- Remote match flow moved toward a **single NavigationStack push** model (instead of modal or multi-stack patterns).
- “Flow gating” / latch patterns were added to prevent double navigations and race conditions.
- List freeze / enter-flow latches were introduced to keep the match list stable during state transitions.

**Why this matters for Phase 7:**
- The history tab may still be using an older navigation route or a now-invalid route payload.
- The details view may be reachable but not wired to fetch the data if it no longer gets the expected input.

### 2) Remote match data pipeline changes
- Server-authoritative visit saving via Edge Function + RPC (`save_remote_visit`)
- `match_throws` is the authoritative per-visit storage for turn-by-turn history
- Match rows now contain `last_visit_payload`, `player_scores`, and `turn_index_in_leg` for realtime updates

**Why this matters for Phase 7:**
- Match details needs to fetch match summary + join against `match_throws` (or separately load turns).
- Any path that only loads the `matches` row (without turns) will show “empty history”.

### 3) Match result model hydration changes
- Work was done to ensure EndGameView can show details for both Local and Remote.
- It’s possible the “load match by id” method was updated for one caller but not for the history tab caller.

---

## Phase 7 Work Plan (What We Need to Do)
### A) Unify the match-details loading contract
Define one consistent rule:

> The Match Details screen must always have a match id and must always load (or receive) full detail including turn-by-turn throws.

Recommended pattern:
- Always navigate with `matchId` (and match type/local vs remote if needed)
- Details view always calls a single authoritative loader:
  - `loadMatchDetails(matchId:)` which returns:
    - match metadata
    - players
    - winner
    - duration
    - turns/throws (local from local store; remote from `match_throws`)

### B) Fix history tab click path
- Ensure match card tap provides correct `matchId`
- Ensure destination triggers the same loader used by end-game path
- Ensure the loader fetches:
  - for remote: `match_throws` rows for this match id
  - for local: local turns history

### C) Regression check: Local history tab
- Local history was known-good previously.
- After changes, confirm:
  - local history list still loads correct match summaries
  - local card tap loads correct full details
- If it’s broken, it’s probably because the tab now routes to a “remote-capable details view” but the loader doesn’t handle local correctly or vice versa.

---

## Repro Steps (Current Bug)
1) Open Match History tab
2) Tap any match card
3) Match details opens but shows no turns / no history data

Control test:
- Finish a match → EndGameView → open match details → history appears correctly

---

## Definition of Done (Phase 7)
- Match History tab shows cards for both local and remote matches
- Tapping a card loads the match details with full turn-by-turn history
- Local match history remains correct (no regression)
- Remote match history remains correct (and consistent with end-game display)

---

## Notes / Constraints
- Remote history data source is `match_throws` (turn-by-turn)
- Remote match summary is `matches` row
- Details screen must hydrate players with more than just name (future improvement: avatar + nickname)
- Avoid duplicating logic across entry points: EndGameView and History tab should reuse the same loader

---
