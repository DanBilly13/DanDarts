# Cricket (Tactics) — Design

**Date:** 2026-10-04
**Status:** Draft for review (iOS first; Android port is a separate plan afterwards)

## Goal

Add Cricket, also called Tactics, as a new local game for 2–4 players. It
replaces the unfinished "English Cricket" stub, which is hidden today. The rules
come from `CRICKET.txt`. The game screen reuses Dart Freak's existing visual
language, with Killer's per-player columns as the model.

## Decisions (agreed in discussion)

| Decision | Choice | Why |
|---|---|---|
| English Cricket | **Replaced** by Cricket. Its catalog entry, hide-filter and mock data go. | It was never shipped and is a different game (batter and bowler). |
| Players | **2–4**, no teams. | Columns stay readable. Teams can come later. |
| Keypad | **Cricket-only keypad**: 20, 19, 18, 17, 16, 15, 25, Bull, Miss, delete. | The normal grid has 1–14 buttons that can never matter. |
| Platforms | **iOS first**, then an Android port. | Same order as auto-save. |
| Remote play | **Out of scope.** | Remote has its own server turn-lock and visit save path. |

## Rules (the engine)

Scoring numbers are the seven **targets**: 20, 19, 18, 17, 16, 15 and the bull.

- **Marks.** A single is 1 mark, a double 2, a treble 3. The bull is a single
  for the outer bull (25) and a double for the inner bull (50), so inner bull =
  2 marks. The bull has no treble. The engine stores at most 3 marks per target;
  the overflow becomes points (see Scoring).
- **Closing.** A player closes a target with their third mark. Marks beyond
  three on that dart carry on as scoring (a treble 20 on an open 20 closes it,
  no points; a treble 20 with 2 marks already on it takes 1 mark to close and the other 2 score, so it adds 40).
- **Scoring.** A mark beyond the third scores the target's value (20 for 20, 25
  for the bull) **only while at least one opponent has not closed that target**.
  Once every player has closed a target it is **dead**: no marks, no points.
- **Winning.** After each dart, the thrower wins if they have closed all seven
  targets **and** their points are **greater than or equal to every opponent's**.
  Equal points win, as in the source rules. Checking after every dart means the
  winning dart ends the visit immediately.
- **Never stuck.** A player who closes everything while behind on points keeps
  playing and can still score on any target an opponent has left open. The
  game always ends, because anyone who has not closed everything can do so, and
  the first player who has closed everything and is level or ahead wins.
- **Turns.** Three darts per visit, then play passes round in a fixed order. The
  order is a plain shuffle at game start, like Knockout and Sudden Death.
  Visits are not scored as totals: the unit is the single dart.
- **Miss.** A miss records no marks. It still uses one of the three darts.
- **Winning dart ends the game.** A visit with fewer than three darts is a
  complete visit if the dart won the game.

Engine surface (pure, no SwiftUI), `CricketEngine`:

```swift
enum CricketTarget: CaseIterable { case twenty, nineteen, eighteen, seventeen, sixteen, fifteen, bull }
struct CricketState { marks: [UUID: [CricketTarget: Int]], points: [UUID: Int],
                      currentPlayerIndex, dartsThrown, winnerId: UUID? }
static func apply(dart: CricketDart, to state: CricketState) -> (CricketState, [CricketEvent])
```

`CricketDart` is a target (or miss) plus a multiplier. Events drive sounds and
animation: `markAdded`, `targetClosed(player)`, `pointsScored(player, amount)`,
`targetDead`, `gameWon`.

## Screen

Same structure as Killer: black background, columns in the top half, three dart
slots, then the keypad and **Save Score** in the bottom half.

- **Navigation bar.** Title "Cricket" and the shared `GameplayMenuButton`
  (instructions, auto-save toggle, restart, quit).
- **Player columns.** One column per player (2–4). Each has the avatar in
  `PlayerAvatarWithRing` (coloured ring plus inner black ring on the thrower), the
  first name in the player's colour (`player1`–`player4`), and the player's
  points under it. Column width and spacing follow `PlayerCardLayout`, with a
  new 4-player case sized so the target labels still fit.
- **Target rows.** A narrow label column down the left, 20 to 15 then "B", with
  hairlines between rows. In each player's cell:
  - 1 mark: a slash in the player's colour.
  - 2 marks: an X in the player's colour.
  - Closed: a filled circle in the player's colour with a black X.
- **Dead rows** dim to 30% opacity. Nothing else about the row changes.
- **Dart slots.** The existing `CurrentThrowDisplay(showScore: false)`.
- **Keypad.** `CricketKeypad`: the 20–15 buttons, a green 25 and a red Bull, then
  Miss and delete. A tap is a single; long-press opens the existing multiplier
  menu (double/treble for 20–15, double for the bull, no treble offered). Bull
  and 25 are two buttons because bull = 25 outer / 50 inner: tapping 25 is the
  outer bull (single), tapping Bull is the inner bull (double). Neither opens a
  menu.
- **Save Score.** Appears when the visit is complete (3 darts, or the winning
  dart). Uses `AutoSaveButton`, so auto-save works as in the other local games,
  except that the winning dart never auto-saves.
- **Undo.** The keypad's delete removes the last dart of the current visit. Like
  Killer after its fix, every dart records a snapshot of the whole state, so
  deleting restores marks, points and the thrower exactly. There is no
  cross-visit undo (same as the other local games).

