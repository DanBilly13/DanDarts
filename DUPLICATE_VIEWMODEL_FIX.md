# Duplicate RemoteGameplayViewModel Instance Fix

## Summary

Fixed the issue where two RemoteGameplayViewModel instances were being created simultaneously on the receiver device, causing duplicate subscriptions and unpredictable behavior.

**Date:** 2026-02-25

---

## Problem

**Symptom:** Logs showed two different ViewModel instances being created at the same time:
- VM instance: 2DCC...
- VM instance: B5A8...
- Both successfully subscribe (SUBSCRIPTION SUCCESSFUL x 2)

**Root Cause:** Multiple `router.push(.remoteGameplay(...))` calls creating multiple view instances, each with its own `@StateObject`.

**Key Understanding:** `@StateObject` only guarantees "one VM per view identity". Two view instances = two VMs. The fix is preventing duplicate view creation, not changing ViewModel lifecycle.

---

## Fixes Implemented

### ✅ PRIMARY FIX: Router Deduplication

**File:** `DanDart/Services/Router.swift`

Added system-wide deduplication to prevent any duplicate destination pushes:

```swift
@Published var path = NavigationPath()
private var lastPushedDestination: Destination?

func push(_ destination: Destination) {
    // Deduplicate: don't push if same as last destination
    if let last = lastPushedDestination, last == destination {
        print("🚫 [Router] Duplicate push prevented - destination already on stack")
        return
    }
    
    print("✅ [Router] Pushing destination to navigation stack")
    lastPushedDestination = destination
    path.append(Route(destination))
}
```

**Also updated:**
- `pop()` - Clears `lastPushedDestination`
- `pop(count:)` - Clears `lastPushedDestination`
- `popToRoot()` - Clears `lastPushedDestination`
- `reset(to:)` - Sets `lastPushedDestination`

**Why this works:**
- Destination equality already uses stable IDs (match.id, opponent.id, currentUser.id) ✅
- Prevents duplicate pushes from any source (lobby, realtime, etc.)
- System-wide protection for all navigation

---

### ✅ SECONDARY FIX: Lobby Navigation Guard

**File:** `DanDart/Views/Remote/RemoteLobbyView.swift`

Added per-instance navigation guard to prevent repeated triggers from the same lobby:

```swift
@State private var hasNavigatedToGameplay = false

// Before router.push():
guard !hasNavigatedToGameplay else {
    print("🚫 [Lobby] Already navigated to gameplay from this instance, skipping duplicate push")
    return
}
hasNavigatedToGameplay = true
print("✅ [Lobby] Navigating to gameplay (first time for this lobby instance)")

router.push(.remoteGameplay(...))
```

**Why this helps:**
- Stops repeated triggers at the source
- Protects against `.onChange` firing multiple times
- Protects against multiple lobby view instances

---

### ✅ ALREADY IMPLEMENTED: ViewModel Idempotency

**File:** `DanDart/ViewModels/Games/RemoteGameplayViewModel.swift`

The ViewModel already has triple guards against duplicate subscriptions:
- `subscribedMatchId` check
- `pendingSubscriptionMatchId` check  
- `isSubscribing` flag

**Value:** Final safety net. Can't prevent "two VMs" (each VM thinks it's the only one), but prevents subscription chaos within each VM.

---

## Expected Behavior

**Before fixes:**
```
✅ [Router] Pushing destination to navigation stack
✅ [Router] Pushing destination to navigation stack  // DUPLICATE!
🔔 [RemoteGameplay] VM instance: 2DCC...
🔔 [RemoteGameplay] VM instance: B5A8...  // DUPLICATE!
✅ [RemoteGameplay] SUBSCRIPTION SUCCESSFUL
✅ [RemoteGameplay] SUBSCRIPTION SUCCESSFUL  // DUPLICATE!
```

**After fixes:**
```
✅ [Router] Pushing destination to navigation stack
🚫 [Router] Duplicate push prevented - destination already on stack  // BLOCKED!
🔔 [RemoteGameplay] VM instance: [SINGLE-UUID]
✅ [RemoteGameplay] SUBSCRIPTION SUCCESSFUL
```

---

## Testing Checklist

After deployment, verify:
- [ ] Only ONE ViewModel instance created (check logs for single VM instance UUID)
- [ ] Only ONE subscription successful log
- [ ] No "Duplicate push prevented" warnings (unless legitimately triggered)
- [ ] Gameplay works correctly on both devices
- [ ] Turn switching works correctly
- [ ] No navigation issues or stuck states

---

## Files Modified

1. **DanDart/Services/Router.swift**
   - Added `lastPushedDestination` property
   - Updated `push()` with deduplication logic
   - Updated `pop()`, `pop(count:)`, `popToRoot()` to clear tracking
   - Updated `reset(to:)` to set tracking

2. **DanDart/Views/Remote/RemoteLobbyView.swift**
   - Added `hasNavigatedToGameplay` state variable
   - Added navigation guard before `router.push()` call

---

## Architecture Notes

**Destination Identity:** Already correct - uses stable IDs for equality and hashing:
```swift
// Equality (line 59-60)
return m1.id == m2.id && o1.id == o2.id && c1.id == c2.id

// Hashing (line 112-116)
hasher.combine(match.id)
hasher.combine(opponent.id)
hasher.combine(currentUser.id)
```

**Defense in Depth:**
1. Router deduplication (system-wide seatbelt)
2. Lobby navigation guard (targeted source protection)
3. ViewModel idempotency (final safety net)

---

**Status: Implementation complete, ready for testing**
