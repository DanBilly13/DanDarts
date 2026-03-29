> Supporting reference for: app-structure  
> Apply when: working on screens or components that exist in both local 
> and remote flows, deciding whether to share or adapt a component, or 
> understanding what is truly reusable vs what needs mode-specific logic  
> Do not apply to: purely local-only screens, purely remote-only screens, 
> database schema, or realtime behavior unless it directly affects shared 
> component state

# Shared Screens and Components

## Purpose

This document describes which screens and components are shared between
local and remote flows in Dart Freak, what stays the same, and what
gets adapted.

It exists so Windsurf understands the "shared foundation, adapted
specifics" pattern before touching any screen that exists in both flows.

---

## Core Pattern

Dart Freak follows a deliberate reuse pattern:

**What stays the same:** visual design, layout structure, basic
interactions, animations, data models, UI components

**What gets adapted:** state management, navigation destinations,
feature sets, business logic, contextual text and labels

---

## 1. Game Setup Views

| | Local | Remote |
|--|-------|--------|
| File | `GameSetupView.swift` | `RemoteGameSetupView.swift` |
| Player model | Multi-player selection | Single opponent selection |
| Action button | "Start Game" | "Send Challenge" |
| Config | `GameSetupConfigurable` | `RemoteGameSetupConfig` |
| Navigation out | `PreGameHypeView` | Returns to RemoteTab |

### What stays the same
- Hero header with game cover image and gradient overlays
- Parallax scrolling and top bar animation
- Layout constants (`heroHeight: 280`, `topBarHeight: 58`,
`contentSpacing: 32`)
- Visual hierarchy and spacing

---

## 2. Pre-Game / Lobby Views

| | Local | Remote |
|--|-------|--------|
| File | `PreGameHypeView.swift` | `RemoteLobbyView.swift` |
| State source | Animation states | Realtime match data |
| Status text | "MATCH STARTING" | Lobby phase status |
| Navigation | Auto-transitions to gameplay | Waits for server countdown |
| Extra features | None | Voice chat, player presence |

### What stays the same
- Dark gradient background
- Player avatars and VS text
- Sequential reveal animation (players → VS → get ready)
- Boxing match aesthetic and dramatic spacing

### Remote additions
- Voice chat connection setup
- Player presence indicators
- Complex flow tracking and freeze/unfreeze logic

---

## 3. Game End Views

| | Local | Remote |
|--|-------|--------|
| File | `GameEndView.swift` | `EndGameViewRemote.swift` |
| Navigation options | Play Again / Change Players | Back to Games / Replay |
| Extra state | None | Replay overlay, replay match tracking |
| Extra features | None | Replay/rematch creation, match details |

### What stays the same
- Dark gradient background and trophy icon
- Winner avatar and crown animation
- Celebration sequence, sound effects
- Button layout structure and typography

---

## 4. Gameplay Components (Fully Shared)

These components require no adaptation — they are used identically
in both local and remote gameplay:

| Component | Purpose |
|-----------|---------|
| `ScoringButtonGrid.swift` | Dartboard layout, button interactions, long-press for doubles/triples |
| `CurrentThrowDisplay.swift` | Tap-to-edit interface, throw display |
| `PlayerCard.swift` | Avatar, name/nickname, stats layout |
| `PlayerAvatarView.swift` | Avatar rendering, border styling, size variants |

---

## 5. Game Cards

| | Local | Remote |
|--|-------|--------|
| File | `GameCard.swift` | `GameCardRemote.swift` |
| Layout | Vertical card | Horizontal HStack |
| Action | "Play" button | Game number + remote indicator |
| Context | Game selection | Remote game selection |

### What stays the same
- Same `Game` object and cover images
- Similar color schemes and visual hierarchy
- Tap handlers for navigation

---

## 6. Universal UI Components (No Adaptation)

These are fully shared with no mode-specific changes:

| Component | Purpose |
|-----------|---------|
| `AppButton.swift` | Button styling |
| `AsyncAvatarImage.swift` | Avatar loading |
| `DartTextField.swift` | Text input |
| `TipBubble.swift` | Tooltips and help text |
| `PopAnimationModifier.swift` | Animations |

---

## 7. Data Models

### Fully shared
- `Player.swift` — player representation
- `Game.swift` — game definitions
- `ScoredThrow.swift` — throw data
- `ScoreType.swift` — scoring types
- `MatchResult.swift` — match completion data

### Remote-specific
- `RemoteMatch.swift` — remote match state
- `RemoteGameViewModel.swift` — server-synced game state

---

## 8. Navigation and State Management

### Shared
- `Router.shared` — same navigation system for both flows
- Hero animations — same navigation hero effects
- `MainTabView` — both flows integrate with the same tab structure

### Adapted
- Local uses local ViewModels with immediate state updates
- Remote uses realtime services with server-authoritative state and
subscription updates

---

## Decision Guide

When working on a screen that exists in both flows, ask:

1. is this a visual/layout change? → likely safe to share
2. is this a state management change? → check whether it affects
local, remote, or both
3. is this adding a feature? → check whether it is remote-only
(voice, replay, realtime) or truly shared
4. is this changing navigation? → destinations differ between flows,
treat separately

---

## Bottom Line

Local and remote share visual foundation and UI components.

They do not share state management, navigation destinations, or
remote-specific features like voice chat and replay.

When editing a shared screen, always confirm which mode is affected
before changing business logic or navigation.