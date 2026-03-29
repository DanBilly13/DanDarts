> Supporting reference for: app-structure  
> Apply when: working on remote match flow, challenge creation, lobby 
> behavior, remote gameplay screens, end game replay, or any task 
> involving the RemoteTab → GameEnd navigation sequence  
> Do not apply to: local game flow, tab-level structure, database 
> schema, or realtime subscription architecture unless it directly 
> affects remote screen state

# Remote Game Flow

## Purpose

This document describes the complete remote match flow in Dart Freak,
from the Remote tab through to end game including replay.

It exists so Windsurf understands what each screen owns, what states
it can be in, and what triggers each transition — before touching any
remote game code.

---

## Flow Summary
```
RemoteTab → RemoteGameSetupView → RemoteLobbyView → RemoteGameplayView → EndGameViewRemote
```

RemoteTab is also the entry point for accepting challenges directly
into RemoteLobbyView, bypassing RemoteGameSetupView.

---

## Screen 1 — RemoteTab (RemoteGamesTab)

### What it owns
- Pending, sent, ready, and active match lists
- Notification and voice chat permission requests
- Supabase realtime subscription for live updates
- Frozen snapshot management to prevent race conditions during navigation

### States
- Loading — initial data load, permission requests
- Idle — displaying match lists with live updates
- Navigating — user selected a match or challenge
- Updating — realtime subscription triggered list refresh

### Key state
```swift
@Published var pendingChallenges: [RemoteMatchWithPlayers] = []
@Published var sentChallenges: [RemoteMatchWithPlayers] = []
@Published var readyMatches: [RemoteMatchWithPlayers] = []
@Published var activeMatch: RemoteMatchWithPlayers?
@State private var frozenSnapshot = false
```

### Transition triggers
- Challenge button → game selection alert → `RemoteGameSetupView`
- Accept challenge → `RemoteLobbyView`
- Tap active match → `RemoteGameplayView`
- Realtime update → automatic list refresh

---

## Screen 2 — RemoteGameSetupView

### What it owns
- Opponent selection from friends list
- Match configuration (game type, match format)
- Challenge creation API call
- Loading and error state

### States
- Selecting — choosing opponent
- Configuring — setting match format
- Creating — sending challenge to server
- Success — challenge created, returning to RemoteTab
- Error — challenge failed, showing error

### Key state
```swift
@State private var selectedOpponent: User?
@State private var selectedMatchFormat: Int = 0
@State private var isCreating = false
@State private var errorMessage: String?
```

### Transition triggers
- Send Challenge → API call → return to RemoteTab (appears in sent 
challenges)
- Cancel → return to RemoteTab

---

## Screen 3 — RemoteLobbyView

### What it owns
- Player presence and lobby readiness state
- Voice chat connection setup
- Countdown timing
- Automatic navigation to gameplay when ready

### Lobby phases
```swift
enum LobbyPhase {
    case waiting      // waiting for both players
    case connecting   // voice window active (< 20s)
    case timedOut     // deadline passed, countdown imminent
    case countdown    // match countdown active
}
```

### States
- Waiting — both players not yet joined
- Connecting — voice window active (20 second window)
- Timed Out — voice deadline passed, waiting for countdown
- Countdown — match countdown active (3–10 seconds)
- Transitioning — navigating to gameplay

### Key state
```swift
@State private var showMatchStarting = false
@State private var isTransitioningToGameplay = false
@State private var hasReportedVoiceReady = false
@State private var voiceWindowTimer: Timer?
```

### Transition triggers
- Countdown completes → auto-navigate to `RemoteGameplayView`
- Cancel → return to RemoteTab
- Realtime update → automatic state update

---

## Screen 4 — RemoteGameplayView

### What it owns
- Server-authoritative game state via `RemoteGameViewModel`
- Realtime sync via `RemoteGameSyncManager`
- Opponent score reveal animation via `RemoteScoreAnimationHandler`
- Turn management via `RemoteTurnRevealState`
- Ongoing voice chat

### States
- Initializing — setting up game state and realtime connection
- Playing — active turn-based gameplay
- Waiting — waiting for opponent's turn
- Revealing — opponent score reveal animation (1–2 seconds)
- Scoring — processing local throws, syncing to server
- Game End — winner detected, transitioning out

### Key state
```swift
@StateObject private var gameViewModel: RemoteGameViewModel
@StateObject private var syncManager: RemoteGameSyncManager
@StateObject private var revealState: RemoteTurnRevealState
@State private var isNavigatingToGameEnd = false
```

### Live match resolution
```swift
private var liveMatch: RemoteMatch? {
    if let fm = remoteMatchService.flowMatch, fm.id == matchId {
        return fm
    }
    return remoteMatchService.activeMatch?.match
}
```

`flowMatch` takes priority over `activeMatch` when IDs match.

### Transition triggers
- `gameViewModel.winner != nil` → navigate to `EndGameViewRemote`
- Server updates match status → automatic navigation
- Cancel → return to RemoteTab

---

## Screen 5 — EndGameViewRemote

### What it owns
- Winner celebration and trophy animation
- Final scores and match statistics
- Replay/rematch creation and overlay state
- Navigation options

### States
- Celebrating — winner reveal with animations
- Displaying — showing final results
- Creating Replay — setting up rematch
- Navigating — user selected next action

### Key state
```swift
@State private var showCelebration = false
@State private var showReplayOverlay = false
@State private var replayMatchId: UUID?
@State private var isCreatingReplay = false
```

### Replay card state
```swift
private var replayCardState: CardPresentationState? {
    guard let match = replayMatch else { return nil }
    switch match.status {
    case .pending: return iAmChallenger ? .sent : .pending
    case .ready: return .ready
    case .lobby: return .lobby
    default: return nil
    }
}
```

### Transition triggers
- Back to Games → return to RemoteTab
- Create Replay → create new challenge with same players
- View Details → match details view
- Replay state changes → navigate back to lobby/gameplay

---

## Data Flow Through the Screens

| Handoff | Data Passed |
|---------|-------------|
| RemoteTab → RemoteGameSetupView | preselected opponent (optional) |
| RemoteGameSetupView → RemoteTab | challenge created (shown in sent list) |
| RemoteTab → RemoteLobbyView | match object |
| RemoteLobbyView → RemoteGameplayView | match id + game config |
| RemoteGameplayView → EndGameViewRemote | winner + match result |
| EndGameViewRemote → RemoteTab | back / replay signal |

---

## Remote-Specific Architecture Notes

### Frozen snapshots
`frozenSnapshot` on RemoteTab prevents live updates during navigation
to avoid race conditions while the user is transitioning into a flow.

### Flow match tracking
`remoteMatchService.flowMatch` tracks the match currently being
navigated into. It takes priority over `activeMatch` in gameplay.

### Duplicate prevention
Guards exist against multiple simultaneous start-match calls.
Do not remove these.

### Replay system
Replay creates a new challenge with the same two players.
It re-enters the full remote lifecycle from the beginning.
It is not a continuation of the completed match.

---

## Bottom Line

Remote flow is a five-screen sequence with server-authoritative state
at every stage.

Each screen owns its local UI state.
Server truth drives lifecycle transitions.
Router owns navigation execution.
Realtime is a trigger, not a source of truth.