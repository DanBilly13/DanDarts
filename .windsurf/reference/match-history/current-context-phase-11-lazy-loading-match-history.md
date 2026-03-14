---
trigger: manual
---

# current-context-phase-11-lazy-loading-match-history

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).

It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations using a server-authoritative flow
- **Showing end-game results and match history consistently across Remote + Local

Phase 11 focuses on **performance and scalability of Match History** without changing the current card UI or detail UI.


---

## Phase 11 Goal
Make the **History tab** fast as match history grows by splitting history loading into two tiers:

1. **Lightweight summary loading** for the match list/cards
2. **Lazy full-detail loading** only when a user opens a specific match

The expensive `match_throws` table must **not** be queried during history list load.

---

## Problem Statement
The current history flow loads **full match data for every match** when the History tab opens, including all `match_throws` rows.

That is fine for small histories, but it will become slow as history grows because:
- one match can have many throw rows
- the list screen does not need throw-level detail
- the app is paying detail-view cost up front for every card

This is an architectural problem, not a UI problem.

---

## Core Principle for This Phase
- **List = summary**
- **Detail = full model**
- **Detail fetch = lazy + cached**

This phase should be implemented as a **safe additive split**, not a rewrite.

---

## What Must Stay the Same
The following must remain unchanged from the user’s point of view:

- Match card UI
- Match card behavior
- Match detail UI
- Match detail stats/content
- Existing full-detail model semantics
- Existing full-detail fetch logic as the source of truth for detail screens

We are extending the architecture, not redesigning the feature.

---

## Required Architecture Change

## 1. Introduce a lightweight summary model
Create a `MatchSummary` model that contains only the fields needed to render a history card.

Expected fields:
- `id`
- `game_type`
- `game_name`
- `timestamp`
- `players`
- `scores`
- `player_scores`
- `winner_id`
- `match_format`
- `total_legs_played` if the card logic needs it

This model must not include throw-level detail.

---

## 2. Add a new summary fetch path
Add a new method such as:

- `fetchMatchSummaries(...)`

This method should:
- query only the `matches` table
- select only card-level columns
- never query `match_throws`
- return `[MatchSummary]`

This becomes the list screen’s data source.

---

## 3. Keep full fetch for detail only
The existing full-detail fetch must continue to own:
- full match loading
- `match_throws` loading
- detail model construction
- detail screen data

The only change is **when** it is used:
- no longer on History list load
- only when opening a specific match detail

---

## 4. Add in-memory detail caching
A full-detail cache should be added, keyed by match id.

Recommended behavior:
1. user opens match detail
2. check cache first
3. if hit: return immediately
4. if miss: fetch full detail
5. store in cache
6. render detail

This should make revisit behavior instant.

---

## Key Rule: Additive First
Do **not** delete or heavily modify the existing full fetch until the new summary path is working and verified.

Implementation should proceed safely:
- add summary model
- add summary fetch
- switch history list to summary path
- verify behavior
- only then consider cleanup or consolidation

If something breaks mid-way, the existing full-detail path should still be intact and recoverable.

---

## Navigation / Flow Requirement
There are at least two relevant entry points that must not drift apart:

1. **History tab -> match detail**
2. **End Game -> View Match History / detail**

These may currently use different loaders or slightly different pipelines.

Phase 11 should reduce divergence, not increase it.

The desired state is:
- list view uses summaries
- detail view uses one shared full-detail loader
- cache sits in the shared full-detail path

---

## Likely Files to Change

## Models
- `MatchSummary.swift`
- possibly card/player DTO helpers if card parsing currently lives inside a full model

## Services / repositories
- `MatchHistoryService.swift`
- `MatchesService.swift`
- any helper/adaptor responsible for history hydration or remote match mapping
- possibly a small cache helper if caching is split out

## Views / state
- `MatchHistoryView.swift`
- history row/card view if it currently expects a full match object
- `MatchDetailView.swift` if it assumes eager full data
- any history view model/provider/controller/state container

## Navigation
- router/coordinator files if navigation currently passes a full match object rather than `matchId`
- any wrapper that preloads detail before push

---

## Ambiguities to Resolve Before Coding

## 1. What exactly does the History tab use today?
Need to confirm:
- current fetch method
- current model type passed into cards
- whether cards are tightly coupled to the full detail model

## 2. What does the detail screen receive today?
Need to confirm whether navigation passes:
- full match object
- match id
- or both

This determines how much the detail entry point needs to change.

## 3. Are local and remote histories merged before or after fetch?
Need to confirm:
- whether both local and remote cards should use summary-level objects
- or whether only one side is currently in the expensive pipeline

Preferred outcome:
- consistent summary-level list contract for both, if practical

## 4. Does any card logic secretly depend on throw data?
If yes, that dependency must be removed before list lazy-loading is complete.

## 5. Are End Game and History tab already separate pipelines?
If yes, this phase must explicitly test and align them.

---

## Recommended Coding Order
1. Trace current list fetch and detail fetch paths
2. Identify all views that currently consume the full match model
3. Add `MatchSummary`
4. Add `fetchMatchSummaries(...)`
5. Switch History tab list to summary objects
6. Update card tap navigation to use `matchId`
7. Add full-detail cache in the service/repository layer
8. Update detail screen to fetch lazily
9. Verify End Game path also uses the shared full-detail loader
10. Regression test remote/local history behavior and revisit performance

---

## Testing / Verification Checklist

## Performance / query behavior
- [ ] History tab does not fetch `match_throws`
- [ ] History list only queries summary columns from `matches`
- [ ] History tab remains fast as match count grows

## UI behavior
- [ ] Match card UI looks unchanged
- [ ] Match detail UI looks unchanged
- [ ] Detail shows a loading state while lazy-loading
- [ ] Revisiting a detail screen is instant via cache

## Functional behavior
- [ ] Remote matches still render correctly in history cards
- [ ] Local matches still render correctly in history cards
- [ ] History tab -> match detail works correctly
- [ ] Cache does not show stale or wrong-match data

## End Game path (must be tested separately)
- [ ] End Game -> View Match History renders correct cards
- [ ] End Game -> match detail opens the correct match
- [ ] End Game detail path uses the same shared full-detail loader
- [ ] End Game path is not silently using stale pre-refactor code

---

## Success Criteria
Phase 11 is complete when:

- History list uses lightweight summary data only
- Full throw-level detail is fetched only on detail open
- Detail revisit uses cache
- Card UI and detail UI remain unchanged
- Both History-tab and End-Game detail flows still work correctly

---

## Working Summary
This phase is a **performance refactor with no intended visual change**.

The list screen should stop paying the cost of full detail loading.
The detail screen should remain the only place that loads full match data.
The app should become faster now and scale better later.

## Reference docs
The main one is
- .windsurf/reference/match-history/phase-11-lazy-loading-match-history-plan.md
But there are a whole load of stuff in
- .windsurf/reference
