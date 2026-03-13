# Phase 11 Task Plan: Lazy Loading for Match History

## Goal
Make the History tab fast and scalable by splitting match-history loading into two tiers:

1. **Lightweight list loading** for history cards
2. **On-demand full detail loading** only when a user opens a specific match

This keeps the card UI and detail UI unchanged while removing the expensive `match_throws` fetch from the history list path.

---

## Background

The current history flow fetches full match data for every game on load, including all `match_throws` rows. That works for small history sets, but it will get slower as match count grows because a single match can have dozens of throw rows.

We already know the card view does not need full throw-level detail. The card only needs summary-level fields that already exist on the `matches` table.

So the right fix is architectural:

- **History list uses a summary model**
- **Detail screen uses the existing full model**
- **Full detail is fetched lazily**
- **Detail results are cached in memory**

---

## Scope

### In scope
- Introduce a lightweight `MatchSummary` model for history cards
- Add a lightweight summary fetch from `matches`
- Update the history tab to use summaries only
- Trigger full match fetch only when entering a match detail view
- Add in-memory caching for full match details
- Preserve current card UI and current detail UI behavior

### Out of scope
- No schema changes
- No redesign of history cards
- No redesign of detail view
- No removal of the existing full-detail fetch path

---

## Expected outcome

After this phase:

- History tab remains fast even as match count grows
- `match_throws` is never queried during list load
- Match detail loads only when opened
- Returning to a previously opened detail is instant via cache hit
- Existing card UI and detail UI remain visually unchanged

---

## Implementation strategy

## 1. Trace the current history pipeline first

Before writing code, confirm:

- which service or repository method the History tab uses today
- what model the history cards currently receive
- what the detail screen currently receives on navigation:
  - full match object
  - match id
  - or both
- whether the End Game -> View Match History path uses the same loader or a different one

This matters because the cleanest implementation depends on whether list and detail are already coupled.

### Why this matters
We do not want to fix performance by creating a second broken pipeline. The list path and detail path should be cleanly separated, but detail loading should still be shared.

---

## 2. Create a `MatchSummary` model

Add a lightweight model that contains only the fields needed to render a match card.

### Proposed fields
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

### Notes
- Do not include turn or throw data
- Do not include heavy computed detail fields
- Keep the existing full match and detail model unchanged

### Purpose
This gives the history list its own explicit data contract so it cannot accidentally depend on full detail again.

---

## 3. Add a lightweight summary fetch

Create a new method such as:

- `fetchMatchSummaries(...)`

This method should:

- query only the `matches` table
- select only card-level columns
- never query `match_throws`
- return `[MatchSummary]`

### Important
This becomes the only source used by the History tab list.

The existing full-detail fetch method stays in place for detail loading.

---

## 4. Keep the full-detail fetch for match detail only

The full fetch method should remain responsible for:

- loading full match data
- loading `match_throws`
- building the existing detail model
- powering the detail screen
- powering any other path that truly needs full detail

### Change in behavior
The difference is simply when it is called:

- Before: history list load
- After: only when a user opens a specific match detail

---

## 5. Add in-memory detail caching

Add a cache such as:

- `[UUID: MatchDetail]`
- or `[String: MatchDetail]`

### Recommended behavior
When detail is requested:
1. check cache first
2. if found, return cached detail immediately
3. if not found, fetch full detail from backend
4. store result in cache
5. return it to the screen

### Recommended location
Put this cache in the service or repository layer that owns full-detail fetching.

That keeps:
- cache lookup logic centralized
- the detail screen simple
- revisit performance automatic

---

## 6. Update the History tab to use summaries only

Switch the History tab list loader from the current full fetch to `fetchMatchSummaries(...)`.

### Goal
The list view should only know about:
- card-level fields
- summary objects
- loading summaries
- navigating to detail by `matchId`

### Important
The card UI should look exactly the same after this refactor.

If cards currently depend on the full model, add a clean adapter or overload rather than sneaking full detail back into list load.

---

## 7. Update match detail loading to happen on navigation

When a user taps a match card:

