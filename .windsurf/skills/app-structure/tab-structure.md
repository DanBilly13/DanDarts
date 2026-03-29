> Supporting reference for: app-structure  
> Apply when: working on tab-level navigation, entry point views, badge 
logic, tab-owned features, or any task where understanding which tab 
owns what is relevant  
> Do not apply to: screen-level detail within a tab, remote match 
lifecycle logic, or database/realtime work unless it directly affects 
tab structure

# Tab Structure

## Purpose

This document describes the four main tabs in Dart Freak and what 
each one owns.

It exists so Windsurf knows where features live before suggesting 
changes, and to prevent putting logic in the wrong tab.

---

## Overview

`MainTabView` hosts four tabs:

| Tag | Name | Icon | Entry Point |
|-----|------|------|-------------|
| 0 | Games | `target` | `GamesTabView` → `GamesListView` |
| 1 | Friends | `person.2.fill` | `FriendsTabView` → `FriendsListView` |
| 2 | Remote | `network` | `RemoteGamesTab` |
| 3 | History | `clock.arrow...` | `HistoryTabView` → `MatchHistoryView` |

Badges appear on Friends (pending requests) and Remote (pending 
challenges).

---

## Tab 0 — Games

### Purpose
Central hub for launching all game modes, both local and remote.

### Structure
```
GamesTabView
├── Remote Games Section
│   ├── Remote 301
│   └── Remote 501
└── Local Games Section
    ├── 301, 501, Halve-It
    ├── Knockout, Sudden Death
    └── Killer, Cricket
```

### What this tab owns
- Entry point for all local game setup flows
- Entry point for remote game creation (remote 301/501 cards)
- Profile avatar button (top-right)
- Hero animations to game setup screens

### What this tab does not own
- Remote match management (that is Tab 2)
- Friend management (that is Tab 1)
- Match history (that is Tab 3)

---

## Tab 1 — Friends

### Purpose
Social layer — managing friendships, guest players, and invites.

### What this tab owns
- Friend search and add flow
- Incoming/outgoing friend request management
- Guest player creation and management
- Shareable invite link generation
- Blocked users list

### Toolbar actions
- Invite button — generate shareable invite link
- Search button — toggle friends search interface

### Badge
Shows count of pending incoming friend requests.

---

## Tab 2 — Remote

### Purpose
Online multiplayer hub — challenges, lobby, active gameplay, and 
voice chat.

### What this tab owns
- Sent and received challenge cards
- Ready match cards and lobby entry
- Active in-progress match cards
- Voice chat controls
- Push notification handling for challenge events

### Match states visible in this tab
- Pending — sent/received challenges awaiting response
- Ready — accepted challenges waiting for lobby entry
- Lobby — pre-game countdown with voice setup
- In Progress — active gameplay
- Completed — finished matches

### Toolbar actions
- Challenge button — start new remote challenge flow

### Badge
Shows count of pending incoming challenges.

---

## Tab 3 — History

### Purpose
Browsable record of past matches — local and cloud.

### What this tab owns
- Chronological match history list
- Game type filtering
- Local vs cloud source toggle
- Match search
- Pull-to-refresh cloud sync
- Match detail view

### Data sources
- Local matches — device JSON storage
- Cloud matches — Supabase
- Both sources combined with deduplication

### Toolbar actions
- Local/Remote toggle — switch data source
- Search button — search match history

---

## Shared Across All Tabs

- Profile access — avatar in Games tab, profile sheet elsewhere
- Hero animations — smooth transitions to game setup
- Unified router — `Router.shared` handles all navigation
- Toast notifications — friend request toasts appear above all tabs
- Live updates — remote matches update in real-time
- Background sync — data syncs when app becomes active

---

## Bottom Line

Each tab has a clear ownership boundary.

- Games owns game launch
- Friends owns social
- Remote owns online match management
- History owns past match records

Do not put tab-owned logic in the wrong tab.