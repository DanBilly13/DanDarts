---
name: app-structure
description: dart freak app structure and screen reference. use when starting a new task, after a context reset, when adding or changing screens, when working on navigation between screens, when debugging unexpected UI behavior in a specific screen, or when unsure where a feature belongs in the app. also use when tasks mention specific screens like RemoteGamesTab, RemoteLobbyView, RemoteGameplayView, GameSetupView, PreGameHypeView, GameEndView, or EndGameViewRemote. do not use for database schema, realtime subscription architecture, or server-side edge function logic unless the question is specifically about how those affect screen state.
---

# App Structure

Use this skill to orient before starting any task that involves screens,
flows, or navigation in Dart Freak.

This is not a rules skill.
It is a map of what exists and where.

## Stack Summary

- Frontend: SwiftUI iOS app, MVVM-light pattern
- Backend: Supabase (PostgreSQL, Auth, Realtime, Edge Functions)
- Navigation: Centralized via `Router.shared` and `MainTabView`
- Local storage: JSON files for local matches and guest players
- Real-time: Supabase subscriptions for remote match updates

## Tab Structure

`MainTabView` hosts four tabs:

| Tag | Tab | Entry Point | Owns |
|-----|-----|-------------|------|
| 0 | Games | `GamesTabView` | Local game launch, remote game creation entry |
| 1 | Friends | `FriendsTabView` | Social, friend requests, guest players |
| 2 | Remote | `RemoteGamesTab` | Online match management, challenges, active games |
| 3 | History | `HistoryTabView` | Past match records, local and cloud |

Badges appear on Friends (pending requests) and Remote (pending 
challenges).

## Local Game Flow
```
GamesTab → GameSetupView → PreGameHypeView → GameplayView → GameEndView
```

Each screen owns its own state and passes data forward.
Router owns all navigation execution.
No screen reaches back into a previous screen's state.

## Remote Game Flow
```
RemoteTab → RemoteGameSetupView → RemoteLobbyView → RemoteGameplayView → EndGameViewRemote
```

RemoteTab also accepts challenges directly into RemoteLobbyView,
bypassing RemoteGameSetupView.

Server truth drives all lifecycle transitions.
Realtime is a trigger, not a source of truth.
Router owns all navigation execution.

## Shared vs Adapted Screens

Some screens exist in both flows with a shared visual foundation
and adapted business logic:

| Local | Remote | Shared | Adapted |
|-------|--------|--------|---------|
| `GameSetupView` | `RemoteGameSetupView` | Layout, hero, scroll | Player model, action, navigation |
| `PreGameHypeView` | `RemoteLobbyView` | Visual structure, animation | State source, voice, lifecycle |
| `GameEndView` | `EndGameViewRemote` | Design, celebration, buttons | Replay features, navigation options |

Gameplay components (`ScoringButtonGrid`, `PlayerCard`,
`CurrentThrowDisplay`) are fully shared with no adaptation.

## Key Remote Screen States

| Screen | Key state drivers |
|--------|------------------|
| `RemoteGamesTab` | `isLoading`, `hasAnyMatches`, `listFrozen`, subscription events |
| `RemoteLobbyView` | `lobbyPhase` (.waiting → .connecting → .timedOut → .countdown) |
| `RemoteGameplayView` | `isMyTurn`, `isInputEnabled`, `isSaving`, `revealState` |
| `EndGameViewRemote` | `showCelebration`, `showReplayOverlay`, `replayMatch?.status` |

## Game Modes

| Family | Games |
|--------|-------|
| Local countdown | 301, 501 |
| Local target | Halve-It, Knockout, Killer, Sudden Death |
| Remote countdown | Remote 301, Remote 501 |

## Architecture Principles

- One navigation owner per transition
- Router executes, feature screens decide
- Server is authoritative for remote match state
- Local matches are client-authoritative
- Realtime triggers refetch, not direct state mutation
- Frozen snapshots prevent race conditions during navigation

## Supporting References

- `tab-structure.md` — tab ownership and entry points
- `local-game-flow.md` — GamesTab → GameEnd screen by screen
- `remote-game-flow.md` — RemoteTab → GameEnd screen by screen
- `shared-screens.md` — what is shared vs adapted between flows
- `remote-screen-state-reference.md` — remote screen state machines

## Relationship to Other Skills

This skill answers: **what exists in the app and where does it live?**

Use alongside:
- `swiftui-navigation` for navigation rules and guard stack
- `remote-match-lifecycle` for remote feature lifecycle meaning
- `realtime-patterns` for subscription and refetch behavior
- `supabase-patterns` for server-authoritative write rules
- `database-patterns` for schema and data model questions

## Bottom Line

Before changing any screen, know what it owns, what state it can be
in, and what flow it belongs to.

This skill is the map.
The other skills are the rules.