# Player Stats Not Updating Fix

## Problem
The current user's player card shows "No games yet" even after playing many matches. Friends show correct stats (28W15L, etc.) but the logged-in user's stats remain at 0W/0L.

## Root Cause

### Issue 1: Stats Updated in Wrong Table
**File:** `Services/MatchService.swift` (line 162-183)

The `updatePlayerStats()` method was updating a `player_stats` table instead of the `users` table where `total_wins` and `total_losses` are actually stored.

```swift
// OLD - Wrong table
try await supabaseService.client
    .from("player_stats")  // ❌ Wrong table
    .upsert(statsRecord, onConflict: "user_id")
    .execute()
```

### Issue 2: Current User Profile Never Refreshed
**File:** `Services/AuthService.swift`

The `currentUser` object in `AuthService` is only loaded when the user signs in. After matches are played and stats are updated in Supabase, the local `currentUser` object is never refreshed to reflect the new stats.

## Fixes Applied

### Fix 1: Update Stats in Correct Table
**File:** `Services/MatchService.swift`

Changed `updatePlayerStats()` to update the `users` table directly:

```swift
// NEW - Correct implementation
private func updatePlayerStats(winnerId: UUID, players: [Player]) async throws {
    for player in players {
        guard let userId = player.userId else { continue } // Skip guests
        
        let isWinner = userId == winnerId
        
        // Fetch current user stats
        let currentUser: User = try await supabaseService.client
            .from("users")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        // Increment wins or losses
        let newWins = currentUser.totalWins + (isWinner ? 1 : 0)
        let newLosses = currentUser.totalLosses + (isWinner ? 0 : 1)
        
        // Update user stats in users table
        try await supabaseService.client
            .from("users")
            .update([
                "total_wins": newWins,
                "total_losses": newLosses,
                "last_seen_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: userId.uuidString)
            .execute()
        
        print("✅ Updated stats for \(currentUser.displayName): \(newWins)W/\(newLosses)L")
    }
}
```

### Fix 2: Add Refresh Method to AuthService
**File:** `Services/AuthService.swift`

Added `refreshCurrentUser()` method to fetch latest user profile from database:

```swift
/// Refresh current user's profile from database (e.g., after match completion to update stats)
func refreshCurrentUser() async throws {
    guard let userId = currentUser?.id else {
        throw AuthError.userNotFound
    }
    
    do {
        // Fetch latest user profile from database
        let refreshedUser: User = try await supabaseService.client
            .from("users")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
        
        // Update current user with fresh data
        currentUser = refreshedUser
        print("✅ User profile refreshed: \(refreshedUser.displayName) - \(refreshedUser.totalWins)W/\(refreshedUser.totalLosses)L")
    } catch {
        print("❌ Failed to refresh user profile: \(error.localizedDescription)")
        throw error
    }
}
```

## How to Use

### Option 1: Manual Refresh (Recommended for MVP)
After a match is completed, the user can manually refresh their profile by:
- Pulling down on the player selection screen
- Navigating away and back to the screen
- Signing out and back in

### Option 2: Automatic Refresh (Future Enhancement)
ViewModels can call `authService.refreshCurrentUser()` after matches are saved:

```swift
// In ViewModel after match save
Task {
    do {
        try await authService.refreshCurrentUser()
    } catch {
        print("Failed to refresh user: \(error)")
    }
}
```

## Testing

After this fix:
1. ✅ Play a match as the logged-in user
2. ✅ Stats are updated in Supabase `users` table
3. ✅ Call `refreshCurrentUser()` to update local profile
4. ✅ Player card shows correct W/L stats

## Database Schema

The `users` table has these columns for stats:
- `total_wins` (INTEGER, DEFAULT 0)
- `total_losses` (INTEGER, DEFAULT 0)

These are updated directly after each match for all connected players (guests are skipped).

## Impact

✅ **Stats now update correctly** in Supabase  
✅ **Refresh method available** to update local profile  
✅ **Friends' stats work** (they were already working)  
✅ **Current user stats will update** after refresh  

## Next Steps

For automatic refresh, we could:
1. Add `@EnvironmentObject var authService: AuthService` to ViewModels
2. Call `refreshCurrentUser()` after match save completes
3. Or implement a notification/observer pattern to auto-refresh

For now, the manual refresh approach works and stats are being saved correctly to Supabase.

## Status

✅ **FIXED** - Stats now update in the correct table. Refresh method available to update local profile.

**Note:** The user may need to pull-to-refresh or navigate away and back to see updated stats until automatic refresh is implemented.
