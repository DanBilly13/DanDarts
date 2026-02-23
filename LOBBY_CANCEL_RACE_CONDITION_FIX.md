# Lobby Cancellation Race Condition - Fix Implementation

**Date:** 2026-02-23  
**Status:** ✅ IMPLEMENTED

## Problem Summary

When users cancelled from the lobby, they would navigate back to Remote tab (correct) but then get sent to the placeholder gameplay page 3 seconds later (incorrect). This was caused by a race condition where the scheduled navigation Task was still executing after cancellation.

## Root Cause

The `startMatchStartingSequence()` method in `RemoteLobbyView` scheduled a 3-second delayed navigation using `DispatchQueue.main.asyncAfter`. When users cancelled:

1. Cancel button tapped → async `cancelChallenge()` started
2. Opponent joined → match became `inProgress`
3. Realtime fired → `onChange(matchStatus)` triggered
4. `startMatchStartingSequence()` scheduled navigation in 3 seconds
5. Cancel completed → user navigated to Remote tab
6. **3 seconds later** → scheduled navigation executed → user sent to gameplay

## Solution: Production-Hardened Multi-Layer Guards

### Layer 1: Global Match-Scoped Cancellation Guard
- Use existing `cancelledMatchIds: Set<UUID>` from `RemoteGamesTab`
- Passed as `@Binding` to `RemoteLobbyView`
- Survives view recreation, tab switches, navigation changes
- Single source of truth for "this match is cancelled"

### Layer 2: View Lifetime Guard
- Added `@State private var isViewActive = false`
- Set `true` in `onAppear`, `false` in `onDisappear`
- Prevents navigation after view dismissed

### Layer 3: Cancellable Task (Swift Concurrency)
- Replaced `DispatchWorkItem` with `Task { @MainActor in ... }`
- Uses `try await Task.sleep()` (throws when cancelled)
- Explicit `Task.isCancelled` check
- More idiomatic for async/await codebase

### Layer 4: Prevent Double-Scheduling
- Check `navigationTask != nil` before scheduling
- Prevents status flaps from creating multiple delayed navigations

## Files Modified

### 1. RemoteLobbyView.swift
**Changes:**
- Added `@Binding var cancelledMatchIds: Set<UUID>` parameter
- Added `@State private var isViewActive = false`
- Added `@State private var navigationTask: Task<Void, Never>?`
- Updated `onAppear` to set `isViewActive = true`
- Added `onDisappear` to set `isViewActive = false` and cancel task
- Rewrote `onChange(matchStatus)` with 4 explicit guards:
  1. Ignore if match cancelled
  2. Cancel navigation if status NOT inProgress
  3. Don't double-schedule if already scheduled
  4. Handle cancelled status
- Rewrote `startMatchStartingSequence()` with Task-based approach:
  - 2 guards before scheduling (cancelled, already scheduled)
  - 4 guards inside Task before navigation (cancelled, view inactive, match cancelled, match still valid)
- Updated Cancel button to set `cancelledMatchIds.insert()` and cancel task
- Updated Preview with wrapper to provide binding

### 2. RemoteGamesTab.swift
**Changes:**
- Updated receiver flow `router.push(.remoteLobby(...))` to pass `cancelledMatchIds: $cancelledMatchIds`
- Updated challenger flow `router.push(.remoteLobby(...))` to pass `cancelledMatchIds: $cancelledMatchIds`

### 3. Router.swift
**Changes:**
- Updated `remoteLobby` case to include `cancelledMatchIds: Binding<Set<UUID>>` parameter
- Updated equality check to ignore binding (5 parameters, ignore last 2)
- Updated hash function to ignore binding (5 parameters, ignore last 2)
- Updated view factory to pass `cancelledMatchIds` to `RemoteLobbyView`

## Guard Layers Explained

### onChange Handler Guards
1. **Cancelled match?** → Ignore all changes
2. **Status NOT inProgress?** → Cancel pending navigation
3. **Already scheduled?** → Don't double-schedule
4. **Status IS inProgress?** → Schedule navigation

### Task Guards (Inside Delayed Navigation)
1. **Task.isCancelled** → Task was cancelled
2. **isViewActive** → View still exists
3. **cancelledMatchIds.contains()** → Match not cancelled
4. **Match still exists and is inProgress** → Database state valid

## Why This Works

### Global Cancellation Guard
- `cancelledMatchIds` lives in parent (`RemoteGamesTab`)
- Survives view recreation, tab switches
- Single source of truth
- Can't be lost when view recreates

### View Lifetime Protection
- `isViewActive` tracks actual view presence
- Prevents navigation after view dismissed
- Belt-and-suspenders safety

### Task-Based Cancellation
- `Task` integrates with Swift concurrency
- `navigationTask?.cancel()` is synchronous and immediate
- `try await Task.sleep()` throws when cancelled
- Explicit error handling

### Main Thread Consistency
- `Task { @MainActor in ... }` ensures main thread
- All navigation on main thread
- All state mutations on main thread
- No race between background cancel and foreground navigation

## Testing Scenarios Covered

### Basic Flows
✅ Cancel before opponent joins → Navigate to Remote tab only  
✅ Cancel after opponent joins, before 3s → Task cancelled, navigate to Remote tab  
✅ Opponent joins during cancel → Guards block navigation  
✅ Normal flow (no cancel) → Wait 3s, navigate to gameplay  

### Edge Cases
✅ Cancel button tapped multiple times → Idempotent  
✅ Tab switch during countdown → `isViewActive = false`, navigation aborted  
✅ View recreated during countdown → `cancelledMatchIds` persists, blocks navigation  
✅ Status flaps → Only first Task scheduled  
✅ Realtime update after cancel → `onChange` guard blocks processing  
✅ Match deleted during countdown → Guard 4 fails, navigation aborted  

### Race Conditions
✅ Cancel + opponent join simultaneously → `cancelledMatchIds.insert()` is synchronous, wins  
✅ Multiple realtime updates rapid-fire → Double-schedule guard prevents multiple Tasks  
✅ Cancel during Task.sleep() → Task cancelled, throws error, navigation aborted  

## Key Improvements Over Previous Approach

| Aspect | Previous (Failed) | Production-Hardened |
|--------|------------------|---------------------|
| **Cancellation scope** | `@State` (view-local) | `cancelledMatchIds` (global) |
| **View recreation** | ❌ Flag resets | ✅ Survives recreation |
| **Scheduled work** | `DispatchWorkItem` | `Task` (async/await) |
| **Double-schedule guard** | ❌ None | ✅ Explicit check |
| **View lifetime guard** | ❌ None | ✅ `isViewActive` |
| **onChange logic** | Implicit | Explicit with 4 guards |
| **Task guards** | 2 guards | 4 guards (defense in depth) |
| **Thread safety** | Implicit | Explicit `@MainActor` |

## Acceptance Criteria

✅ Cancel from lobby navigates to Remote tab only (no gameplay navigation)  
✅ Scheduled navigation is cancelled when Cancel tapped  
✅ Realtime updates during cancellation don't trigger navigation  
✅ Match status changes during cancellation are ignored  
✅ No race conditions between cancel and auto-join logic  
✅ Works correctly even if view is recreated (tab switch, etc.)  
✅ Prevents double-scheduling from status flaps  
✅ All navigation happens on main thread  
✅ Clean error handling with explicit logging  

## Implementation Complete

All files have been modified according to the production-hardened plan. The fix uses multiple layers of defense to ensure that cancellation intent is respected across all edge cases including view recreation, tab switches, and realtime updates.
