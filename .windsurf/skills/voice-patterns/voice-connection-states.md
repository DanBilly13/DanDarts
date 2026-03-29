> Supporting reference for: voice-patterns  
> Apply when: working on VoiceChatService connection state, voice 
> availability, mute behavior, or debugging unexpected voice state 
> transitions  
> Do not apply to: lobby flow integration, replay voice, or server 
> field confirmation unless the question is specifically about 
> connection state

# Voice Connection States

## Purpose

This document defines the voice connection state model in Dart Freak.

It exists so Windsurf understands what each voice state means, what
drives transitions between states, and what the availability model
controls — before touching any voice state logic.

---

## Core Rule

Voice state is owned by `VoiceChatService.shared`.

Do not derive voice state from local assumptions.
Do not infer voice readiness from connection state alone.
Server fields prove readiness — local state does not.

---

## Session State Machine

```swift
enum VoiceSessionState {
    case idle        // no session exists for current flow
    case connecting  // WebRTC handshake in progress
    case connected   // peer connection established, audio active
    case failed      // connection failed or lost
}
```

### State transitions

| From | To | Trigger |
|------|----|---------|
| idle | connecting | `startSession()` called in lobby |
| connecting | connected | WebRTC handshake completed, peer ready |
| connecting | failed | WebRTC failure, timeout, or error |
| connected | failed | Connection lost during gameplay |

### Key published state

```swift
@Published private(set) var connectionState: VoiceSessionState = .idle
@Published private(set) var currentSession: VoiceSession?
```

---

## Mute State

```swift
enum VoiceMuteState {
    case unmuted  // microphone active, audio being sent
    case muted    // microphone muted, no audio sent
}
```

Mute is user-controlled and independent of connection state.
A connected session can be muted or unmuted at any time.

```swift
@Published private(set) var muteState: VoiceMuteState = .unmuted
```

---

## Availability Model

```swift
enum VoiceAvailability {
    case notApplicable      // voice not relevant here (e.g. local match)
    case available          // voice applicable and usable
    case systemUnavailable  // voice applicable but system prevents use
}
```

```swift
@Published private(set) var availability: VoiceAvailability = .notApplicable
```

### What availability controls

- `notApplicable` — local matches, non-voice contexts
- `available` — remote match lobby and gameplay
- `systemUnavailable` — microphone permission denied, device constraints

### Important rule

`systemUnavailable` does not block match flow.
It only means voice enhancement is not possible in this session.

---

## Voice Independence Rule

Voice connection failure does not stop gameplay.

- Turn progression continues regardless of voice state
- Match start continues regardless of voice state
- Voice can reconnect independently of game state
- `failed` state is non-blocking by design

---

## Session Ownership Rule

`VoiceChatService` is a singleton.

```swift
static let shared = VoiceChatService()
```

- Always use `VoiceChatService.shared`
- Never instantiate directly
- Never create a second session while one exists
- Always check `currentSession == nil` before starting a new session

---

## Cleanup Rule

Always end the session when the owning view disappears.

```swift
.onDisappear {
    voiceChatService.endSession()
}
```

Missing cleanup causes memory leaks and stale session state.

---

## Permission Handling

Microphone permissions are owned by `VoicePermissionManager.shared`.

Permission handling is deliberately decoupled from match timing.
Permission dialogs must not interfere with match flow.

---

## Common State Mistakes

### Mistake: blocking on connected state
Voice connection is not required for match progression.
Never gate match flow on `connectionState == .connected`.

### Mistake: inferring readiness from connection state
`connected` does not mean voice is confirmed ready on the server.
Server readiness comes from `*_voice_ready_at` timestamps, not from
local connection state.

### Mistake: creating duplicate sessions
Always check `currentSession` before calling `startSession()`.

---

## Bottom Line

Voice state lives in `VoiceChatService.shared`.

`connected` means audio is active locally.
It does not mean the server knows voice is ready.
It does not mean the match can start.
Those are separate concerns.
