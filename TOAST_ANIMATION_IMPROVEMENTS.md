# Toast Notification Animation Improvements

## Overview
Enhanced friend request toast notifications with smooth, notification-like animations and configurable delays for a polished user experience.

## New Features

### 1. Separate Animation Configuration File
Created `FriendRequestToastAnimations.swift` for easy experimentation with animation parameters.

### 2. Animation Presets
Four pre-configured animation styles:

- **`.default`** - Balanced, smooth animations (0.5s slide-in, 0.8s delay)
- **`.snappy`** - Fast, responsive animations (0.35s slide-in, 0.5s delay)
- **`.smooth`** - Elegant, slower animations (0.7s slide-in, 1.0s delay)
- **`.bouncy`** - Playful, springy animations (0.6s slide-in, 0.6s delay)

### 3. Configurable Parameters
Each preset includes:
- `slideInDuration` - How long the toast takes to slide in
- `slideOutDuration` - How long the toast takes to slide out
- `slideInResponse` - Spring response for entry animation
- `slideInDamping` - Spring damping for entry animation
- `slideOutResponse` - Spring response for exit animation
- `slideOutDamping` - Spring damping for exit animation
- `initialDelay` - Delay before showing toast on app launch/return
- `opacityDuration` - Fade animation duration

### 4. Initial Delay on App Launch
When a user has a pending friend request on app launch or when returning to the app:
- Toast waits 0.8 seconds (configurable) before animating in
- Gives the app time to settle and feel more polished
- Prevents jarring immediate notifications

### 5. Smooth Slide Animations
- Toasts slide in from the top with spring physics
- Combined slide + opacity animations for natural feel
- Separate slide-out animations when dismissed

## Implementation Details

### ToastAnimationConfig
```swift
struct ToastAnimationConfig {
    let slideInDuration: Double
    let slideOutDuration: Double
    let slideInResponse: Double
    let slideInDamping: Double
    let slideOutResponse: Double
    let slideOutDamping: Double
    let initialDelay: Double
    let opacityDuration: Double
    
    static let `default` = ToastAnimationConfig(...)
    static let snappy = ToastAnimationConfig(...)
    static let smooth = ToastAnimationConfig(...)
    static let bouncy = ToastAnimationConfig(...)
}
```

### ToastTransition
```swift
struct ToastTransition {
    let config: ToastAnimationConfig
    
    var slideIn: Animation { ... }
    var slideOut: Animation { ... }
    var opacity: Animation { ... }
    var entry: AnyTransition { ... }
}
```

### Usage in FriendRequestToastManager
```swift
// Show toast immediately (realtime events)
await FriendRequestToastManager.shared.showToast(toast)

// Show toast with delay (app launch/return)
await FriendRequestToastManager.shared.showToast(toast, delay: config.initialDelay)
```

## Files Modified

1. **FriendRequestToastAnimations.swift** (NEW)
   - Animation configuration system
   - Four preset styles
   - Helper structs for transitions

2. **FriendRequestToastManager.swift**
   - Added `animationConfig` property
   - Added `delay` parameter to `showToast()`
   - Implements delay with Task.sleep

3. **FriendRequestToastView.swift**
   - Updated `FriendRequestToastContainer` to use `ToastTransition`
   - Replaced hardcoded animations with configurable ones
   - Uses `.transition(transition.entry)` and `.animation(transition.slideIn)`

4. **FriendsService.swift**
   - Updated `checkForPendingRequestsOnReturn()` to use delay
   - Reads delay from `animationConfig.initialDelay`

## Experimenting with Animations

To change the animation style, simply modify the initialization in `FriendRequestToastManager`:

```swift
// In FriendRequestToastManager.swift, line 27
private init(animationConfig: ToastAnimationConfig = .default) {
    self.animationConfig = animationConfig
}
```

Change `.default` to:
- `.snappy` for faster animations
- `.smooth` for more elegant animations
- `.bouncy` for playful animations

Or create a custom configuration:
```swift
let custom = ToastAnimationConfig(
    slideInDuration: 0.6,
    slideOutDuration: 0.4,
    slideInResponse: 0.5,
    slideInDamping: 0.7,
    slideOutResponse: 0.4,
    slideOutDamping: 0.8,
    initialDelay: 1.2,  // Longer delay
    opacityDuration: 0.3
)
```

## User Experience

### Before:
- Toast appeared instantly (no animation)
- Felt abrupt and jarring
- No distinction between immediate and delayed notifications

### After:
- Smooth slide-in from top with spring physics
- Delayed appearance on app launch (0.8s) feels polished
- Immediate appearance for realtime events feels responsive
- Smooth slide-out when dismissed
- Combined with opacity fade for natural feel

## Testing

1. **Realtime notification** - Send friend request while app is open
   - Should appear immediately with smooth slide-in
   
2. **App launch notification** - Have pending request, then sign in
   - Should wait 0.8s, then smoothly slide in
   
3. **App return notification** - Background app with pending request, return
   - Should wait 0.8s, then smoothly slide in
   
4. **Dismiss animation** - Tap X button
   - Should smoothly slide out to top

## Future Enhancements

Potential improvements:
- User preference for animation speed
- Different animations for different toast types
- Bounce effect on initial appearance
- Swipe-to-dismiss gesture
- Queue animation when multiple toasts pending
