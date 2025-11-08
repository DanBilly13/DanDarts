# Guest Player Avatar Upload Fix

## Problem
Camera roll photo selection worked when creating a new account with email, but not when creating guest players in game setup views.

## Root Cause
`AddGuestPlayerView` was missing the `.onChange(of: selectedPhotoItem)` handler that loads the selected photo data into a `UIImage`. Without this handler:
1. User selects photo from camera roll
2. `PhotosPickerItem` is set in the binding
3. Photo data is never loaded/converted to `UIImage`
4. Guest player is saved with only the default avatar

## Solution Implemented

### 1. Added Photo Selection Handler to AddGuestPlayerView
**File:** `Views/Players/AddGuestPlayerView.swift`

Added `.onChange` modifier to handle photo selection:
```swift
.onChange(of: selectedPhotoItem) { _, newItem in
    Task {
        await handlePhotoSelection(newItem)
    }
}
```

Added `handlePhotoSelection` method:
```swift
private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
    guard let item = item else { return }
    
    do {
        guard let data = try await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }
        
        selectedAvatarImage = uiImage
    } catch {
        print("Failed to load photo: \(error.localizedDescription)")
    }
}
```

### 2. Added Local Avatar Storage for Guest Players
**File:** `Services/GuestPlayerStorageManager.swift`

Added methods to save custom avatar images to local storage:

**saveCustomAvatar(image:for:)**
- Resizes image to 512px max dimension
- Compresses to JPEG (80% quality)
- Saves to `Documents/guest_avatars/{playerId}.jpg`
- Returns file path for storage in `Player.avatarURL`

**deleteCustomAvatar(at:)**
- Deletes custom avatar file when guest player is removed
- Called automatically by `deleteGuestPlayer(id:)`

### 3. Updated Guest Player Save Logic
**File:** `Views/Players/AddGuestPlayerView.swift`

Updated `savePlayer()` method to:
1. Check if custom image was selected (`selectedAvatarImage`)
2. If yes: Save image to local storage and use file path as `avatarURL`
3. If no: Use predefined avatar asset name

```swift
// If custom image was selected, save it to local storage
if let customImage = selectedAvatarImage {
    let playerId = UUID()
    if let savedPath = GuestPlayerStorageManager.shared.saveCustomAvatar(image: customImage, for: playerId) {
        avatarURL = savedPath
    }
    // Create player with saved file path
}
```

### 4. Updated Avatar Display Components to Support File Paths

**File:** `Views/Components/AsyncAvatarImage.swift`
**File:** `Utilities/AvatarHelper.swift` (PlayerAvatarView)

Added support for loading images from file paths:
```swift
} else if avatarURL.hasPrefix("/") || avatarURL.contains("/Documents/") {
    // File path - load from local storage
    let fileURL = URL(fileURLWithPath: avatarURL)
    if let imageData = try? Data(contentsOf: fileURL),
       let uiImage = UIImage(data: imageData) {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}
```

Now handles three types of avatar URLs:
1. **Remote URLs** (`http://` or `https://`) - AsyncImage/CachedAsyncImage
2. **File paths** (starts with `/` or contains `/Documents/`) - UIImage from file
3. **Asset names** (anything else) - Image from asset catalog

## Files Modified
1. `Views/Players/AddGuestPlayerView.swift` - Added photo selection handler and save logic
2. `Services/GuestPlayerStorageManager.swift` - Added avatar storage methods
3. `Views/Components/AsyncAvatarImage.swift` - Added file path support
4. `Utilities/AvatarHelper.swift` - Added file path support to PlayerAvatarView

## Testing
1. Open any game setup view (301, 501, Halve-It, Sudden Death)
2. Tap "Add Guest Player"
3. Tap camera icon in avatar selector
4. Select photo from camera roll
5. Photo should appear in the avatar selector
6. Enter name and nickname
7. Tap "Save Player"
8. Guest player should be created with custom photo
9. Photo should display in player selection and during gameplay

## Storage Details
- **Location:** `Documents/guest_avatars/`
- **Format:** JPEG, 80% quality
- **Size:** Max 512px dimension
- **Naming:** `{playerId}.jpg`
- **Cleanup:** Automatic deletion when guest player is removed

## Consistency with Account Creation
This implementation mirrors the avatar upload flow in `ProfileSetupView`:
- Same photo selection handler pattern
- Same image resizing/compression (512px, 80% JPEG)
- Same user experience
- Different storage (local files vs Supabase for guests vs authenticated users)
