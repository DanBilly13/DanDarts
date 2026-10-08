# Cricket: Cut-Throat option — Design

**Date:** 2026-10-08
**Status:** Draft for review (iOS first, then Android)

## Goal

Add **Cut-Throat** as a scoring option inside Cricket. Standard Cricket with three
or four individual players lets the leader run away. In Cut-Throat, points are bad:
overflow marks give points to opponents, and the lowest score wins. This is the usual
format for 3–4 players. It is an option on the Cricket setup screen, not a separate
game.

## Decisions (agreed in discussion)

| Decision | Choice | Why |
|---|---|---|
| Where | **Option inside Cricket**, "Scoring": Standard (default) / Cut-Throat. | Same board, keypad and saved data; only the scoring differs. |
| Player count | **Always selectable**, no hint, including with 2 players. | With 2 players it is Standard turned upside down; harmless, and setup stays free of player-count logic. |
| Instructions | Cricket's instruction text gets a Cut-Throat paragraph. | Players read it from the game card and the in-game menu. |
| Standard rules | **Unchanged.** | No regression risk. |
| Teams, 5–6 players | Out of scope. | Neither app has a team concept. |
| Order | iOS first, then Android. | Same as every game so far. |

## Rules (engine)

Everything in the Cricket spec holds (marks, closing, dead targets, three darts per
visit, one dart per undo) except the following, which apply only when the scoring is
Cut-Throat.

- **Scoring.** A mark beyond the third on a target you have closed is overflow. The
  overflow's points (overflow × target value) are added to **each opponent who has
  not closed that target**. The thrower gets nothing. If every opponent has closed
  it, the target is dead and nothing is scored.
- **Winning.** After each dart, a player wins if they have closed all seven targets
  **and** their points are **less than or equal to** every opponent's. The check is
  made for **every** player, not only the thrower.
- **Several qualifying at once.** The thrower wins, otherwise the first in throwing
  order.
- **Why every player is checked.** Points only rise. Suppose Anna closes everything
  while Ben is still lower, so she does not win. Ben is then fed points past her and
  closes last, so he does not win either. Every target is dead and nobody can
  score, so with a thrower-only check the game would never end. Checking every
  player after each dart makes Anna win the moment Ben passes her.
- **Placements.** Winner 1st, then most targets closed, then **fewest** points, then
  throwing order. (Standard: most points.)

Engine surface: `CricketEngine.apply(dart:to:)` gains a scoring-mode parameter
(`CricketScoring.standard` / `.cutThroat`); `CricketState` carries it so undo
snapshots stay consistent. `CricketOutcome.pointsScored` keeps its meaning: the
overflow points the dart generated. In Cut-Throat the state change is to the
opponents' totals.

## Setup

- `CricketSetupConfig`: `showOptions = true`, label "Scoring", two options
  (Standard, Cut-Throat), default Standard. The selection is the `matchFormat`:
  **1 = Standard, 2 = Cut-Throat**. Standard stays 1, so every Cricket match already
  saved reads correctly.
- `darts_games.json` gets this paragraph at the end of Cricket's instructions:

> Cut-Throat.
> Points are bad, so the lowest score wins. When you hit a number you have already closed, the points go to every opponent who has not closed it, not to you. Close all seven numbers while your points are equal to or lower than every opponent's.

## Game screen

Same board and keypad. A small "Cut-Throat" tag sits under the "Cricket" title so
players remember that lower is better. Nothing else changes: points still show under
each avatar.

## Data and history

- **Match format.** `matchFormat` (1 or 2) is passed through the existing save path
  and stored in `matches.match_format`. No schema change.
- **`cricket_darts`** is unchanged (target, marks, marks_added, points per dart), so
  both apps keep reading each other's matches.
- **Rebuilding the board in Cut-Throat.** Per-dart `points` is the overflow's points.
  The recipients are found by replaying the match: visits in turn order, darts in
  order, and for each dart with points, every opponent whose marks on that target are
  below 3 at that moment gets them. Standard keeps the current sum.
  `buildCricketBoards` therefore takes the visits in turn order, plus the scoring
  mode.
- **Detail screen.** Shows a "Cut-Throat" tag, and ranks by fewest points. Matches
  with `matchFormat` 1, missing, or any other value are Standard.
- **Final scores.** Each player's saved final score is their final points, as now.
- **Older app versions.** A version without this change reads a Cut-Throat match as
  Standard, so its History detail would show points on the wrong players. This is a
  display issue only; no data is lost or changed. Fix: update the app.

## Testing

- **`CricketEngineTests`** (Cut-Throat cases): overflow goes to each open opponent
  and not the thrower; closed opponents get nothing; dead target scores nothing;
  treble overflow amounts; win needs all closed and points ≤ everyone's; equal points
  win; closed-but-higher keeps playing; the stuck case above ends with the earlier
  closer winning once the other passes them; thrower-first tie-break; 2, 3 and 4
  players. Standard cases stay as they are.
- **`CricketMatchDataTests`:** the replay rebuilds the final board for Cut-Throat;
  Standard rebuild unchanged; `matchFormat` other than 2 is Standard.
- **`CricketViewModelTests`:** undo restores the opponents' points exactly; the saved
  payload carries `matchFormat` 2.
- **`CricketCatalogTests`:** the instruction text contains the Cut-Throat paragraph.
- Manual: a full 3-player Cut-Throat game on the simulator, then the saved match in
  History (board, tag, ranking), and a check that `matches.match_format` is 2.

## Rollout

1. iOS on `feature/cricket-cut-throat`; PR into `test-flight` when asked.
2. Android on `feature/cricket-cut-throat` off `master`, following the Android
   Cricket spec, then a `versionCode` bump when asked.

## Out of scope

Teams, a board for 5–6 players, new sounds or animations, a player-count hint,
changes to Standard.
