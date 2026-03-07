---
trigger: always_on
---

# DanDart — current-context-remote-matches-phase-6

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).
It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations (challenge → lobby → gameplay)

Current focus is **Remote Matches**.

---

## Current focus: Remote Matches (Phase 6)

### Phase 6 Goal: Remote Match History (reuse local system)
We already have a fully working match history + match detail flow for local 301/501 games:
- Local end-game view has a button/link to open match details immediately
- Match detail can also be viewed from the History tab

Remote match history should:
- Reuse the existing local history + detail views/models **where possible**
- Or create a remote version that mirrors local behavior and UI exactly

### Status
- Remote gameplay stability work (Phase 5) is considered complete enough to proceed.
- Remote match completion now produces terminal state and player_scores reliably (decoding fixed).

### Primary requirements (Phase 6)
1) **Remote GameEnd → “View match details”**
   - Must open the match detail immediately (same UX as local).
   - Must NOT auto-navigate to the Remote Games tab.
   - Navigation should match local behavior: user chooses when to leave/end.

2) **History tab integration**
   - Remote completed matches appear in the History tab (or Remote History section), consistent with local.
   - Tapping a history row opens the same match detail view used by local (preferred).
   - Remote matches should be clearly labeled as Remote (if needed) but UI structure stays the same.

3) **Data parity with local match detail**
   Remote match detail must support the same fields local uses (or provide sensible fallbacks):
   - opponent(s), winner, final scores
   - ended reason, ended_at
   - match type (301/501), format (legs/sets if applicable)
   - optional: per-turn timeline later

### Key design decision (important)
Prefer a single unified “Match History / Match Detail” system:
- Either make remote matches produce a record compatible with the existing local history storage/model
- Or introduce a thin adapter layer so remote data can be displayed by the same UI without duplicating the UI.

Avoid duplicating the match detail UI unless unavoidable.

### Implementation strategy (recommended order)
1) Identify what local history/detail consumes (model + storage + navigation contract).
2) Create a Remote → LocalHistory adapter/mapping (or write remote matches into the same history store).
3) Wire Remote GameEnd “View details” to open the detail screen without changing tabs.
4) Add remote matches to History tab list with correct filtering and ordering.
5) Ensure realtime completion updates cause history to appear quickly (no stale/empty).

### Known issue to fix in this phase
- Remote end-of-game currently auto-navigates back to Remote Games tab (and it’s empty).
- This must be removed: only user action should change tabs.

### Where to look first (code pointers)
- Local match history pipeline: history store, history tab, match detail view, and local end-game link
- Remote game end / navigation: RemoteGameplayView → game end route → onBack handler
- RemoteMatchService: terminal match handling + loading matches (and history list queries if used)

### Reference docs (load only if needed)
- .windsurf/reference/remote-matches/remote-matches-frd-v2.md
- .windsurf/reference/remote-matches/remote-matches-task-list-v2.md