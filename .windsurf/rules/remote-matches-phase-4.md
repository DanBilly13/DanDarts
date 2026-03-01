---
trigger: manual
---
# Phase 4 — Real Gameplay Integration (Remote 301/501 GameView)

## Goal
Replace the temporary RemoteGameplayPlaceholderView with the **real** gameplay UI by **duplicating the existing local 301/501 GameView and adapting it for remote**.

This phase focuses on:
- Correct remote turn flow (server-authoritative)
- Correct UI lockout and “saving” states
- Correct **player identity colors** (Player 1 = Red, Player 2 = Green) persisting into results
- Correct **player-card rotation** behavior (current player card at the front)

## What we already have (pre-reqs)
- Phase 2: deterministic fetch + state rendering
- Phase 3: realtime-as-signal + flow-gate so list reloads don’t interfere with Lobby/Gameplay
- Remote flow navigation is stable (Lobby → Gameplay push works and doesn’t get interrupted)

## Critical Design Rules

### Identity (static)
- **Player 1 = Red**
- **Player 2 = Green**
- These colors must remain consistent throughout:
  - Gameplay player cards
  - “Saving…” / “Opponent is throwing…” overlays
  - EndGame + MatchDetail stats visuals

> In remote matches: **Challenger = Player 1 (Red)**, **Receiver = Player 2 (Green)**.

### Turn indicator (dynamic)
- “Whose turn” is indicated by **which player card is at the front**.
- The cards **rotate** when the server switches `currentPlayerId`.

### Server is authoritative
- Clients do not decide state.
- Realtime events are not trusted payloads — they only trigger `fetchMatch(matchId)`.

---

## Visual Spec (Gameplay Columns)
Use the provided “Section 3” image as the truth source.

- **Top row** = Player A device view  
- **Bottom row** = Player B device view  
- **Each column** = both devices at the **same moment** in the match

Gameplay states to support (as shown in the columns):

1) **Active player is throwing**
- Active player: board enabled + can enter darts
- Inactive player: board disabled/dimmed + sees overlay “{Opponent} is throwing”

2) **Active player enters darts**
- Darts input updates “20 20 20 = 60” (example)
- Save button becomes available

3) **Saving visit**
- After tapping Save:
  - Show a “Saving {Player}’s visit” state
  - Disable interaction for both players until server response returns
  - Once server confirms, briefly show the scored visit to both players

4) **Reveal window**
- Both devices show “Scored: X” / “Last visit: X”
- Duration: ~1–2 seconds (same as local design intent)

5) **Turn switches**
- Cards rotate so the next player is now at the front
- Active player board becomes enabled, inactive becomes dimmed

---

## Implementation Plan (Duplicate + Adapt, no rewrite)

### Step 1 — Duplicate the correct local screen
**Do not rebuild from screenshots.**  
Duplicate the existing local 301/501 GameView + its ViewModel (whatever your local implementation uses).

**Verify it’s the right one:**
- It already supports:
  - card rotation animation
  - darts keypad + visit calculation
  - save flow UI states
  - endgame navigation

Create:
- `RemoteGameView301.swift` (or `RemoteGameView.swift` that supports both 301/501)
- `RemoteGameViewModel.swift` (adapted from local)

### Step 2 — Define the Remote “Game State Adapter”
We need a clean mapping between:
- Remote backend match object (authoritative state)
- Local game UI expectations (scores, current player, last visit display, etc.)

Create a small adapter layer (structs / helper methods) so the remote view model can produce:

- `player1Display` (red) + `player2Display` (green)
- `player1Score`, `player2Score`
- `isPlayer1Turn` / `isPlayer2Turn` (based on `currentPlayerId`)
- `lastVisitValue` (from backend `lastVisitPayload` or equivalent)
- `isSaving` (local UI state while save RPC is in flight)
- `canInteract` (active player only, and not saving)

This keeps the UI identical to local, while the “source of truth” is remote.

### Step 3 — Turn lockout rules (must match visuals)
On each device:
- If **current user is active player**:
  - board enabled unless `isSaving == true`
- If **current user is not active**:
  - board disabled/dimmed
  - show overlay: “{Opponent} is throwing” + “Last visit: X”

### Step 4 — Save Visit (server-authoritative)
Replace local “save visit updates local state” with:

1) Build visit payload from local UI inputs
2) Call server RPC / Edge Function: `save-visit(match_id, payload)`
3) Server validates:
   - correct player
   - match in progress
   - prevents double-submit
   - updates scores
   - sets `lastVisitPayload`
   - switches `currentPlayerId`
4) Client handling:
   - set `isSaving = true` immediately
   - await response
   - on success:
     - set `isSaving = false`
     - trigger `fetchMatch(matchId)` (or rely on the realtime-triggered fetch)
     - run reveal window + rotation
   - on failure:
     - set `isSaving = false`
     - show an error toast/banner
     - keep UI consistent (no local score mutation)

### Step 5 — Rotation + reveal timing (must not be missed)
This was missed in the last failed attempt.

Required behavior:
- After server ack + updated match fetched:
  1) show the scored visit to both players (1–2s)
  2) rotate the player cards
  3) enable the next player’s input

Implementation hint:
- Don’t rotate purely on button tap.
- Rotate when `currentPlayerId` changes in fetched match state.
- Use a “reveal gate” so the UI doesn’t instantly flip without showing the scored visit.

### Step 6 — Replace the placeholder view
Once RemoteGameView works:
- Replace `RemoteGameplayPlaceholderView` usage in the router destination with the new RemoteGameView.
- Keep the FlowGate calls (enter/exit remote flow) exactly as-is.

### Step 7 — End-of-match routing (reuse existing)
When backend match becomes `completed`:
- Navigate to existing EndGameView
- Then to existing MatchDetailView
- Ensure color mapping persists:
  - Player 1 remains red bars/labels
  - Player 2 remains green bars/labels

---

## Acceptance Criteria (Phase 4 is complete when)
1) **Both devices show correct turn lockout**
- Active player can enter darts and Save
- Inactive player is dimmed and cannot interact

2) **Cards rotate with the current player at the front**
- Rotation happens after server-confirmed turn switch

3) **Scoring updates on both devices**
- After Save, both devices show the new score
- “Saving…” state appears and then clears

4) **Realtime + fetch stays stable**
- No navigation interference
- No list reloads during gameplay
- Active match stays fresh

5) **Identity colors are consistent**
- Player 1 red, Player 2 green
- Same mapping is used in MatchDetailView

---

## Logging (required for debugging)
Add logs at:
- GameView init/deinit
- ViewModel init/deinit
- onAppear/onDisappear
- Save Visit start/finish (matchId, userId, visit summary)
- Match fetch results (status, currentPlayerId, scores, lastVisit)
- Turn change detection (old → new currentPlayerId)
- Rotation start/end

---

## Notes / Non-goals for this phase
- Do NOT add push notifications yet
- Do NOT do reconnect hardening beyond what already exists
- Do NOT implement edge cases beyond basic “server rejected save” handling
- Focus on the single happy path:
  - A creates → B accepts → both join → in progress → save visit → turn switches → UI updates

