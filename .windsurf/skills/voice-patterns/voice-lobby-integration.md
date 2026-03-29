> Supporting reference for: voice-patterns  
> Apply when: working on lobby voice integration, confirmVoiceReady 
> calls, voice_connect_deadline behavior, countdown triggers related 
> to voice, or debugging lobby flow where voice readiness is a factor  
> Do not apply to: general lobby flow unrelated to voice, replay voice 
> behavior, or connection state details

# Voice Lobby Integration

## Purpose

This document defines how voice integrates with the remote lobby flow
in Dart Freak.

It exists so Windsurf understands the relationship between local voice
connection state and authoritative server voice fields — before
touching any lobby or voice readiness logic.

---

## Core Rule

Local voice connection is not the same as server-confirmed voice
readiness.

The match countdown evaluates server fields, not local connection
state.

---

## Authoritative Server Fields

```sql
challenger_voice_ready_at  TIMESTAMPTZ
receiver_voice_ready_at    TIMESTAMPTZ
voice_connect_deadline     TIMESTAMPTZ
```

These are the only fields that matter for countdown decisions.
Local voice state is irrelevant to the server's countdown evaluation.

---

## Lobby Voice Flow

```
Both players join lobby
        ↓
Server sets voice_connect_deadline (20-second window)
        ↓
VoiceChatService.startSession() called for each player
        ↓
Voice connection established (local)
        ↓
remoteMatchService.confirmVoiceReady(matchId:) called
        ↓
Server sets challenger_voice_ready_at / receiver_voice_ready_at
        ↓
Countdown evaluation runs
```

---

## Confirmation Rule

The correct way to confirm voice readiness:

```swift
try await remoteMatchService.confirmVoiceReady(matchId: match.id)
```

### What this does
- calls the server RPC
- server sets the appropriate `*_voice_ready_at` timestamp
- server evaluates whether countdown can now start

### What this does not do
- does not directly start the countdown
- does not set the timestamp on the client
- does not guarantee immediate countdown

---

## Never Set Timestamps Directly

```swift
// ❌ WRONG
match.challenger_voice_ready_at = Date()

// ✅ CORRECT
try await remoteMatchService.confirmVoiceReady(matchId: matchId)
```

Server timestamps must only be set by the server.

---

## Countdown Paths

### Immediate path
Both `challenger_voice_ready_at` and `receiver_voice_ready_at` are
non-null → countdown starts immediately.

### Fallback path
`voice_connect_deadline` has passed → countdown starts regardless
of voice readiness state.

Voice is not required for the match to start.
The fallback path exists specifically for voice failure scenarios.

---

## Countdown Evaluation Logic

```typescript
// Server-side evaluation
const bothVoiceReady =
    freshMatch.challenger_voice_ready_at !== null &&
    freshMatch.receiver_voice_ready_at !== null

if (trigger === 'immediate_voice_ready') {
    if (!freshMatch.challenger_voice_ready_at)
        blockers.push('challenger_voice_ready_false')
    if (!freshMatch.receiver_voice_ready_at)
        blockers.push('receiver_voice_ready_false')
}
```

The server evaluates fresh state.
Client assumptions about voice readiness are not consulted.

---

## Voice Window Timer

The `voice_connect_deadline` gives players 20 seconds to establish
voice connection and confirm readiness.

After the deadline:
- countdown proceeds via fallback path
- voice connection may still be in progress
- match is not blocked

---

## Lobby Phase and Voice

Voice connection overlaps with the connecting lobby phase:

| Lobby phase | Voice expectation |
|-------------|-------------------|
| waiting | voice not yet started |
| connecting | `startSession()` called, handshake in progress |
| timedOut | deadline passed, fallback path will trigger |
| countdown | voice may or may not be connected |

Voice connection failure does not prevent lobby phase progression.

---

## ICE Candidate Safety

WebRTC ICE candidates must be queued if the remote description is
not yet set.

```swift
if hasRemoteDescription {
    peerConnection.add(iceCandidate)
} else {
    pendingRemoteICECandidates.append(candidate)
}
```

Never add ICE candidates before the remote description is set.

---

## Common Mistakes

### Mistake: treating connected as confirmed ready
Local connection does not mean server timestamp is set.
Always call `confirmVoiceReady()` after connecting.

### Mistake: blocking countdown on voice
Countdown has a fallback path.
Never gate countdown logic on voice connection state.

### Mistake: calling confirmVoiceReady multiple times carelessly
Confirm calls should be idempotent.
Server handles repeated calls gracefully, but avoid unnecessary
duplicate calls.

### Mistake: skipping confirmVoiceReady on fast connection
Even when voice connects quickly, the server RPC must still be
called to set the authoritative timestamp.

---

## Bottom Line

Local voice connection enables audio.
`confirmVoiceReady()` proves it to the server.
Server timestamps drive countdown decisions.
Voice failure triggers the fallback path, not a blocked match.