### What this means for the existing components

- `ScoringButtonGrid` is not reused; the keypad is a sibling component using the
  same button style and multiplier menu.
- `GameSetupView` gets a `CricketSetupConfig` (min 2, limit 4 players, no extra
  options) and `Router` gets `.cricketGameplay(game:players:)`, plus the matching
  cases in `==` and `hash`.
- `PreGameHypeView` and the shared game-end flow need no Cricket-specific work.

## Data and history

- **Save path.** `MatchService.saveMatch(gameId: "cricket", ...)`, called the way
  `KillerViewModel.saveMatch()` calls it. `MatchResult.gameType` and
  `gameName` are both `"Cricket"`. The match is local-first and uploads like the
  other local games; Guest handling is unchanged.
- **Per-dart data.** Each dart is saved in `match_throws.game_metadata` as a
  `cricket_darts` JSON string (same pattern as `killer_darts`): target, multiplier,
  marks added, points scored.
- **Match metadata.** `placement_<playerId>` for each player: winner 1st; the
  rest ordered by closed-target count, then points, then throwing order.
- **Stats.** Winners and games played update through the existing
  `MatchSaveRules`. Cricket points are not a score and are kept out of
  ProfileStats. Solo practice is not offered (min 2 players).
- **History.** Cricket gets a filter chip in `MatchHistoryView` (the commented
  `case cricket` is enabled) and a `CricketMatchDetailView` routed from
  `MatchDetailView` on `gameName == "Cricket"`. The detail view is a final board:
  the same columns, marks and points as the game screen, plus placement. Older or
  incomplete metadata falls back to the generic detail view, as Killer does.
- **`MatchCard`.** Cricket is a ranking game (placement from metadata), like
  Killer.

## Catalog

- **iOS** `darts_games.json`: the "English Cricket" entry becomes "Cricket" with
  subtitle "Tactics. Close, Score, Outsmart.", players "2-4", and instructions
  drawn from `CRICKET.txt` (summarised, not pasted). `Game.swift` drops the
  English Cricket hide-filter. `English_Cricket.md` is removed or replaced with
  `Cricket.md`.
- The existing `cricket` cover image is reused.
- `MatchStorageManager` mock data renamed from "English Cricket" to "Cricket".
- `TipBubble` and `SoundManager` are untouched: Cricket uses the existing dart
  hit and miss sounds and the existing win flow. No new sounds or animations.

## Testing

All engine and policy logic is pure and covered by Swift Testing, in the style of
`KillerUndoTests`:

- **`CricketEngineTests`:** single/double/treble marks; closing on the third mark;
  overflow marks scoring when an opponent is open; no points once all have closed;
  bull outer = 1 mark, inner = 2; miss records nothing; 2, 3 and 4 players;
  winning needs all closed AND points ≥ every opponent; equal points wins;
  closed-but-behind keeps playing; dead targets score nothing.
- **`CricketUndoTests`:** delete restores marks, points and turn exactly across a
  closing dart, a scoring dart and the winning dart; delete is disabled once the
  game is won.
- **`CricketPlacementTests`:** placement ordering and tie-breaks.
- **`CricketSaveTests`:** `cricket_darts` payload and placement metadata round-trip.
- Manual: a full 2-, 3- and 4-player game on the simulator, then the saved match
  appears in History with the right detail view. Verify against Supabase that
  `matches`, `match_participants`, `match_players` and `match_throws` all received
  rows.

## Rollout

1. iOS on `feature/cricket`; PR into `test-flight`.
2. Follow-up Android plan in `DartFreak-Android`: port the engine to `:domain`,
   `CricketScreen`, `CricketKeypad`, catalog entry in `games.json`, `GameType.CRICKET`,
   history detail. The Android plan is written after iOS is working.

## Out of scope

- Remote Cricket and teams.
- Variants: cut-throat, no-score, English Cricket.
- New sounds, animations or a Cricket-specific tip.
- Profile stats for Cricket.
- Cross-visit undo.

## Deviations from the first draft (recorded during implementation)

- **Board layout.** A flexible grid with one narrow label column, not `PlayerCardLayout`'s fixed card widths: four 72 pt columns plus the label column do not fit a phone. The avatar shrinks with the player count (64, 56, 48).
- **Keypad buttons.** The keypad reuses the existing circular `ScoringButton`, in the same 5-column grid as the other games (20 19 18 17 16 / 15 25 Bull Miss delete), not the cream rounded squares from the first mockup.
- **Outcome, not events.** The engine returns one `CricketOutcome` per dart (marks added, points, closed, dead, won) instead of an event list. It drives the dart hit and miss sounds only.
- **Overflow example.** A treble on a target with 2 marks adds 1 mark to close and scores the other 2, so 40 on the 20s (the first draft said 20).
- **Engine helpers.** `CricketState.isVisitComplete` and `canThrow` were added after review so the view model does not repeat the "three darts or a win" rule.

## Open items

- **Cover art.** `Assets.xcassets/game-cover/cricket.imageset/cricket.png` is a flat grey placeholder that was already in the project, so the Cricket card on the Games tab, the setup header and the History thumbnail are all grey. It needs real artwork before release.
- **Android.** The port is a separate plan, written once iOS has merged.
