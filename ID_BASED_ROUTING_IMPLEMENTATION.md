# ID-Based Routing Implementation - Complete

## Summary

Successfully refactored remote match navigation from struct-based to ID-based routing to fix duplicate lobby and ViewModel instances.

## Root Cause Fixed

**Problem:** Passing full structs (RemoteMatch, User, Binding, closures) in Router destinations created unstable identity, causing SwiftUI to create duplicate view instances even when representing the same match.

**Solution:** Route by stable UUID only, fetch data from RemoteMatchService (single source of truth).

---

## Files Modified

### 1. Router.swift ✅
**Changes:**
- `remoteLobby(matchId: UUID)` - ID-based (was: match, opponent, currentUser, Binding, closure)
- `remoteGameplay(matchId: UUID)` - ID-based (was: match, opponent, currentUser)
- Simplified equality/hashing (just UUID comparison)
- Updated view factory to pass matchId only

**Benefits:**
- Stable identity (UUID never changes)
- Proper Hashable (no Binding/closure issues)
- Deduplication works correctly

### 2. RemoteNavigationLatch.swift ✅ (NEW)
**Purpose:** Global navigation guard to prevent duplicate navigation per match

**Methods:**
- `tryNavigateToGameplay(matchId:) -> Bool` - Returns false if already navigated
- `clearNavigation(matchId:)` - Clears latch for specific match
- `reset()` - Clears all navigation state

**Usage:**
```swift
guard RemoteNavigationLatch.shared.tryNavigateToGameplay(matchId: matchId) else {
    return // Already navigated
}
router.push(.remoteGameplay(matchId: matchId))
```

### 3. RemoteMatchService.swift ✅
**Added:**
- `@Published var cancelledMatchIds: Set<UUID>` - Moved from local state

**Benefits:**
- Single source of truth for cancelled matches
- No Binding in Router destinations
- Reactive across all views

### 4. RemoteLobbyView.swift ✅
**Refactored to ID-based:**

**Before:**
```swift
init(match: RemoteMatch, opponent: User, currentUser: User, 
     onCancel: () -> Void, cancelledMatchIds: Binding<Set<UUID>>)
```

**After:**
```swift
init(matchId: UUID)
```

**Implementation:**
- Computed properties fetch from `remoteMatchService` (NOT @State)
- Loading state when data unavailable
- `.task` with `hasAttemptedInitialLoad` guard (prevents load loops)
- Uses `remoteMatchService.cancelledMatchIds` (not Binding)
- Navigation uses global latch

**Computed Properties:**
```swift
private var matchWithPlayers: RemoteMatchWithPlayers? {
    if let active = remoteMatchService.activeMatch, active.match.id == matchId {
        return active
    }
    return remoteMatchService.readyMatches.first(where: { $0.match.id == matchId })
}

private var match: RemoteMatch? { matchWithPlayers?.match }
private var opponent: User? { matchWithPlayers?.opponent }
private var currentUser: User? { authService.currentUser }
```

### 5. RemoteGamesTab.swift ✅
**Updated navigation calls:**

**Before:**
```swift
router.push(.remoteLobby(
    match: updatedMatch,
    opponent: opponent,
    currentUser: currentUser,
    cancelledMatchIds: $cancelledMatchIds,
    onCancel: { /* 60 lines of closure code */ }
))
```

**After:**
```swift
router.push(.remoteLobby(matchId: matchId))
```

**Changes:**
- Removed local `@State cancelledMatchIds`
- All references use `remoteMatchService.cancelledMatchIds`
- Both receiver and challenger flows simplified

### 6. RemoteGameplayView.swift ✅
**Refactored to ID-based:**

**Before:**
```swift
init(match: RemoteMatch, opponent: User, currentUser: User)
```

**After:**
```swift
init(matchId: UUID) {
    self.matchId = matchId
    
    // CRITICAL: Initialize @StateObject in init()
    _gameViewModel = StateObject(wrappedValue: RemoteGameplayViewModel(matchId: matchId))
}
```

