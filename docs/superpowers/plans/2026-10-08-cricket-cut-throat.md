# Cricket Cut-Throat (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Scoring: Standard / Cut-Throat" option to Cricket, where overflow points go to the opponents and the lowest score wins.

**Architecture:** `CricketScoring` (raw value = the saved `matchFormat`: 1 Standard, 2 Cut-Throat) lives on `CricketState`, so the pure `CricketEngine` branches on it and undo snapshots stay consistent. The setup selection travels as the existing `matchFormat` through `GameParameters` → `PreGameHypeView` → `Router.cricketGameplay` → `CricketViewModel`. History rebuilds the Cut-Throat board by replaying the saved darts in turn order. Standard code paths are not changed.

**Tech Stack:** Swift, SwiftUI, Swift Testing (`@Test`, `#expect`), `xcodebuild`.

**Spec:** `docs/superpowers/specs/2026-10-08-cricket-cut-throat-design.md`

**Working directory for every command:** `/Users/dan/Projects/DanDarts-worktrees/cut-throat` (branch `feature/cricket-cut-throat`). Never touch `/Users/dan/Projects/DanDarts` (the user's Xcode folder).

**Test command** (used throughout; replace the filter):

```bash
xcodebuild test -project DanDart.xcodeproj -scheme DanDart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DanDartTests/CricketCutThroatEngineTests 2>&1 | tail -25
```

Expected on success: `** TEST SUCCEEDED **`. New `.swift` files under `DanDart/` and `DanDartTests/` are picked up automatically (synchronized folders), so the project file is not edited.

## File structure

| File | Change |
|---|---|
| `DanDart/Models/Cricket/CricketEngine.swift` | `CricketScoring`; `scoring` on `CricketState`; Cut-Throat scoring, win check and placements |
| `DanDart/Models/Cricket/CricketMatchData.swift` | `CricketBoardBuilder.build(players:scoring:)` replays darts for Cut-Throat |
| `DanDart/ViewModels/Games/CricketViewModel.swift` | takes `scoring`; saves `matchFormat` |
| `DanDart/Views/GameSetup/GameSetupOptions/CricketSetupConfig.swift` | "Scoring" segmented option |
| `DanDart/Views/Games/Shared/PreGameHypeView.swift` | passes `matchFormat` on to Cricket |
| `DanDart/Services/Router.swift` | `cricketGameplay` gains `matchFormat` |
| `DanDart/Views/Games/Cricket/CricketGameplayView.swift` | takes `matchFormat`; "Cut-Throat" tag; Play Again keeps the variant |
| `DanDart/Views/History/CricketMatchDetailView.swift` | scoring from `match.matchFormat`; tag; ranking |
| `DanDart/documents/gameText/darts_games.json` | Cut-Throat paragraph |
| `DanDartTests/CricketCutThroatEngineTests.swift` | new |
| `DanDartTests/CricketMatchDataTests.swift`, `CricketViewModelTests.swift`, `CricketCatalogTests.swift` | new cases |

---

### Task 1: Engine — scoring mode, Cut-Throat scoring, win check, placements

**Files:**
- Modify: `DanDart/Models/Cricket/CricketEngine.swift`
- Create: `DanDartTests/CricketCutThroatEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DanDartTests/CricketCutThroatEngineTests.swift`:

```swift
//
//  CricketCutThroatEngineTests.swift
//  DanDartTests
//
//  Cut-Throat Cricket: overflow points go to the opponents, lowest score wins.
//

import Foundation
import Testing
@testable import DanDart

struct CricketCutThroatEngineTests {

    // MARK: - helpers

    private func game(_ playerCount: Int = 3) -> (state: CricketState, ids: [UUID]) {
        let ids = (0..<playerCount).map { _ in UUID() }
        return (CricketState(playerIds: ids, scoring: .cutThroat), ids)
    }

    private func throwDart(_ state: CricketState, _ target: CricketTarget?, _ marks: Int)
        -> (state: CricketState, outcome: CricketOutcome) {
        CricketEngine.apply(CricketDart(target: target, marks: marks), to: state)
    }

    private func close(_ state: inout CricketState, _ id: UUID,
                       targets: [CricketTarget] = CricketTarget.allCases) {
        for target in targets { state.markCounts[id]![target] = 3 }
    }

    private let everythingButTwenty: [CricketTarget] = [.nineteen, .eighteen, .seventeen, .sixteen, .fifteen, .bull]

    // MARK: - scoring mode

    @Test func scoringIsStandardByDefault() {
        let state = CricketState(playerIds: [UUID(), UUID()])
        #expect(state.scoring == .standard)
    }

    @Test func scoringMatchesTheSavedMatchFormat() {
        #expect(CricketScoring.standard.matchFormat == 1)
        #expect(CricketScoring.cutThroat.matchFormat == 2)
        #expect(CricketScoring(matchFormat: 2) == .cutThroat)
        #expect(CricketScoring(matchFormat: 1) == .standard)
        #expect(CricketScoring(matchFormat: 0) == .standard)
        #expect(CricketScoring(matchFormat: 7) == .standard)
    }

    // MARK: - scoring

    @Test func overflowGoesToEachOpenOpponentAndNotTheThrower() {
        var g = game(3)
        close(&g.state, g.ids[0], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 1)

        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 20)
        #expect(r.state.points(for: g.ids[2]) == 20)
        #expect(r.outcome.pointsScored == 20)
        #expect(r.outcome.marksAdded == 0)
    }

    @Test func opponentsWhoHaveClosedTheTargetGetNothing() {
        var g = game(3)
        close(&g.state, g.ids[0], targets: [.twenty])
        close(&g.state, g.ids[1], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 2)

        #expect(r.state.points(for: g.ids[1]) == 0)
        #expect(r.state.points(for: g.ids[2]) == 40)
        #expect(r.state.points(for: g.ids[0]) == 0)
    }

    @Test func nothingScoresOnADeadTarget() {
        var g = game(3)
        for id in g.ids { close(&g.state, id, targets: [.twenty]) }
        let r = throwDart(g.state, .twenty, 3)

        #expect(g.ids.allSatisfy { r.state.points(for: $0) == 0 })
        #expect(r.outcome.pointsScored == 0)
    }

    @Test func aTrebleThatClosesThenOverflowsGivesTheOverflowToOpponents() {
        var g = game(2)
        g.state.markCounts[g.ids[0]]![.nineteen] = 2 // one more mark closes it; two are overflow
        let r = throwDart(g.state, .nineteen, 3)

        #expect(r.state.marks(for: g.ids[0], on: .nineteen) == 3)
        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 38)
        #expect(r.outcome.marksAdded == 1)
        #expect(r.outcome.pointsScored == 38)
    }

    @Test func twoPlayerCutThroatHandsThePointsToTheOtherPlayer() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: [.twenty])
        let r = throwDart(g.state, .twenty, 1)

        #expect(r.state.points(for: g.ids[0]) == 0)
        #expect(r.state.points(for: g.ids[1]) == 20)
    }

    @Test func standardScoringStillCreditsTheThrower() {
        let ids = [UUID(), UUID(), UUID()]
        var state = CricketState(playerIds: ids, scoring: .standard)
        state.markCounts[ids[0]]![.twenty] = 3
        let r = CricketEngine.apply(CricketDart(target: .twenty, marks: 1), to: state)

        #expect(r.state.points(for: ids[0]) == 20)
        #expect(r.state.points(for: ids[1]) == 0)
    }

    // MARK: - winning

    @Test func closingEverythingWhileLowestWins() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[0])
        #expect(r.outcome.won)
    }

    @Test func closingEverythingWithEqualPointsWins() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[0]] = 30
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[0])
    }

    @Test func closingEverythingWhileHigherKeepsPlaying() {
        var g = game(2)
        close(&g.state, g.ids[0], targets: everythingButTwenty)
        g.state.pointTotals[g.ids[0]] = 40
        g.state.pointTotals[g.ids[1]] = 30
        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == nil)
        #expect(r.outcome.won == false)
        #expect(r.state.hasClosedAll(g.ids[0]))
    }

    @Test func aPlayerWhoClosedEarlierWinsOnceTheLowerPlayerIsFedPastThem() {
        // Anna (0) closed everything on 20 points while Ben (1) was on 10, so she did not win.
        // Cara (2) now scores 15 on Ben, who is still open on 15: Ben goes to 25 and Anna is lowest.
        var g = game(3)
        close(&g.state, g.ids[0])
        g.state.pointTotals[g.ids[0]] = 20
        g.state.pointTotals[g.ids[1]] = 10
        g.state.pointTotals[g.ids[2]] = 30
        g.state.markCounts[g.ids[2]]![.fifteen] = 3
        g.state.currentPlayerIndex = 2

        let r = throwDart(g.state, .fifteen, 1)

        #expect(r.state.points(for: g.ids[1]) == 25)
        #expect(r.state.winnerId == g.ids[0])
        #expect(r.outcome.won)
    }

    @Test func theThrowerWinsWhenSeveralPlayersQualifyAtOnce() {
        var g = game(3)
        close(&g.state, g.ids[0])                                     // Anna: closed all, 10 points
        close(&g.state, g.ids[2], targets: everythingButTwenty)       // Cara about to close the last one
        g.state.pointTotals[g.ids[0]] = 10
        g.state.pointTotals[g.ids[1]] = 20
        g.state.pointTotals[g.ids[2]] = 10
        g.state.currentPlayerIndex = 2

        let r = throwDart(g.state, .twenty, 3)

        #expect(r.state.winnerId == g.ids[2])
    }

    // MARK: - placements

    @Test func placementsRankTheWinnerThenMostClosedThenFewestPoints() {
        var g = game(3)
        close(&g.state, g.ids[0])
        g.state.winnerId = g.ids[0]
        close(&g.state, g.ids[1], targets: [.twenty, .nineteen, .eighteen])
        close(&g.state, g.ids[2], targets: [.twenty, .nineteen, .eighteen])
        g.state.pointTotals[g.ids[1]] = 40
        g.state.pointTotals[g.ids[2]] = 10

        let places = CricketEngine.placements(for: g.state)

        #expect(places[g.ids[0]] == 1)
        #expect(places[g.ids[2]] == 2)
        #expect(places[g.ids[1]] == 3)
    }

    @Test func standardPlacementsStillRankMostPointsFirst() {
        let ids = [UUID(), UUID(), UUID()]
        var state = CricketState(playerIds: ids, scoring: .standard)
        state.winnerId = ids[0]
        state.pointTotals[ids[1]] = 10
        state.pointTotals[ids[2]] = 40

        let places = CricketEngine.placements(for: state)

        #expect(places[ids[2]] == 2)
        #expect(places[ids[1]] == 3)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the test command with `-only-testing:DanDartTests/CricketCutThroatEngineTests`.
Expected: build FAILS with "cannot find 'CricketScoring' in scope" / "extra argument 'scoring' in call".

- [ ] **Step 3: Add `CricketScoring` and the `scoring` field**

In `DanDart/Models/Cricket/CricketEngine.swift`, add above `struct CricketState`:

```swift
/// How Cricket is scored. The raw value is what a match saves as `matchFormat`, so every
/// Cricket match saved before this option existed (format 1) reads as Standard.
enum CricketScoring: Int, Equatable {
    case standard = 1
    case cutThroat = 2

    /// Anything other than 2 is Standard.
    init(matchFormat: Int) {
        self = CricketScoring(rawValue: matchFormat) ?? .standard
    }

    var matchFormat: Int { rawValue }
}
```

In `CricketState`, add the stored property after `playerIds` and change the initialiser:

```swift
    /// Throwing order.
    let playerIds: [UUID]
    let scoring: CricketScoring
```

```swift
    init(playerIds: [UUID], scoring: CricketScoring = .standard) {
        precondition(!playerIds.isEmpty && Set(playerIds).count == playerIds.count,
                     "Cricket needs at least one player and no duplicate players")
        self.playerIds = playerIds
        self.scoring = scoring
```
(keep the existing `let empty = …` / `markCounts` / `pointTotals` lines that follow unchanged).

- [ ] **Step 4: Implement Cut-Throat scoring and the win check**

Replace the scoring block and the win block in `CricketEngine.apply` so the middle of the method reads:

```swift
            let openOpponents = state.playerIds.filter {
                $0 != playerId && state.marks(for: $0, on: target) < 3
            }
            if overflow > 0 && !openOpponents.isEmpty {
                let points = overflow * target.pointValue
                outcome.pointsScored = points
                switch state.scoring {
                case .standard:
                    next.pointTotals[playerId, default: 0] += points
                case .cutThroat:
                    for opponent in openOpponents { next.pointTotals[opponent, default: 0] += points }
                }
            }

            outcome.targetBecameDead = outcome.closedTarget && next.isDead(target)
        }

        switch state.scoring {
        case .standard:
            if next.hasClosedAll(playerId) {
                let bestOpponent = state.playerIds
                    .filter { $0 != playerId }
                    .map { next.points(for: $0) }
                    .max() ?? 0
                if next.points(for: playerId) >= bestOpponent {
                    next.winnerId = playerId
                    outcome.won = true
                }
            }
        case .cutThroat:
            if let winner = cutThroatWinner(in: next, thrower: playerId) {
                next.winnerId = winner
                outcome.won = true
            }
        }

        return (next, outcome)
    }

    /// Cut-Throat: the first player (thrower first, then throwing order) who has closed
    /// everything with points at or below every opponent's. Every player is checked, because
    /// points only rise: someone who closed earlier while another player was lower wins the
    /// moment that player is fed past them. Checking only the thrower could leave a game
    /// where every target is dead and nobody can ever win.
    private static func cutThroatWinner(in state: CricketState, thrower: UUID) -> UUID? {
        let candidates = [thrower] + state.playerIds.filter { $0 != thrower }
        return candidates.first { candidate in
            guard state.hasClosedAll(candidate) else { return false }
            let lowestOpponent = state.playerIds
                .filter { $0 != candidate }
                .map { state.points(for: $0) }
                .min() ?? Int.max
            return state.points(for: candidate) <= lowestOpponent
        }
    }
