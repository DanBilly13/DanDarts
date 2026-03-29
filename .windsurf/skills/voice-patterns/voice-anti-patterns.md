> Supporting reference for: voice-patterns  
> Apply when: reviewing voice-related code changes, debugging voice 
> bugs, or any situation where an AI assistant might suggest voice 
> patterns that could block match flow, corrupt server state, or 
> cause session management problems  
> Do not apply to: non-voice remote logic, local matches, or general 
> realtime behavior

# Voice Anti-Patterns

## Purpose

This document defines what Windsurf must never do when working on
voice chat in Dart Freak.

Voice mistakes are especially dangerous because they can silently
block match flow, corrupt server state, or cause duplicate session
problems that are hard to debug.

---

## Core Rule

Voice is an enhancement, not a gate.

Any code that treats voice as a hard requirement for match
progression is wrong by design.

---

## Anti-Pattern 1 — Blocking Match Flow on Voice State

```swift
// ❌ NEVER DO THIS
if voiceChatService.connectionState != .connected {
    return  // blocks match progression
}

// ✅ CORRECT
do {
    try await voiceChatService.startSession(...)
} catch {
    print("⚠️ Voice failed (non-blocking): \(error)")
    // match continues
}
```

Voice failures must be caught and ignored for match flow purposes.
Never return early or throw based on voice connection state alone.

---

## Anti-Pattern 2 — Setting Server Timestamp Fields Directly

```swift
// ❌ NEVER DO THIS
match.challenger_voice_ready_at = Date()
match.receiver_voice_ready_at = Date()

// ✅ CORRECT
try await remoteMatchService.confirmVoiceReady(matchId: matchId)
```

Server voice timestamps are authoritative.
They must only be set by the server via the correct RPC.
Client-side mutation of these fields corrupts countdown evaluation.

---

## Anti-Pattern 3 — Creating Duplicate Voice Sessions

```swift
// ❌ NEVER DO THIS
await voiceChatService.startSession(...)  // called twice
await voiceChatService.startSession(...)  // duplicate

// ✅ CORRECT
if voiceChatService.currentSession == nil {
    await voiceChatService.startSession(...)
}
```

Always check `currentSession` before starting a new session.
Duplicate sessions cause audio problems and state corruption.

---

## Anti-Pattern 4 — Skipping Voice Session Cleanup

```swift
// ❌ NEVER DO THIS
// view disappears with no cleanup

// ✅ CORRECT
.onDisappear {
    voiceChatService.endSession()
}
```

Always call `endSession()` when the owning view disappears.
Missing cleanup causes memory leaks and stale session state that
affects subsequent matches.

---

## Anti-Pattern 5 — Coupling Voice State to Game Logic

```swift
// ❌ NEVER DO THIS
if gameViewModel.currentPlayerIndex == voiceChatService.localPlayerIndex {
    // voice-coupled turn logic
}

// ✅ CORRECT
// voice works independently of turn state
// never derive turn logic from voice state
// never derive voice behavior from turn state
```

Voice is always on during gameplay regardless of whose turn it is.
Never mix voice state with game turn management.

---

## Anti-Pattern 6 — Adding ICE Candidates Without Safety Check

```swift
// ❌ NEVER DO THIS
peerConnection.add(iceCandidate)  // fails if remote description not set

// ✅ CORRECT
if hasRemoteDescription {
    peerConnection.add(iceCandidate)
} else {
    pendingRemoteICECandidates.append(candidate)
}
```

ICE candidates may arrive before the remote description is set.
Always queue candidates when remote description is not yet available.

---

## Anti-Pattern 7 — Treating Voice Connection as Lifecycle Proof

```swift
// ❌ NEVER DO THIS
if voiceChatService.connectionState == .connected {
    // assume lobby is ready to proceed
    navigateToGameplay()
}

// ✅ CORRECT
// lobby progression follows authoritative server fields
// fetchMatch() confirms in_progress
// then navigate
```

Local voice connection state does not prove server lifecycle state.
Navigation must always wait for authoritative confirmation.

---

## Anti-Pattern 8 — Rebuilding Voice Session for Replay

```swift
// ❌ NEVER DO THIS
voiceChatService.endSession()
await voiceChatService.startSession(...)  // full rebuild for replay

// ✅ CORRECT
await voiceChatService.rebindSessionForReplay()
// then observe replayReadyMatchId
// then call confirmVoiceReady() for new match
```

Replay reuses the existing session via rebind.
Full rebuild adds unnecessary overhead and can cause connection
issues.

---

## Anti-Pattern 9 — Skipping Re-announcement for Replay

```swift
// ❌ NEVER DO THIS
// assume original voice_ready_at timestamps carry over to replay

// ✅ CORRECT
// observe replayReadyMatchId
// call confirmVoiceReady(matchId:) for the new replay match
// let server set fresh timestamps
```

Every replay match needs fresh voice readiness confirmation.
Original match timestamps do not apply to replay.

---

## Anti-Pattern 10 — Bypassing VoiceChatService Singleton

```swift
// ❌ NEVER DO THIS
let voiceService = VoiceChatService()  // new instance

// ✅ CORRECT
let voiceService = VoiceChatService.shared
```

`VoiceChatService` is a singleton by design.
Creating additional instances causes unpredictable behavior.

---

## Quick Reference

| Never | Always |
|-------|--------|
| Block match on voice failure | Catch and continue |
| Set `*_voice_ready_at` directly | Call `confirmVoiceReady()` |
| Start session without checking current | Check `currentSession == nil` first |
| Skip cleanup on disappear | Call `endSession()` in `onDisappear` |
| Couple voice to turn logic | Keep voice independent |
| Add ICE without checking description | Queue in `pendingRemoteICECandidates` |
| Navigate from voice connection state | Wait for authoritative server state |
| Rebuild session for replay | Use `rebindSessionForReplay()` |
| Skip re-announcement for replay | Call `confirmVoiceReady()` for new match |
| Instantiate new VoiceChatService | Use `VoiceChatService.shared` |

---

## Bottom Line

Voice must never block the match.
Server fields must only be set by the server.
One singleton, one session, always clean up.
Replay rebinds — it does not rebuild.
