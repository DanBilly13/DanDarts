# Guest Player Local Storage Implementation

## Overview
Guest players are now saved to local storage and persist across app sessions. They appear in a dedicated "Guest Players" section in the player selection sheet.

## Files Created

### 1. GuestPlayerStorageManager.swift
**Location:** `/Services/GuestPlayerStorageManager.swift`

**Purpose:** Manages local storage of guest players using UserDefaults

**Key Methods:**
- `saveGuestPlayer(_ player: Player)` - Save a new guest player
- `loadGuestPlayers() -> [Player]` - Load all saved guests
- `deleteGuestPlayer(id: UUID)` - Delete guest by ID
- `deleteGuestPlayer(nickname: String)` - Delete guest by nickname
- `updateGuestPlayer(_ player: Player)` - Update existing guest
- `clearAllGuestPlayers()` - Clear all guests (testing/debugging)
- `guestExists(nickname: String) -> Bool` - Check if guest exists

**Storage:**
- Uses UserDefaults with key: `"savedGuestPlayers"`
- Stores guests as JSON-encoded array
- Prevents duplicate nicknames

## Files Modified

### 1. AddGuestPlayerView.swift
**Changes:**
- Added call to `GuestPlayerStorageManager.shared.saveGuestPlayer(newPlayer)` after creating guest
- Guests are automatically saved when created

### 2. GameSetupView.swift (SearchPlayerSheet)
**Changes:**
- Added `@State private var guestPlayers: [Player] = []`
- Added `.onAppear { loadGuestPlayers() }`
- Added new "Guest Players" section after "Your Friends"
- Added swipe-to-delete functionality for guest players
- Added `loadGuestPlayers()` helper method
- Added `deleteGuestPlayer(_ player: Player)` helper method
- Reload guests after adding new one

### 3. PlayerIdentity.swift
**Changes:**
- Removed `!isGuest` condition from nickname display
- Guest players now show their nicknames (previously hidden)

### 4. PlayerCard.swift
**Changes:**
- Moved "Guest" badge from left side to right side (where stats normally are)
- Guest players show "Guest" text instead of W/L stats
- Cleaner, more consistent layout

## UI Layout

### SearchPlayerSheet Sections:
1. **"You"** - Current user
2. **"Your Friends"** - Connected players from Supabase (with W/L stats)
3. **"Guest Players"** - Locally saved guests (with "Guest" label)
   - Only shown if guests exist
   - Swipe left to delete
   - Shows checkmark if already selected

## Features

### Guest Player Persistence
✅ Guests saved automatically when created
✅ Guests persist across app sessions
✅ Guests loaded on sheet appear
✅ No need to re-add guests each time

### Guest Management
✅ Swipe-to-delete on guest players
✅ Duplicate nickname prevention
✅ Clear separation from connected friends
✅ Shows "Guest" label instead of stats

### User Experience
✅ Seamless integration with existing flow
✅ Guests appear immediately after creation
✅ Easy to identify (separate section + "Guest" label)
✅ Simple deletion with swipe gesture

## Data Flow

### Creating a Guest:
1. User taps "+ Guest" button
2. Fills out AddGuestPlayerView form
3. Taps "Save Player"
4. Guest saved to GuestPlayerStorageManager
5. Callback fires with new player
6. SearchPlayerSheet reloads guests
7. Sheet dismisses
8. Guest appears in selected players

### Loading Guests:
1. SearchPlayerSheet appears
2. `onAppear` triggers
3. `loadGuestPlayers()` called
4. GuestPlayerStorageManager loads from UserDefaults
5. Guests displayed in "Guest Players" section

### Deleting a Guest:
1. User swipes left on guest player card
2. Taps "Delete" button
3. `deleteGuestPlayer()` called
4. GuestPlayerStorageManager removes from storage
5. `loadGuestPlayers()` refreshes list
6. Guest removed from UI

## Technical Details

### Storage Format:
```json
[
  {
    "id": "UUID",
    "displayName": "John Doe",
    "nickname": "johnd",
    "avatarURL": "avatar1",
    "isGuest": true,
    "totalWins": 0,
    "totalLosses": 0
  }
]
```

### UserDefaults Key:
- `savedGuestPlayers`

### Validation:
- Prevents duplicate nicknames
- Only saves players with `isGuest = true`
- Handles encoding/decoding errors gracefully

## Benefits

1. **Convenience** - No need to re-add regular playing partners
2. **Offline-first** - Works without internet connection
3. **Fast** - Instant loading from local storage
4. **Clean UI** - Clear separation between friends and guests
5. **Easy Management** - Simple swipe-to-delete

## Future Enhancements (Optional)

- Edit guest player details
- Guest player statistics tracking
- Export/import guest players
- Search/filter guest players
- Sort guests alphabetically
- Guest player avatars from photo library
