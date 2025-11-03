# Stats Refresh Fix - Implementation Notes

## Problem Statement
After completing a match, player statistics would update correctly in Supabase but would not refresh in the app UI until the user logged out and logged back in.

## Root Causes Identified

### 1. Wrong User Data Being Returned
- `MatchService.updatePlayerStats()` was looping through all players and returning the LAST player's updated data
- When you played against Tony and won, it would return Tony's stats instead of yours
- This was because the loop kept overwriting `updatedCurrentUser` for every player

### 2. AuthService.shared Returning Nil
- When accessing `AuthService.shared.currentUser?.id` inside a background Task, it returned `nil`
- The singleton wasn't properly accessible from the background thread context
- This caused the check `userId == AuthService.shared.currentUser?.id` to always fail

### 3. Multiple AuthService Instances
- Even after fixing the above, we were updating `AuthService.shared` but views were observing a different instance from `@EnvironmentObject`
- This meant the update happened but the UI didn't see it

## Solution Implemented

### Architecture: Dependency Injection Pattern

#### 1. ViewModel Changes (`CountdownViewModel.swift`)
```swift
// Added authService property
private var authService: AuthService?

// Added injection method
func setAuthService(_ service: AuthService) {
    self.authService = service
}

// Capture currentUserId BEFORE entering Task (on main thread)
let currentUserId = authService?.currentUser?.id

// Pass it to MatchService
let updatedUser = try await matchService.saveMatch(
    // ... other params
    currentUserId: currentUserId
)

// Update the INJECTED authService (not AuthService.shared)
if let updatedUser = updatedUser {
    await MainActor.run {
        self.authService?.currentUser = updatedUser
        self.authService?.objectWillChange.send()
    }
}
```

#### 2. View Changes (`CountdownGameplayView.swift`)
```swift
.onAppear {
    // Inject authService into the ViewModel
    gameViewModel.setAuthService(authService)
}
```

#### 3. Service Changes (`MatchService.swift`)
```swift
// Added currentUserId parameter
func saveMatch(
    // ... other params
    currentUserId: UUID? = nil
) async throws -> User? {
    // Pass it to updatePlayerStats
    updatedUser = try await updatePlayerStats(
        winnerId: winnerId, 
        players: players, 
        currentUserId: currentUserId
    )
}

// Updated to accept and use currentUserId
private func updatePlayerStats(
    winnerId: UUID, 
    players: [Player], 
    currentUserId: UUID?
) async throws -> User? {
    // Only return data if this player IS the current user
    if let passedUserId = currentUserId {
        if userId == passedUserId {
            updatedCurrentUser = updatedUser
            print("📌 This is the authenticated user - will return their updated data")
        }
    }
}
```

## The Complete Flow

1. **View Initialization** → `.onAppear` injects `authService` into ViewModel
2. **Match Completes** → `saveMatchToSupabase()` is called
3. **Capture User ID** → `currentUserId = authService?.currentUser?.id` (on main thread)
4. **Background Task** → Passes `currentUserId` to `MatchService`
5. **Update Supabase** → Both players' stats updated in database
6. **Filter Response** → Only return YOUR updated data (where `userId == currentUserId`)
7. **Update AuthService** → `authService.currentUser = updatedUser`
8. **UI Refreshes** → Profile and player cards show new stats immediately! 🎉

## Key Learnings

### 1. Singleton Pattern Isn't Enough
- Even with `AuthService.shared`, accessing it from different contexts (main thread vs background Task) can cause issues
- Dependency injection ensures the ViewModel has the SAME instance that views are observing

### 2. Thread Context Matters
- Capturing values on the main thread before entering a Task is safer than accessing them inside
- `AuthService.shared.currentUser?.id` works on main thread but may be `nil` in background context

### 3. ObservableObject Updates
- Updating `currentUser` alone isn't enough - must call `objectWillChange.send()` to trigger SwiftUI refresh
- Must update the SAME instance that views are observing via `@EnvironmentObject`

## Testing Checklist

- [x] User wins a match → Profile shows updated W/L immediately
- [x] Friend wins a match → Friend's player card shows updated W/L when navigating back to setup
- [x] Guest players work correctly (no userId, stats don't update)
- [x] Multi-player matches update all connected players' stats
- [x] NotificationCenter triggers friends list reload

## Files Modified

- `DanDart/ViewModels/Games/CountdownViewModel.swift` - Added authService injection, currentUserId capture
- `DanDart/Views/Games/Countdown/CountdownGameplayView.swift` - Added `.onAppear` to inject authService
- `DanDart/Services/MatchService.swift` - Added currentUserId parameter, updated filtering logic
- `DanDart/Views/Games/Countdown/CountdownSetupView.swift` - Added NotificationCenter listener for match completion

## Future Considerations

### For Other Game Modes
- `HalveItViewModel` will need the same pattern
- Any future game ViewModels should follow this dependency injection approach

### Alternative Approaches Considered
1. **Delay + Refresh** - Added delays before calling `refreshCurrentUser()` - didn't work due to read-after-write consistency
2. **Direct Database Query** - Querying immediately after update returned stale data
3. **Singleton Only** - `AuthService.shared` wasn't accessible from background context

### Why This Solution Works Best
- No delays or polling needed
- No extra database queries
- Immediate UI updates
- Proper separation of concerns
- Testable (can inject mock AuthService)

---

**Date Fixed:** November 3, 2025  
**Developer:** Daniel Billingham (with Cascade AI assistance)
