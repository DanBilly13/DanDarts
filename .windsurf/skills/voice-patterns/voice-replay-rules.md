> Supporting reference for: voice-patterns  
> Apply when: working on replay lobby voice, voice session rebinding, 
> replayReadyMatchId handling, or debugging voice readiness issues 
> that only appear in replay flows  
> Do not apply to: first-time match voice flow, general lobby 
> integration, or connection state details unless the issue is 
> replay-specific

# Voice Replay Rules

## Purpose

This document defines how voice behaves in replay flows in Dart Freak.

Replay voice is different from first-time match voice because the
WebRTC session already exists and must be reused rather than rebuilt
from scratch.

It exists to prevent the most common replay voice mistake: assuming
first-time voice flow applies to replay.

---

## Core Rule

Replay reuses the existing voice session via rebind.

It does not create a new session from scratch.
After rebind, voice readiness must be re-announced and re-confirmed
for the new match.

---

## Replay Voice Strategy

```
Replay match created
        ↓
rebindSessionForReplay() called
        ↓
WebRTC components reused, signaling channel rebound for new match
        ↓
replayReadyMatchId published by VoiceChatService
        ↓
RemoteLobbyView observes replayReadyMatchId
        ↓
confirmVoiceReady(matchId:) called for replay match
        ↓
Server sets *_voice_ready_at for new match
        ↓
Normal countdown evaluation proceeds
```

---

## Rebind vs Rebuild

| | Rebind (correct) | Rebuild (wrong) |
|--|-----------------|-----------------|
| WebRTC peer connection | reused | destroyed and recreated |
| Signaling channel | rebound for new match | rebuilt from scratch |
| Audio state | preserved | restarted |
| Session overhead | minimal | full reconnection cost |

Always rebind for replay.
Never destroy and recreate the session for replay.

---

## replayReadyMatchId

`replayReadyMatchId` is the signal that rebind completed
successfully.

```swift
@Published private(set) var replayReadyMatchId: UUID? = nil
```

When `replayReadyMatchId` is set, `RemoteLobbyView` should:
1. observe the published value
2. call `confirmVoiceReady(matchId:)` for the replay match
3. let the server set the authoritative timestamps

---

## Re-announcement Rule

Voice readiness timestamps from the original match do not carry
over to the replay match.

The replay match is a new server row with its own:
- `challenger_voice_ready_at`
- `receiver_voice_ready_at`
- `voice_connect_deadline`

Both players must re-confirm voice readiness for every replay match.

---

## Voice and Replay Lifecycle Separation

Keep these separate:

### Voice/session layer
- WebRTC peer connection reuse
- signaling channel rebind
- `replayReadyMatchId` publication
- local readiness signal

### Replay lifecycle layer
- replay match status
- lobby entry for replay
- `confirmVoiceReady()` RPC call
- authoritative timestamp confirmation
- countdown evaluation

Voice rebind completing does not mean replay lifecycle is ready.
`replayReadyMatchId` being set does not mean the server has
confirmed readiness.
`confirmVoiceReady()` must still be called.

---

## Common Replay Voice Mistakes

### Mistake: assuming voice is ready because rebind succeeded
Rebind is a local operation.
Server timestamps are still nil until `confirmVoiceReady()` is
called.

### Mistake: skipping re-announcement for replay
Voice ready timestamps from the original match do not apply to
replay.
Always re-confirm for the new match.

### Mistake: rebuilding instead of rebinding
Creating a new voice session for replay adds unnecessary overhead
and can cause connection issues.
Use `rebindSessionForReplay()`.

### Mistake: treating replayReadyMatchId as server confirmation
`replayReadyMatchId` signals local rebind completion.
It does not mean the server has set `*_voice_ready_at`.

### Mistake: coupling replay navigation to voice rebind
Replay lobby navigation should follow authoritative replay lifecycle
state, not voice rebind completion.

---

## Relationship to Replay Lifecycle

From `replay-realtime-rules.md` and `replay-navigation-rules.md`:

- realtime triggers reload, not direct state trust
- replay lobby navigation waits for authoritative confirmation
- voice rebind is one input into lobby readiness, not the decision

Voice rebind success is necessary but not sufficient for replay
lobby progression.

---

## Bottom Line

Replay rebinds the existing voice session.
Rebind completion triggers re-announcement via `replayReadyMatchId`.
Re-announcement triggers `confirmVoiceReady()` for the new match.
Server timestamps reset for every replay.
Voice rebind is not replay lifecycle readiness.
