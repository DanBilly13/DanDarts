# Replay Navigation Diagnostics Implementation

This plan adds focused logging to trace navigation behavior during replay accept/join flow and identify whether there's a real tab switch or just UI redraw.

## Diagnostic Goal

Determine if replay accept/join is:
1. Actually switching to Remote Games tab
2. Router pop/reset exposing the tab temporarily  
3. Just UI redraw/flicker without actual navigation changes

## Implementation Scope

**Logging only** - no behavior changes yet
**Prefix**: `[ReplayNavTrace]` for all diagnostic logs
**Focus**: Replay accept/join flow navigation events

## Files to Modify

### 1. MainTabView.swift
**Location**: Tab selection logic
**Logs**: Every `selectedTab` change
**Include**:
- Old tab → New tab
- Timestamp
- `isInRemoteFlow` state
- `flowMatchId` if available

```swift
// Add to tab selection onChange
print("[ReplayNavTrace] Tab change: \(oldTab) → \(newTab) | isInRemoteFlow: \(remoteMatchService.isInRemoteFlow) | flowMatchId: \(remoteMatchService.flowMatchId?.uuidString.prefix(8) ?? "none") | \(Date())")
```

### 2. Router.swift
**Location**: Navigation mutation methods
**Logs**: Every navigation operation
**Include**:
- Caller file/function
- Route details
- Path depth before/after
- Operation type (push/pop/reset)

```swift
// Add to navigation methods
print("[ReplayNavTrace] Router.\(#function) | route: \(route) | depth: \(navigationPath.count) → \(newCount) | caller: \(caller)")
```

### 3. EndGameViewRemote.swift
**Location**: Key replay flow points
**Logs**:
- Accept replay tapped
- Join replay tapped  
- `navigateToLobby()` start/end
- Overlay dismiss
- Replay ownership claim/release

```swift
// Add at key points
print("[ReplayNavTrace] EndGameViewRemote.\(#function) | matchId: \(matchId?.uuidString.prefix(8) ?? "nil") | \(Date())")
```

### 4. RemoteGamesTab.swift
**Location**: View lifecycle
**Logs**: `onAppear` and `onDisappear`
**Include**:
- View appearing/disappearing
- Current match counts
- Active flow state

```swift
// Add lifecycle logs
print("[ReplayNavTrace] RemoteGamesTab.\(#function) | pending: \(pendingChallenges.count) | ready: \(readyMatches.count) | \(Date())")
```

### 5. RemoteLobbyView.swift  
**Location**: View lifecycle
**Logs**: `onAppear` and `onDisappear`
**Include**:
- View appearing/disappearing
- Match ID and status
- Navigation source

```swift
// Add lifecycle logs  
print("[ReplayNavTrace] RemoteLobbyView.\(#function) | matchId: \(match.id.uuidString.prefix(8)) | status: \(match.status?.rawValue ?? "nil") | \(Date())")
```

### 6. RemoteMatchService.swift
**Location**: Replay-related reload/publish events
**Logs**:
- `isInRemoteFlow` changes
- `flowMatchId` changes
- Match count updates
- `activeMatch` changes

```swift
// Add to reload/publish methods
print("[ReplayNavTrace] RemoteMatchService.\(#function) | isInRemoteFlow: \(isInRemoteFlow) | flowMatchId: \(flowMatchId?.uuidString.prefix(8) ?? "none") | pending: \(pendingChallenges.count) | ready: \(readyMatches.count) | \(Date())")
```

## Log Format Standard

All logs use consistent format:
```
[ReplayNavTrace] Component.function | key: value | key: value | timestamp
```

**Key fields to include where relevant**:
- `matchId`: 8-char prefix
- `isInRemoteFlow`: boolean
- `flowMatchId`: 8-char prefix or "none"
- `tab`: current tab name
- `depth`: navigation path depth
- `counts`: pending/ready/sent match counts
- `caller`: source of navigation operation

## Success Criteria

1. ✅ Complete timeline of replay accept/join navigation
2. ✅ Tab change events captured with context
3. ✅ Router mutations traced with caller info
4. ✅ View lifecycle events logged
5. ✅ Flow state changes captured
6. ✅ Clear distinction between real navigation vs UI redraw

## Analysis Focus

After implementation, analyze logs for:
1. **Tab Switch Pattern**: MainTabView actually changing selectedTab
2. **Router Pattern**: Navigation path changes (pop/push/reset)
3. **Lifecycle Pattern**: Views appearing/disappearing unexpectedly
4. **Flow State Pattern**: Remote flow state changes during navigation
5. **Timing Correlation**: Event sequencing and timing

## Files Modified

- `MainTabView.swift` - Tab selection logging
- `Router.swift` - Navigation mutation logging  
- `EndGameViewRemote.swift` - Replay flow logging
- `RemoteGamesTab.swift` - View lifecycle logging
- `RemoteLobbyView.swift` - View lifecycle logging
- `RemoteMatchService.swift` - Flow state logging

## Risk Assessment

**ZERO RISK** - Pure logging additions, no behavior changes. All logs are non-intrusive print statements.