**Key Points:**
- @StateObject initialized in `init()` (one VM per view identity)
- Computed properties for match/opponent/currentUser (from service)
- Loading state when data unavailable
- `.task` with `hasAttemptedInitialLoad` guard
- `.onDisappear` clears navigation latch

**Navigation Latch Clearing:**
```swift
.onDisappear {
    RemoteNavigationLatch.shared.clearNavigation(matchId: matchId)
}
```

### 7. RemoteGameplayViewModel.swift ✅
**Refactored to fetch data asynchronously:**

**Before:**
```swift
init(match: RemoteMatch, challenger: User, receiver: User, currentUser: User)
```

**After:**
```swift
init(matchId: UUID) {
    self.matchId = matchId
    self.matchStartTime = Date()
    
    Task {
        await loadMatchData()
    }
}
```

**Changes:**
- Properties now optional: `RemoteMatch?`, `User?`
- `loadMatchData()` fetches match and users from Supabase
- Updates @Published properties on MainActor
- Calls `subscribeToMatch()` after data loaded
- Computed properties handle optionals gracefully

**Data Loading:**
```swift
private func loadMatchData() async {
    // Fetch match from RemoteMatchService
    // Fetch users from Supabase
    // Update @Published properties on MainActor
    // Initialize players and scores
    // Subscribe to realtime updates
}
```

---

## Architecture Benefits

### ✅ Stable Identity
- UUID never changes
- No struct equality issues
- Router deduplication works correctly

### ✅ Single Source of Truth
- RemoteMatchService is authoritative
- No @State fork of data
- Reactive updates via @Published

### ✅ @StateObject Pattern
- Initialized in `init()` (not body)
- One VM per view identity
- No recreation on re-render

### ✅ Global Navigation Guard
- Prevents duplicate navigation per match
- Works across all view instances
- Cleared when leaving gameplay

### ✅ No Binding/Closure in Routes
- Proper Hashable/Equatable
- No identity confusion
- Cleaner navigation code

---

## Expected Results

**Before:**
```
🧩 [Lobby] instance=00B2... onAppear
🧩 [Lobby] instance=FF3F... onAppear  // DUPLICATE!
✅ [Router] Pushing destination
✅ [Router] Pushing destination  // DUPLICATE!
🔔 [RemoteGameplay] VM instance: DF5D...
🔔 [RemoteGameplay] VM instance: F22D...  // DUPLICATE!
⚠️ Update NavigationRequestObserver tried to update multiple times per frame
```

**After:**
```
🧩 [Lobby] instance=00B2... onAppear
✅ [Router] Pushing destination (matchId: ...)
✅ [NavigationLatch] Allowing navigation to gameplay
🎮 [RemoteGameplayVM] Initializing with matchId: ...
🎮 [RemoteGameplayVM] VM instance: [SINGLE-UUID]
📥 [RemoteGameplayVM] Loading match data
✅ [RemoteGameplayVM] Match data loaded successfully
🔔 [RemoteGameplay] SUBSCRIBING TO MATCH
✅ [RemoteGameplay] SUBSCRIPTION SUCCESSFUL
```

---

## Testing Checklist

- [ ] Only ONE lobby instance created per match
- [ ] Only ONE gameplay VM instance created per match
- [ ] No "multiple updates per frame" warnings
- [ ] Router deduplication works (no duplicate pushes)
- [ ] Global latch prevents duplicate navigation
- [ ] Both players can join and play normally
- [ ] Turn switching works correctly
- [ ] Navigation back works correctly
- [ ] Match data loads correctly
- [ ] Realtime updates work
- [ ] Cancel functionality works
- [ ] Navigation latch clears on exit

---

## Production-Grade Architecture ✅

This implementation follows SwiftUI best practices:

1. **ID-based routing** - Stable identity, proper Hashable
2. **Service as source of truth** - No @State fork
3. **@StateObject in init()** - One VM per view
4. **Global navigation latch** - Prevents duplicates
5. **Computed properties** - Reactive to service updates
6. **Loading states** - Graceful data fetching
7. **Idempotency guards** - Prevents load loops

**Status: Implementation complete, ready for testing**
