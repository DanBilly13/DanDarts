# Remote Match Realtime Edge Cases - Complete Guide

**A comprehensive reference for handling realtime subscriptions, async operations, and navigation in the DanDart remote match system.**

---

## Table of Contents

1. [The Core Problem Pattern](#1-the-core-problem-pattern)
2. [Case Studies: Real Issues & Solutions](#2-case-studies-real-issues--solutions)
3. [The Friends Feature Breakthrough](#3-the-friends-feature-breakthrough)
4. [Best Practices & Patterns](#4-best-practices--patterns)
5. [Debugging Toolkit](#5-debugging-toolkit)
6. [Quick Reference](#6-quick-reference)

---

## 1. The Core Problem Pattern

### What Makes Realtime + Async + Navigation Complex?

Remote matches involve three challenging aspects working together:

1. **Realtime Subscriptions** - Database changes trigger callbacks that update local state
2. **Async Operations** - Edge functions, database queries, and state updates happen asynchronously
3. **Navigation** - SwiftUI view transitions that depend on state being correct

**The Fundamental Race Condition:**

```
User Action → Async Operation → State Change → Realtime Callback → Another State Change → Navigation
                                      ↓                                        ↓
                                 View Re-render                          View Re-render
```

When these happen in the wrong order or timing, users see:
- Buttons that don't respond
- UI flickering through intermediate states
- Cards appearing/disappearing unexpectedly
- Navigation failing silently

### Why Simple Approaches Work Better

**Complex approach (prone to issues):**
- Multiple async operations in sequence
- Background reloads during navigation
- State mutations before capturing needed data
- Async checks in critical paths

**Simple approach (robust):**
- Capture data early, before any state changes
- Synchronous checks where possible
- State mutations only after operations complete
- No background operations during navigation

---

## 2. Case Studies: Real Issues & Solutions

### Case Study 1: Accept Button Not Responding

**Issue:** Receiver tapped Accept button, but nothing happened. Second tap showed 409 error (already accepted).

**User Experience:**
- Tap Accept → Nothing happens
- Tap Accept again → Error: "Challenge already accepted"
- Confusion and frustration

**Root Cause:**

The Accept button WAS working - challenges were being accepted successfully. The issue was navigation failing due to an async race condition in `loadMatches()`.

**File:** `RemoteMatchService.swift` (lines 121-133)

**Before (Broken):**
```swift
case .lobby:
    Task {
        let hasJoined = await checkIfUserJoinedMatch(matchId: match.id, userId: userId)
        await MainActor.run {
            if hasJoined {
                active = matchWithPlayers  // ⚠️ Set AFTER loadMatches returns
            }
        }
    }
```

**What happened:**
1. `acceptChallenge()` called `joinMatch()` → match status became `lobby`
2. `loadMatches()` called to refresh state
3. Found match with status `lobby`
4. Spawned async `Task` to check if user joined
5. **`loadMatches()` returned immediately** (before Task completed)
6. `activeMatch` was still `nil`
7. Navigation check failed
8. User stayed on Remote tab
9. Second tap → 409 error (already accepted)

**After (Fixed):**
```swift
case .lobby:
    // Check synchronously to ensure activeMatch is set before loadMatches returns
    let hasJoined = await checkIfUserJoinedMatch(matchId: match.id, userId: userId)
    await MainActor.run {
        if hasJoined {
            active = matchWithPlayers  // ✅ Set BEFORE loadMatches returns
        } else {
            ready.append(matchWithPlayers)
        }
    }
```

**Solution:**
- Removed `Task` wrapper
- Made lobby check synchronous (await directly)
- Ensured `activeMatch` is populated before `loadMatches()` returns

**Lesson Learned:**
> **Never use `Task {}` in critical state-setting paths.** If you need the result before continuing, use `await` directly.

**References:**
- `REMOTE_ACCEPT_BUTTON_FIX_SUMMARY.md`
- `RemoteMatchService.swift` lines 121-133

---

### Case Study 2: Receiver Card State Flicker

**Issue:** When receiver accepted a challenge, their card briefly changed to show "Resume Match" button before navigating to lobby.

**User Experience:**
- Tap Accept
- Card flickers to "Active Match" state
- Then navigates to lobby
- Jarring, unprofessional UX

**Root Cause:**

The `processingMatchId` flag was being cleared BEFORE navigation, causing the view to re-render and show the Active Match section.

**File:** `RemoteGamesTab.swift` (lines 375-409)

**Before (Broken):**
```swift
await MainActor.run {
    processingMatchId = nil  // ← Cleared FIRST
    
    if let opponent = ... {
        router.push(.remoteLobby(...))  // ← Navigation SECOND
    }
}
```

**Sequence:**
1. `processingMatchId = nil` → State changed
2. View re-rendered
3. Active Match section appeared (processingMatchId was nil)
4. Card showed "Resume Match" button
5. `router.push()` called
6. User already saw the flicker

**After (Fixed):**
```swift
await MainActor.run {
    if let opponent = ..., let currentUser = ... {
        router.push(.remoteLobby(...))  // ← Navigation FIRST
        
        // Clear processingMatchId AFTER navigation is initiated
        processingMatchId = nil  // ← Cleared SECOND
    } else {
        processingMatchId = nil  // Only clear if navigation fails
    }
}
```

**Sequence:**
1. `processingMatchId` stays set (card hidden)
2. `router.push()` called → Navigation starts
3. `processingMatchId = nil` → View re-renders
4. By the time view re-renders, navigation is in progress
5. User never sees the Active Match card

**Lesson Learned:**
> **Clear processing flags AFTER navigation, not before.** State changes trigger re-renders immediately.

**References:**
- `FIX_RECEIVER_NAVIGATION_TIMING_V2.md`
- `RemoteGamesTab.swift` lines 375-409

---

### Case Study 3: Card Not Disappearing After Accept

**Issue:** After receiver accepted and navigated to lobby, their challenge card was still visible in RemoteGamesTab.

**User Experience:**
- Accept challenge → Navigate to lobby ✅
- Navigate back to Remote tab
- Same challenge card still showing
- Can tap Accept again (causes errors)

**Root Cause:**

Two issues:
1. Background reload was refreshing RemoteGamesTab even after navigation
2. No filter to exclude `activeMatch` from challenge lists

**File:** `RemoteGamesTab.swift`

**Problem 1: Background Reload**

**Before (Broken):**
```swift
// Step 4: Reload matches in background to update state
Task {
    do {
        try await remoteMatchService.loadMatches(userId: currentUser.id)
    } catch {
        print("❌ Background reload failed: \(error)")
    }
}
```

This was triggering a UI refresh after the user had already navigated away.

**After (Fixed):**
```swift
// Note: No background reload needed - receiver is navigating to lobby
// The realtime subscription will handle any updates if needed
```

**Problem 2: Missing Filter**

**Before (Broken):**
```swift
ForEach(remoteMatchService.pendingChallenges.filter { 
    !expiredMatchIds.contains($0.id)
}) { matchWithPlayers in
```

**After (Fixed):**
```swift
ForEach(remoteMatchService.pendingChallenges.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id  // ← Added filter
}) { matchWithPlayers in
```

Applied to all three lists: `pendingChallenges`, `sentChallenges`, `readyMatches`

**Lesson Learned:**
> **Don't trigger background reloads during navigation.** Let realtime subscriptions handle updates. Always filter out `activeMatch` from challenge lists.

**References:**
- `FIX_RECEIVER_CARD_AFTER_ACCEPT.md`
- `RemoteGamesTab.swift` lines 159-162, 203-206, 122-125

---

### Case Study 4: Active Match Section Rendering Too Early

**Issue:** Even with filters on challenge lists, the Active Match section was rendering during the accept flow, showing "Resume Match" button.

**User Experience:**
- Tap Accept
- Brief flash of "Active Match" section with Resume button
- Then navigates to lobby
- Still jarring

**Root Cause:**

The filters we added only applied to challenge lists (pending/sent/ready), NOT to the Active Match section itself.

**File:** `RemoteGamesTab.swift` (line 243-244)

**Before (Broken):**
```swift
// Active match (in progress)
if let activeMatch = remoteMatchService.activeMatch {
    VStack(alignment: .leading, spacing: 12) {
        sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
        PlayerChallengeCard(...)
    }
}
```

**After (Fixed):**
```swift
// Active match (in progress)
if let activeMatch = remoteMatchService.activeMatch,
   processingMatchId == nil {  // ← Added guard
    VStack(alignment: .leading, spacing: 12) {
        sectionHeader("Active Match", systemImage: "play.circle.fill", color: .blue)
        PlayerChallengeCard(...)
    }
}
```

**How It Works:**
1. Receiver clicks Accept
2. `processingMatchId = matchId` set
3. `joinMatch()` executes → match becomes `in_progress`
4. Realtime fires → `loadMatches()` → match becomes `activeMatch`
5. **Active Match section doesn't render** (because `processingMatchId != nil`)
6. Navigation completes
7. `processingMatchId = nil` (but user is already in lobby)

**Lesson Learned:**
> **Use processing flags to guard ALL sections that could render during async operations,** not just the sections you're modifying.

**References:**
- `FIX_RECEIVER_ACTIVE_MATCH_TIMING.md`
- `RemoteGamesTab.swift` line 243-244

---

### Case Study 5: Opponent Data Lost During Navigation

**Issue:** Receiver accepted challenge, but navigation failed with error: "Cannot find opponent in pendingChallenges".

**User Experience:**
- Tap Accept
- Nothing happens (navigation fails)
- Console shows: "Cannot find opponent"

**Root Cause:**

The code was trying to find opponent data from `pendingChallenges` AFTER the match had already been accepted and moved to a different list.

**File:** `RemoteGamesTab.swift` (lines 347-353, 383-411)

**Before (Broken):**
```swift
private func acceptChallenge(matchId: UUID) {
    processingMatchId = matchId
    
    Task {
        // Accept and join...
        try await remoteMatchService.acceptChallenge(matchId: matchId)
        try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
        
        await MainActor.run {
            // Try to find opponent NOW (after match moved lists)
            if let opponent = remoteMatchService.pendingChallenges
                .first(where: { $0.match.id == matchId })?.opponent {  // ← Not found!
                router.push(.remoteLobby(...))
            }
        }
    }
}
```

**What happened:**
1. Match was in `pendingChallenges`
2. `acceptChallenge()` called → match moved to `readyMatches`
3. `joinMatch()` called → match moved to `activeMatch`
4. Tried to find opponent in `pendingChallenges` → Not found!
5. Navigation failed

**After (Fixed):**
```swift
private func acceptChallenge(matchId: UUID) {
    // CRITICAL: Capture opponent data NOW before state changes
    guard let matchWithPlayers = remoteMatchService.pendingChallenges
        .first(where: { $0.match.id == matchId }) else {
        return
    }
    let opponent = matchWithPlayers.opponent  // ← Captured early!
    
    processingMatchId = matchId
    
    Task {
        // Accept and join...
        try await remoteMatchService.acceptChallenge(matchId: matchId)
        try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
        
        await MainActor.run {
            // Use captured opponent data
            router.push(.remoteLobby(
                match: updatedMatch,
                opponent: opponent,  // ← Already have it!
                currentUser: currentUser,
                onCancel: { ... }
            ))
            
            processingMatchId = nil
        }
    }
}
```

**Lesson Learned:**
> **Capture all needed data at the START of async operations, before any state changes.** Don't try to look up data after state has mutated.

**References:**
- `RemoteGamesTab.swift` lines 347-353, 383-411

---

## 3. The Friends Feature Breakthrough

### The Clean Pattern That Works

The friends feature (accept/deny friend requests) uses a simple, direct approach that avoids all the realtime edge cases we encountered with remote matches.

**File:** `FriendsService.swift` (lines 779-803)

### Accept Friend Request

```swift
func acceptFriendRequest(requestId: UUID) async throws {
    // Simple, direct database update
    try await supabaseService.client
        .from("friendships")
        .update(["status": "accepted"])
        .eq("id", value: requestId.uuidString)
        .execute()
}
```

**That's it.** No:
- Background reloads
- Complex state management
- Async race conditions
- Navigation timing issues

### Deny Friend Request

```swift
func denyFriendRequest(requestId: UUID) async throws {
    // Simple, direct database delete
    try await supabaseService.client
        .from("friendships")
        .delete()
        .eq("id", value: requestId.uuidString)
        .execute()
}
```

### Why It Works So Well

1. **Single Responsibility** - Each function does ONE thing
2. **No State Coupling** - Doesn't depend on complex state being correct
3. **Direct Operations** - Straight to database, no edge functions
4. **Simple UI Updates** - Realtime subscription handles UI refresh naturally
5. **No Navigation** - Stays on same screen, just updates list

### Pattern Comparison

**Friends (Simple):**
```
User Action → Database Update → Realtime Callback → UI Update
```

**Remote Matches (Complex):**
```
User Action → Edge Function → Database Update → Realtime Callback → 
State Mutation → Load Matches → Check Active → Navigate → Clear Flags
```

### What We Should Adopt

**From Friends Implementation:**
1. ✅ Capture data early (before async operations)
2. ✅ Single-purpose functions
3. ✅ Let realtime handle UI updates
4. ✅ Avoid background reloads during operations
5. ✅ Simple, direct database operations where possible

**Applied to Remote Matches:**
- Capture opponent data at function start
- Remove background reloads
- Synchronous checks in loadMatches
- Processing flags to prevent UI flicker
- Clear flags after navigation, not before

---

## 4. Best Practices & Patterns

### State Management

#### ✅ DO: Capture Data Early

```swift
func acceptChallenge(matchId: UUID) {
    // Capture ALL needed data FIRST
    guard let matchWithPlayers = remoteMatchService.pendingChallenges
        .first(where: { $0.match.id == matchId }) else {
        return
    }
    let opponent = matchWithPlayers.opponent
    let currentMatch = matchWithPlayers.match
    
    // Now proceed with async operations
    Task {
        // Data is safe, won't be lost
    }
}
```

#### ❌ DON'T: Look Up Data After State Changes

```swift
func acceptChallenge(matchId: UUID) {
    Task {
        try await remoteMatchService.acceptChallenge(matchId: matchId)
        
        // ❌ Match has moved to different list, lookup will fail
        if let opponent = remoteMatchService.pendingChallenges
            .first(where: { $0.match.id == matchId })?.opponent {
            // Won't find it!
        }
    }
}
```

#### ✅ DO: Guard Checks Before State Mutations

```swift
func acceptChallenge(matchId: UUID) {
    // Guard BEFORE setting processingMatchId
    guard processingMatchId == nil else {
        return  // Already processing
    }
    
    guard let matchWithPlayers = remoteMatchService.pendingChallenges
        .first(where: { $0.match.id == matchId }) else {
        return  // Match not found
    }
    
    // NOW set the flag
    processingMatchId = matchId
}
```

#### ❌ DON'T: Set Flags Before Guards

```swift
func acceptChallenge(matchId: UUID) {
    // ❌ Set flag FIRST
    processingMatchId = matchId
    
    // Guard fails → flag stays set → button disabled forever
    guard let matchWithPlayers = ... else {
        return  // ❌ Forgot to clear processingMatchId!
    }
}
```

#### ✅ DO: Use Processing Flags to Prevent UI Flicker

```swift
// Hide section during async operations
if let activeMatch = remoteMatchService.activeMatch,
   processingMatchId == nil {  // ← Guard with flag
    ActiveMatchSection(match: activeMatch)
}
```

#### ✅ DO: Clear Flags After Navigation

```swift
await MainActor.run {
    router.push(.remoteLobby(...))  // Navigate FIRST
    processingMatchId = nil  // Clear AFTER
}
```

---

### Async Operations

#### ✅ DO: Use Synchronous Checks in Critical Paths

```swift
case .lobby:
    // Synchronous - result available before function returns
    let hasJoined = await checkIfUserJoinedMatch(matchId: match.id, userId: userId)
    await MainActor.run {
        if hasJoined {
            active = matchWithPlayers
        }
    }
```

#### ❌ DON'T: Use Task{} for Critical State

```swift
case .lobby:
    // ❌ Async - function returns before Task completes
    Task {
        let hasJoined = await checkIfUserJoinedMatch(...)
        await MainActor.run {
            active = matchWithPlayers  // Set AFTER function returns
        }
    }
```

#### ✅ DO: Avoid Background Operations During Navigation

```swift
// Navigate to lobby
router.push(.remoteLobby(...))

// ❌ DON'T reload in background
// Task {
//     try await remoteMatchService.loadMatches(userId: userId)
// }

// ✅ Let realtime subscription handle updates
```

#### ✅ DO: Handle Errors at Each Step

```swift
Task {
    do {
        try await remoteMatchService.acceptChallenge(matchId: matchId)
        try await remoteMatchService.joinMatch(matchId: matchId, currentUserId: currentUser.id)
        
        // Success - navigate
        await MainActor.run {
            router.push(.remoteLobby(...))
            processingMatchId = nil
        }
    } catch {
        // Error - clean up state
        await MainActor.run {
            processingMatchId = nil
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
```

---

### Navigation

#### ✅ DO: Clear State After Navigation Starts

```swift
await MainActor.run {
    router.push(.remoteLobby(...))  // Start navigation
    processingMatchId = nil  // Then clear flag
}
```

#### ❌ DON'T: Clear State Before Navigation

```swift
await MainActor.run {
    processingMatchId = nil  // ❌ Triggers re-render
    router.push(.remoteLobby(...))  // User sees intermediate state
}
```

#### ✅ DO: Filter Out Active Match from Lists

```swift
ForEach(remoteMatchService.pendingChallenges.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id  // ← Prevent duplicates
}) { matchWithPlayers in
```

#### ✅ DO: Guard Sections with Processing Flags

```swift
if let activeMatch = remoteMatchService.activeMatch,
   processingMatchId == nil {  // ← Don't show during operations
    ActiveMatchSection(match: activeMatch)
}
```

---

### Edge Functions

#### ✅ DO: Validate Status Appropriately

```typescript
// Allow cancellation in multiple states
if (
  match.remote_status !== 'sent' &&
  match.remote_status !== 'pending' &&
  match.remote_status !== 'ready' &&
  match.remote_status !== 'lobby'  // ← Allow lobby cancellation
) {
  return new Response(
    JSON.stringify({ error: 'Cannot cancel match in this state' }),
    { status: 400 }
  )
}
```

#### ❌ DON'T: Be Too Restrictive

```typescript
// ❌ Too restrictive - can't cancel from lobby
if (
  match.remote_status !== 'sent' &&
  match.remote_status !== 'pending' &&
  match.remote_status !== 'ready'
) {
  return new Response(
    JSON.stringify({ error: 'Can only cancel sent, pending, or ready matches' }),
    { status: 400 }
  )
}
```

#### ✅ DO: Return Helpful Error Messages

```typescript
if (!match_id) {
  return new Response(
    JSON.stringify({ 
      error: 'Missing required field: match_id',
      details: 'Please provide a valid match_id in the request body'
    }),
    { status: 400 }
  )
}
```

#### ✅ DO: Use Edge Functions for Complex Operations

**Good use cases:**
- Multi-step operations (accept → create locks → update status)
- Operations requiring validation across multiple tables
- Operations that need atomic transactions

**Bad use cases:**
- Simple single-table updates (use direct DB access)
- Operations that don't need server-side validation
- Operations where client has all needed data

---

## 5. Debugging Toolkit

### Color-Coded Logging System

Use emoji prefixes to categorize logs:

```swift
// 🟢 Green: UI/Button events
print("🟢 [DEBUG] Accept button tapped!")

// 🔴 Red: Closure invocations
print("🔴 [DEBUG] onAccept closure called from RemoteGamesTab")

// 🔵 Blue: Function calls
print("🔵 [DEBUG] acceptChallenge called with matchId: \(matchId)")

// 🟠 Orange: Alternative paths (decline, cancel)
print("🟠 [DEBUG] declineChallenge called")

// 🔄 Reload operations
print("🔄 [DEBUG] Reloading matches after join...")

// 🔍 Navigation/State checks
print("🔍 [DEBUG] Checking activeMatch for navigation...")

// ✅ Success
print("✅ [DEBUG] Navigating to lobby")

// ❌ Errors
print("❌ [DEBUG] Cannot navigate - activeMatch is nil")

// 🎯 Render events
print("🎯 [RENDER] Active Match section rendering")

// ⏱️ Timing logs
print("⏱️ [TIMING] MainActor.run START")
```

### Timing Logs for Async Flows

```swift
await MainActor.run {
    print("⏱️ [TIMING] MainActor.run START - processingMatchId: \(String(describing: processingMatchId))")
    print("⏱️ [TIMING] About to call router.push")
    
    router.push(.remoteLobby(...))
    
    print("⏱️ [TIMING] router.push called")
    
    processingMatchId = nil
    
    print("⏱️ [TIMING] processingMatchId set to nil")
    print("⏱️ [TIMING] MainActor.run END")
}
```

### State Tracking Patterns

```swift
print("🔍 [DEBUG] Checking activeMatch for navigation...")
print("🔍 [DEBUG] activeMatch exists: \(remoteMatchService.activeMatch != nil)")
if let activeMatch = remoteMatchService.activeMatch {
    print("🔍 [DEBUG] activeMatch.match.id: \(activeMatch.match.id)")
    print("🔍 [DEBUG] activeMatch.match.status: \(activeMatch.match.status?.rawValue ?? "nil")")
}
print("🔍 [DEBUG] currentUser exists: \(authService.currentUser != nil)")
```

### Console Output Analysis

**Successful Accept Flow:**
```
🟢 [DEBUG] Accept button tapped!
🔴 [DEBUG] onAccept closure called from RemoteGamesTab
🔵 [DEBUG] acceptChallenge called with matchId: [UUID]
✅ [DEBUG] Guard passed, setting processingMatchId
🔍 Getting headers for accept-challenge...
🚀 Calling accept-challenge with match_id: [UUID]
✅ Challenge accepted: [UUID]
🔍 Getting headers for join-match...
🚀 Calling join-match with match_id: [UUID]
✅ Match joined: [UUID]
⏱️ [TIMING] MainActor.run START
⏱️ [TIMING] About to call router.push
✅ [DEBUG] Navigating to lobby
⏱️ [TIMING] router.push called
⏱️ [TIMING] processingMatchId set to nil
⏱️ [TIMING] MainActor.run END
```

**Failed Flow (Opponent Not Found):**
```
🟢 [DEBUG] Accept button tapped!
🔴 [DEBUG] onAccept closure called
🔵 [DEBUG] acceptChallenge called
❌ [DEBUG] Cannot find match in pendingChallenges  ← Problem!
```

### Common Failure Patterns

**Pattern 1: Async Race Condition**
```
✅ Match joined
🔄 Reloading matches...
✅ Matches reloaded
🔍 Checking activeMatch...
❌ activeMatch is nil  ← Race condition!
```

**Pattern 2: State Mutation Before Guard**
```
🔵 acceptChallenge called
✅ Setting processingMatchId  ← Set too early
❌ Cannot find match  ← Guard fails
(processingMatchId never cleared - button stuck)
```

**Pattern 3: Background Reload During Navigation**
```
✅ Navigating to lobby
🔄 Background reload started  ← Interferes with navigation
🎯 Active Match section rendering  ← Unwanted render
```

---

## 6. Quick Reference

### Checklist for New Async Operations

- [ ] Capture all needed data at function start (before any async calls)
- [ ] Add guard checks BEFORE setting processing flags
- [ ] Use synchronous checks in critical paths (avoid Task{})
- [ ] Clear processing flags AFTER navigation, not before
- [ ] Filter out activeMatch from all challenge lists
- [ ] Guard sections with processing flags to prevent flicker
- [ ] Add color-coded debug logging
- [ ] Add timing logs for async flows
- [ ] Handle errors and clean up state
- [ ] Avoid background reloads during navigation
- [ ] Test the complete flow end-to-end

### Common Pitfalls & Solutions

| Pitfall | Solution |
|---------|----------|
| Button doesn't respond | Check for async race in loadMatches - make checks synchronous |
| UI flickers during operation | Clear processing flags AFTER navigation, not before |
| Card doesn't disappear | Remove background reloads, add activeMatch filters |
| Navigation fails silently | Capture opponent data early, before state changes |
| Button stays disabled | Add guard checks BEFORE setting processingMatchId |
| Active section shows during accept | Guard section with `processingMatchId == nil` |

### Code Snippets for Common Patterns

**Capture Data Early:**
```swift
func performAction(matchId: UUID) {
    guard let matchWithPlayers = remoteMatchService.pendingChallenges
        .first(where: { $0.match.id == matchId }) else {
        return
    }
    let opponent = matchWithPlayers.opponent
    let match = matchWithPlayers.match
    
    processingMatchId = matchId
    
    Task {
        // Use captured data
    }
}
```

**Synchronous Check:**
```swift
case .lobby:
    let hasJoined = await checkIfUserJoinedMatch(matchId: match.id, userId: userId)
    await MainActor.run {
        if hasJoined {
            active = matchWithPlayers
        }
    }
```

**Navigation with Cleanup:**
```swift
await MainActor.run {
    router.push(.destination(...))
    processingMatchId = nil
}
```

**Filter Active Match:**
```swift
ForEach(remoteMatchService.pendingChallenges.filter { 
    !expiredMatchIds.contains($0.id) && 
    $0.id != remoteMatchService.activeMatch?.id
}) { matchWithPlayers in
```

**Guard Section:**
```swift
if let activeMatch = remoteMatchService.activeMatch,
   processingMatchId == nil {
    ActiveMatchSection(match: activeMatch)
}
```

### Troubleshooting Decision Tree

```
Issue: Button not responding
├─ Check console logs
│  ├─ No logs at all → Button action not wired up
│  ├─ Logs stop at guard → Guard check failing
│  └─ Logs complete but no navigation → Check activeMatch
│     ├─ activeMatch is nil → Async race in loadMatches
│     └─ activeMatch exists → Navigation code issue
│
Issue: UI flickering
├─ Check when processingMatchId is cleared
│  ├─ Before navigation → Move to after
│  └─ After navigation → Check for background reloads
│
Issue: Card doesn't disappear
├─ Check for background reloads → Remove them
├─ Check activeMatch filters → Add to all lists
└─ Check Active Match section guard → Add processingMatchId check
│
Issue: Navigation fails
├─ Check opponent lookup timing
│  ├─ After async operations → Capture early
│  └─ Before async operations → Check guard logic
│
Issue: Button stays disabled
└─ Check guard order
   ├─ processingMatchId set before guards → Move after
   └─ Error handling → Ensure processingMatchId cleared in catch
```

---

## Related Documentation

- `REMOTE_ACCEPT_BUTTON_FIX_SUMMARY.md` - Async race condition fix
- `FIX_RECEIVER_NAVIGATION_TIMING_V2.md` - processingMatchId timing
- `FIX_RECEIVER_CARD_AFTER_ACCEPT.md` - Background reload issue
- `FIX_RECEIVER_ACTIVE_MATCH_TIMING.md` - Active match section guard
- `REMOTE_MATCH_FIXES_SUMMARY.md` - Earlier fixes (auth, RLS, locks)

---

## Key Files Reference

- `RemoteGamesTab.swift` - Main UI with accept/decline/cancel functions
- `RemoteMatchService.swift` - Service layer with loadMatches, cancelChallenge, joinMatch
- `FriendsService.swift` - Simple pattern reference (acceptFriendRequest, denyFriendRequest)
- `supabase/functions/cancel-match/index.ts` - Edge function with status validation
- `supabase/functions/accept-challenge/index.ts` - Edge function for accepting
- `supabase/functions/join-match/index.ts` - Edge function for joining

---

**Last Updated:** 2026-02-22

**Status:** Complete reference guide based on real issues and solutions

---
