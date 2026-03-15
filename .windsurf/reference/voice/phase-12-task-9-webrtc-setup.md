# Phase 12 Task 9: WebRTC Setup Instructions

## Add WebRTC Package to Xcode

Since WebRTC requires manual package addition in Xcode, follow these steps:

### Option 1: Official Google WebRTC (Recommended)

1. Open `DanDart.xcodeproj` in Xcode
2. Select the project in the navigator
3. Select the "DanDart" target
4. Go to "Package Dependencies" tab
5. Click the "+" button
6. Enter package URL: `https://github.com/stasel/WebRTC.git`
7. Select "Up to Next Major Version" with minimum version `125.0.0`
8. Click "Add Package"
9. Select "WebRTC" product
10. Click "Add Package"

### Why This Package?

- **stasel/WebRTC** is a well-maintained Swift Package Manager wrapper for Google's WebRTC
- Pre-compiled binaries (no need to build WebRTC from source)
- Regular updates following Google WebRTC releases
- Used by many production iOS apps

### Alternative: Build from Source (Not Recommended)

If you prefer to build from Google's official source:
- URL: `https://github.com/webrtc-sdk/webrtc-ios`
- Much larger download and build time
- Same functionality

### Verification

After adding the package:

1. Build the project (Cmd+B)
2. Verify no "No such module 'WebRTC'" errors
3. The import statement `import WebRTC` should work in Swift files

### Next Steps

Once WebRTC package is added:
- Task 9 code is already implemented in `VoiceSessionService.swift`
- Build and test the signalling + WebRTC integration
- Proceed to Task 10 (ICE negotiation)

## WebRTC Configuration

The implementation uses:

- **STUN server:** `stun:stun.l.google.com:19302` (Google's public STUN)
- **Audio only:** No video tracks (voice chat only)
- **Codec:** Opus (optimized for voice)
- **Echo cancellation:** Enabled
- **Noise suppression:** Enabled
- **Auto gain control:** Enabled

## Phase 12 Limitations

- **STUN only:** No TURN relay (may fail on restrictive networks)
- **No reconnection:** Connection drops are permanent
- **No quality adaptation:** Fixed codec settings

These will be addressed in future phases if needed.