```

Leave `endVisit` unchanged.

- [ ] **Step 5: Implement Cut-Throat placements**

In `placements(for:)` replace the points comparison and update the doc comment:

```swift
    /// 1 for the winner, then by targets closed, then points (most for Standard, fewest for
    /// Cut-Throat), then throwing order.
    static func placements(for state: CricketState) -> [UUID: Int] {
```

```swift
            let leftPoints = state.points(for: lhs.element)
            let rightPoints = state.points(for: rhs.element)
            if leftPoints != rightPoints {
                return state.scoring == .cutThroat ? leftPoints < rightPoints : leftPoints > rightPoints
            }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run the test command for `CricketCutThroatEngineTests`, then again with `-only-testing:DanDartTests/CricketEngineTests` (Standard must still pass).
Expected: both `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add DanDart/Models/Cricket/CricketEngine.swift DanDartTests/CricketCutThroatEngineTests.swift
git commit -m "feat(cricket): Cut-Throat scoring in the engine

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: History board — replay the darts for Cut-Throat

**Files:**
- Modify: `DanDart/Models/Cricket/CricketMatchData.swift` (`CricketBoardBuilder`)
- Modify: `DanDartTests/CricketMatchDataTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `CricketMatchDataTests` (before the final `}`):

```swift
    // MARK: - Cut-Throat board

    @Test func cutThroatPointsLandOnOpponentsWhoWereOpenAtThatMoment() {
        // Round 1: A closes 20, B closes 20. Round 2: A scores 20 on 20 (only C is open),
        // then C closes 20. Round 3: A scores 20 again; nobody is open any more.
        let a = player("A", turns: [
            [dart(20, marks: 3, added: 3)],
            [dart(20, marks: 1, added: 0, points: 20)],
            [dart(20, marks: 1, added: 0, points: 0)]
        ])
        let b = player("B", turns: [
            [dart(20, marks: 3, added: 3)],
            [dart(nil, marks: 0, added: 0)],
            [dart(nil, marks: 0, added: 0)]
        ])
        let c = player("C", turns: [
            [dart(nil, marks: 0, added: 0)],
            [dart(20, marks: 3, added: 3)],
            [dart(nil, marks: 0, added: 0)]
        ])

        let boards = CricketBoardBuilder.build(players: [a, b, c], scoring: .cutThroat)

        #expect(boards[a.id]?.points == 0)
        #expect(boards[b.id]?.points == 0)
        #expect(boards[c.id]?.points == 20)
        #expect(boards[a.id]?.marks(on: .twenty) == 3)
        #expect(boards[c.id]?.marks(on: .twenty) == 3)
    }

    @Test func cutThroatGivesTheSamePointsToEveryOpenOpponent() {
        let a = player("A", turns: [
            [dart(19, marks: 3, added: 3)],
            [dart(19, marks: 2, added: 0, points: 38)]
        ])
        let b = player("B", turns: [[dart(nil, marks: 0, added: 0)], [dart(nil, marks: 0, added: 0)]])
        let c = player("C", turns: [[dart(nil, marks: 0, added: 0)], [dart(nil, marks: 0, added: 0)]])

        let boards = CricketBoardBuilder.build(players: [a, b, c], scoring: .cutThroat)

        #expect(boards[a.id]?.points == 0)
        #expect(boards[b.id]?.points == 38)
        #expect(boards[c.id]?.points == 38)
    }

    @Test func standardBoardStillCreditsTheThrower() {
        let a = player("A", turns: [[dart(20, marks: 3, added: 3), dart(20, marks: 1, added: 0, points: 20)]])
        let b = player("B", turns: [[dart(nil, marks: 0, added: 0)]])

        let boards = CricketBoardBuilder.build(players: [a, b], scoring: .standard)
        let defaultBoards = CricketBoardBuilder.build(players: [a, b])

        #expect(boards[a.id]?.points == 20)
        #expect(boards[b.id]?.points == 0)
        #expect(defaultBoards[a.id]?.points == 20)
    }
```

- [ ] **Step 2: Run to verify failure**

Run the test command with `-only-testing:DanDartTests/CricketMatchDataTests`.
Expected: build FAILS ("extra argument 'scoring' in call").

- [ ] **Step 3: Implement the replay**

In `CricketBoardBuilder`, change `build` and add the Cut-Throat path:

```swift
enum CricketBoardBuilder {
    /// Adds up every saved dart. Keyed by `MatchPlayer.id`. `players` must be in throwing order.
    static func build(players: [MatchPlayer], scoring: CricketScoring = .standard) -> [UUID: CricketPlayerBoard] {
        switch scoring {
        case .standard: return buildStandard(players: players)
        case .cutThroat: return buildCutThroat(players: players)
        }
    }

    private static func buildStandard(players: [MatchPlayer]) -> [UUID: CricketPlayerBoard] {
        var boards: [UUID: CricketPlayerBoard] = [:]
        for player in players {
            var board = CricketPlayerBoard()
            for turn in player.turns {
                for dart in turn.darts {
                    guard let metadata = dart.cricketMetadata else { continue }
                    if let rawTarget = metadata.target, let target = CricketTarget(rawValue: rawTarget) {
                        board.markCounts[target, default: 0] += metadata.marksAdded
                    }
                    board.points += metadata.pointsScored
                }
            }
            boards[player.id] = board
        }
        return boards
    }

    /// Cut-Throat points belong to the opponents who had not closed the target when the dart
    /// was thrown, so the match is replayed in turn order: turn 1 for everyone in throwing
    /// order, then turn 2, and so on. The saved `points` per dart is the overflow's points.
    private static func buildCutThroat(players: [MatchPlayer]) -> [UUID: CricketPlayerBoard] {
        var boards = Dictionary(uniqueKeysWithValues: players.map { ($0.id, CricketPlayerBoard()) })
        let rounds = players.map(\.turns.count).max() ?? 0

        for round in 0..<rounds {
            for player in players where round < player.turns.count {
                for dart in player.turns[round].darts {
                    guard let metadata = dart.cricketMetadata,
                          let rawTarget = metadata.target,
                          let target = CricketTarget(rawValue: rawTarget) else { continue }

                    boards[player.id]?.markCounts[target, default: 0] += metadata.marksAdded

                    guard metadata.pointsScored > 0 else { continue }
                    for opponent in players where opponent.id != player.id {
                        if (boards[opponent.id]?.markCounts[target] ?? 0) < 3 {
                            boards[opponent.id]?.points += metadata.pointsScored
                        }
                    }
                }
            }
        }
        return boards
    }
```

Keep `hasData(in:)` below, unchanged.

- [ ] **Step 4: Run to verify pass**

Run the test command for `CricketMatchDataTests`. Expected: `** TEST SUCCEEDED **` (old and new tests).

- [ ] **Step 5: Commit**

```bash
git add DanDart/Models/Cricket/CricketMatchData.swift DanDartTests/CricketMatchDataTests.swift
git commit -m "feat(cricket): rebuild the Cut-Throat board by replaying saved darts

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: View model — carry the scoring and save `matchFormat`

**Files:**
- Modify: `DanDart/ViewModels/Games/CricketViewModel.swift`
- Modify: `DanDartTests/CricketViewModelTests.swift`

- [ ] **Step 1: Write the failing tests**

Append inside `CricketViewModelTests`:

```swift
    // MARK: - Cut-Throat

    private func makeCutThroatGame() -> (vm: CricketViewModel, a: Player, b: Player) {
        let a = Player(displayName: "A", nickname: "a")
        let b = Player(displayName: "B", nickname: "b")
        let vm = CricketViewModel(players: [a, b], scoring: .cutThroat, shuffle: false, persistsMatch: false)
        return (vm, a, b)
    }

    @Test func aCutThroatGameStartsWithCutThroatScoring() {
        let g = makeCutThroatGame()
        #expect(g.vm.state.scoring == .cutThroat)
    }

    @Test func standardIsTheDefaultScoring() {
        #expect(makeGame().vm.state.scoring == .standard)
    }

    @Test func deletingACutThroatScoringDartTakesTheOpponentsPointsBack() {
        let g = makeCutThroatGame()
        throwDart(g.vm, 20, .triple)
        throwDart(g.vm, 20) // 20 points to B
        #expect(g.vm.state.points(for: g.b.id) == 20)
        #expect(g.vm.state.points(for: g.a.id) == 0)

        g.vm.deleteThrow()

        #expect(g.vm.state.points(for: g.b.id) == 0)
        #expect(g.vm.state.marks(for: g.a.id, on: .twenty) == 3)
    }

    @Test func aFinishedCutThroatGameSavesMatchFormatTwo() {
        let g = makeCutThroatGame()
        playUpToTheWinningDart(g.vm) // A closes everything; B has no points, so A is lowest
        g.vm.completeTurn()

        let payload = g.vm.makeMatchPayload()

        #expect(payload?.matchResult.matchFormat == 2)
    }

    @Test func aFinishedStandardGameStillSavesMatchFormatOne() {
        let g = makeGame()
        playUpToTheWinningDart(g.vm)
        g.vm.completeTurn()

        #expect(g.vm.makeMatchPayload()?.matchResult.matchFormat == 1)
    }
```

- [ ] **Step 2: Run to verify failure**

Run the test command with `-only-testing:DanDartTests/CricketViewModelTests`. Expected: build FAILS ("extra argument 'scoring' in call").

- [ ] **Step 3: Implement**

In `CricketViewModel`:

```swift
    private let scoring: CricketScoring
```
(add beside `persistsMatch`), change the initialiser:

```swift
    init(players: [Player], scoring: CricketScoring = .standard, shuffle: Bool = true, persistsMatch: Bool = true) {
        let order = shuffle ? players.shuffled() : players
        self.players = order
        self.scoring = scoring
        self.state = CricketState(playerIds: order.map(\.id), scoring: scoring)
        self.persistsMatch = persistsMatch
    }
```

and replace both `matchFormat: 1,` occurrences (the `MatchResult(…)` initialiser in `makeMatchPayload` and the `MatchService().saveMatch(…)` call in `saveMatch`) with:

```swift
            matchFormat: scoring.matchFormat,
```
(the `saveMatch` call has the same label with its own indentation; use `matchFormat: scoring.matchFormat,` there too).

- [ ] **Step 4: Run to verify pass**

Run the test command for `CricketViewModelTests`. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/ViewModels/Games/CricketViewModel.swift DanDartTests/CricketViewModelTests.swift
git commit -m "feat(cricket): view model carries the scoring and saves matchFormat

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Setup option and navigation

**Files:**
- Modify: `DanDart/Views/GameSetup/GameSetupOptions/CricketSetupConfig.swift`
- Modify: `DanDart/Views/Games/Shared/PreGameHypeView.swift`
- Modify: `DanDart/Services/Router.swift`
- Modify: `DanDart/Views/Games/Cricket/CricketGameplayView.swift`

- [ ] **Step 1: Replace `CricketSetupConfig`**

Whole file `DanDart/Views/GameSetup/GameSetupOptions/CricketSetupConfig.swift`:

```swift
//
//  CricketSetupConfig.swift
//  Dart Freak
//
//  Configuration for Cricket game setup: 2 to 4 players, Standard or Cut-Throat scoring.
//

import SwiftUI

struct CricketSetupConfig: GameSetupConfigurable {
    let game: Game
    let playerLimit: Int = 4
    let optionLabel: String = "Scoring"
    let defaultSelection: Int = 0 // Standard

    private let scoringOptions: [CricketScoring] = [.standard, .cutThroat]

    func optionView(selection: Binding<Int>) -> AnyView {
        AnyView(
            SegmentedControl(options: [0, 1], selection: selection) { index in
                scoringOptions[index] == .cutThroat ? "Cut-Throat" : "Standard"
            }
        )
    }

    func gameParameters(players: [Player], selection: Int) -> GameParameters {
        GameParameters(game: game, players: players, matchFormat: scoringOptions[selection].matchFormat)
    }
}
```

- [ ] **Step 2: Route the format into gameplay**

`Router.swift`: change the case, equality and hash:

```swift
    case cricketGameplay(game: Game, players: [Player], matchFormat: Int)
```
```swift
        case (.cricketGameplay(let g1, let p1, let m1), .cricketGameplay(let g2, let p2, let m2)):
            return g1.id == g2.id && p1.map(\.id) == p2.map(\.id) && m1 == m2
```
```swift
        case .cricketGameplay(let game, let players, let matchFormat):
            hasher.combine("cricketGameplay")
            hasher.combine(game.id)
            hasher.combine(players.map(\.id))
            hasher.combine(matchFormat)
```
```swift
        case .cricketGameplay(let game, let players, let matchFormat):
            CricketGameplayView(game: game, players: players, matchFormat: matchFormat)
```

`PreGameHypeView.swift`:

```swift
        } else if game.title == "Cricket" {
            router.push(.cricketGameplay(game: game, players: players, matchFormat: matchFormat))
```

- [ ] **Step 3: Update `CricketGameplayView`**

```swift
struct CricketGameplayView: View {
    let game: Game
    let players: [Player]
    let matchFormat: Int
    private let scoring: CricketScoring
```
```swift
    init(game: Game, players: [Player], matchFormat: Int = 1) {
        self.game = game
        self.players = players
        self.matchFormat = matchFormat
        let scoring = CricketScoring(matchFormat: matchFormat)
        self.scoring = scoring
        _viewModel = StateObject(wrappedValue: CricketViewModel(players: players, scoring: scoring))
    }
```

Title with tag (replace the `ToolbarItem(placement: .principal)` content):

```swift
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(game.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.justWhite)
                    if scoring == .cutThroat {
                        Text("Cut-Throat")
                            .font(.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
```

Play Again keeps the variant:

```swift
                        router.push(.preGameHype(game: game, players: players, matchFormat: matchFormat))
```

- [ ] **Step 4: Build**

```bash
xcodebuild build -project DanDart.xcodeproj -scheme DanDart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15
```
Expected: `** BUILD SUCCEEDED **`. If another call site of `.cricketGameplay(` fails to compile, `grep -rn "cricketGameplay(" DanDart DanDartTests` and add `matchFormat:`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/Views/GameSetup/GameSetupOptions/CricketSetupConfig.swift DanDart/Views/Games/Shared/PreGameHypeView.swift DanDart/Services/Router.swift DanDart/Views/Games/Cricket/CricketGameplayView.swift
git commit -m "feat(cricket): Scoring option on setup, carried into the game screen

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: History detail — tag, board and ranking

**Files:**
- Modify: `DanDart/Views/History/CricketMatchDetailView.swift`

- [ ] **Step 1: Derive the scoring and use it for the board and the fallback ranking**

Replace the `boards` property and the fallback in `standings`:

```swift
    private var scoring: CricketScoring { CricketScoring(matchFormat: match.matchFormat) }

    private var boards: [UUID: CricketPlayerBoard] {
        CricketBoardBuilder.build(players: match.players, scoring: scoring)
    }
```
```swift
        return match.players.sorted { lhs, rhs in
            if isWinner(lhs) != isWinner(rhs) { return isWinner(lhs) }
            let left = boards[lhs.id]?.points ?? 0
            let right = boards[rhs.id]?.points ?? 0
            return scoring == .cutThroat ? left < right : left > right
        }
```

- [ ] **Step 2: Show the tag**

In `standingsSection`, replace the "Final standings" `Text` with:

```swift
            HStack {
                Text("Final standings")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.justWhite)
                Spacer()
                if scoring == .cutThroat {
                    Text("Cut-Throat")
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
```

- [ ] **Step 3: Build**

Run the build command from Task 4. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DanDart/Views/History/CricketMatchDetailView.swift
git commit -m "feat(cricket): Cut-Throat tag and ranking in the match detail

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Instructions text

**Files:**
- Modify: `DanDart/documents/gameText/darts_games.json` (Cricket entry)
- Modify: `DanDartTests/CricketCatalogTests.swift`

- [ ] **Step 1: Write the failing test**

Append inside `CricketCatalogTests`:

```swift
    @Test func theInstructionsExplainCutThroat() {
        let cricket = Game.loadGames().first { $0.title == "Cricket" }

        #expect(cricket?.instructions.contains("Cut-Throat.") == true)
        #expect(cricket?.instructions.contains("lowest score wins") == true)
    }
```
(If `Game`'s property is not named `instructions`, run `grep -n "instructions" DanDart/Models/Game.swift` and use the real name.)

- [ ] **Step 2: Run to verify failure**

Run the test command with `-only-testing:DanDartTests/CricketCatalogTests`. Expected: FAIL on the new test.

- [ ] **Step 3: Add the paragraph**

In `darts_games.json`, in the Cricket entry, end the `instructions` string with the existing last sentence followed by the new paragraph (still one JSON string, `\n\n` between paragraphs):

```
...or defend by closing the numbers your opponents are scoring on.\n\nCut-Throat.\nPoints are bad, so the lowest score wins. When you hit a number you have already closed, the points go to every opponent who has not closed it, not to you. Close all seven numbers while your points are equal to or lower than every opponent's."
```

- [ ] **Step 4: Run to verify pass**

Run the test command for `CricketCatalogTests`. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DanDart/documents/gameText/darts_games.json DanDartTests/CricketCatalogTests.swift
git commit -m "docs(cricket): explain Cut-Throat in the instructions

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Full verification

- [ ] **Step 1: Run every Cricket test and the whole suite**

```bash
xcodebuild test -project DanDart.xcodeproj -scheme DanDart \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```
Expected: `** TEST SUCCEEDED **`. Report any failure with its output; do not skip it.

- [ ] **Step 2: Manual check on the simulator**

Build and launch the worktree build on the iPhone 17 Pro simulator. Check:
1. Games → Cricket → setup shows a "Scoring" control, Standard selected; Cut-Throat selectable with 2, 3 and 4 players.
2. Start a 3-player Cut-Throat game: "Cut-Throat" shows under the title; close 20 with a treble, then hit a single 20: the other two players' points go up by 20 and yours does not.
3. Delete that dart: the opponents' points go back.
4. Play to the end; the winner is the player with everything closed and the lowest points. "Play Again" starts another Cut-Throat game.
5. History: the match opens with a "Cut-Throat" tag, the final board shows points on the right players, and standings are fewest-points-first.
6. A Standard game still behaves as before.

If the iOS app has no signed-in user in the simulator, ask the user to sign in first.

- [ ] **Step 3: Check the saved row (user-run SQL)**

Production reads from this session are blocked by the classifier, so give the user this to run in the Supabase SQL Editor after a Cut-Throat game saved while signed in:

```sql
select id, game_name, match_format, created_at
from matches
where game_name = 'Cricket'
order by created_at desc
limit 3;
```
Expected: the newest Cut-Throat match has `match_format = 2`, older ones 1.

- [ ] **Step 4: Report**

Summarise what passed and what was not seen. Do not push or open a PR until the user asks.