- navigate to the detail screen with `matchId`
- optionally also pass the tapped `MatchSummary` for title or header placeholders
- show a loading state
- fetch full detail on demand
- use cache if available

### UX requirement
The user should see:
- immediate navigation
- then a loading state if needed
- then the existing detail UI

---

## 8. Make sure both entry paths share the same full-detail loader

We already have at least two relevant entry points:

- History tab -> match detail
- End Game -> View Match History or detail path

These should not drift apart.

### Recommendation
Use:
- summaries for the History tab list
- one shared full-detail fetch and cached detail path for actual detail loading

That avoids repeating the same class of bug we just had with history-related flows diverging.

---

## File groups likely to change

## Models
- `MatchSummary.swift` or equivalent model file
- possibly shared card or player DTO helpers if card parsing is embedded in the full model

## Services or repositories
- `MatchHistoryService.swift`
- `MatchesService.swift`
- any adapter or helper that enriches remote match card data
- possibly a cache helper if cache ownership is split out

## Views or state
- `MatchHistoryView.swift`
- match card row view if it currently expects full detail objects
- `MatchDetailView.swift` if it assumes preloaded data
- any history view model, provider, controller, or state store

## Navigation
- router or coordinator file if detail currently receives a full object and should now receive a `matchId`
- any navigation wrapper that currently preloads detail before push

---

## Key ambiguities to check before coding

## 1. Are there already multiple history or detail pipelines?
We need to verify whether:
- History tab detail path
- End Game detail path

already use different loaders.

If yes, Phase 11 should reduce that split, not deepen it.

---

## 2. What does the match card currently consume?
If the card currently expects the full match or detail model, we need to decide whether to:
- overload it for `MatchSummary`
- wrap `MatchSummary` in a small card view model
- or adapt card-specific fields in the view layer

This is probably the main UI refactor point.

---

## 3. Where is local vs remote merge happening?
If local and remote matches are merged into a single list today, confirm whether:
- both should use summary models
- or only remote or Supabase matches are being optimized first

### Recommendation
Keep the list layer consistent and use summary-level objects for both if practical.

---

## 4. Does any card logic depend on throw data?
If any card stats are secretly derived from `match_throws`, that breaks the lazy-load boundary.

We should identify and remove that dependency before switching the list path.

---

## 5. Does the detail screen assume eager data?
If `MatchDetailView` assumes full detail is present at init time, it will need:
- a loading state
- async load on appear or task
- or a wrapper detail container view

---

## Recommended coding order

1. Trace current list fetch and detail fetch paths
2. Identify all views currently consuming the full model
3. Add `MatchSummary`
4. Add `fetchMatchSummaries(...)`
5. Switch History tab list to summaries
6. Update card tap navigation to pass `matchId`
7. Add detail cache in service layer
8. Update detail screen to fetch lazily
9. Verify End Game path also uses shared full-detail loading
10. Regression test list, detail, revisit, and remote/local history behavior

---

## Verification checklist

## Performance and query behavior
- [ ] History tab no longer fetches `match_throws`
- [ ] History list only queries `matches` summary columns
- [ ] History tab load time stays stable as match count grows

## UI behavior
- [ ] Match card UI looks unchanged
- [ ] Match detail UI looks unchanged
- [ ] Detail shows loading state when fetched on demand
- [ ] Reopening a previously viewed detail is instant

## Functional behavior
- [ ] Remote matches still render correctly in cards
- [ ] Local matches still render correctly in cards
- [ ] End Game -> match detail still works
- [ ] History tab -> match detail still works
- [ ] Cache returns correct data and does not show stale wrong-match content

---

## Success criteria

This phase is complete when:

- the History tab uses lightweight summaries only
- full throw-level detail is fetched only on detail open
- revisiting a detail uses cache
- existing card and detail UI remain unchanged
- both History-tab and End-Game detail flows still behave correctly

---

## Recommended implementation note for coworker review

This should be treated as a safe architectural split, not a rewrite.

The core principle is:

- list = summary
- detail = full model
- detail fetch = lazy plus cached

That gives the performance improvement without destabilizing the UI or replacing the existing detail pipeline.
