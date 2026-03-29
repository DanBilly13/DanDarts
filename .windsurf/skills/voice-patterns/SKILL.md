---
name: voice-patterns
description: voice chat rules for dart freak. use when working on VoiceChatService, voice connection state, lobby voice readiness, voice ready server fields, replay voice rebinding, microphone permissions, or any bug where voice is blocking match flow, failing silently, creating duplicate sessions, or not confirming readiness correctly. also use when tasks mention voice, VoiceChatService, confirmVoiceReady, replayReadyMatchId, voice_connect_deadline, challenger_voice_ready_at, or receiver_voice_ready_at. do not use for local matches, non-voice realtime behavior, or general lobby flow unless the question is specifically about voice integration.
---

# Voice Patterns

Use this skill when working on any voice chat behavior in Dart Freak.

## Core Rule

Voice is an enhancement, not a gate.

Match flow must never be blocked by voice state.
Voice failures are non-blocking by design.
The match continues even if voice fails.

## Architecture

- `VoiceChatService.swift` — singleton, owns all voice state
- `VoicePermissionManager.swift` — microphone permissions, decoupled from match timing
- Always use `VoiceChatService.shared` — never instantiate directly

## Connection State Model
```swift
enum VoiceSessionState {
    case idle        // no session exists
    case connecting  // handshake in progress
    case connected   // peer connection established, audio active
    case failed      // connection failed or lost
}
```

Voice failure does not stop gameplay.
Turn progression continues regardless of voice state.
Voice can reconnect independently of game state.

## Voice and Server Fields

Voice readiness is proven by authoritative server timestamps:

- `challenger_voice_ready_at`
- `receiver_voice_ready_at`
- `voice_connect_deadline`

The correct way to confirm voice readiness is:
```swift
try await remoteMatchService.confirmVoiceReady(matchId: matchId)
```

Never set `*_voice_ready_at` fields directly on the client.

## Voice and Countdown

Two paths to countdown:

- **Immediate** — both `*_voice_ready_at` set → countdown starts now
- **Fallback** — `voice_connect_deadline` passed → countdown starts 
regardless of voice state

Voice is not required for the match to start.

## Replay Voice

Replay rebinds the existing session rather than rebuilding from scratch.

After rebind, voice readiness must be re-announced and re-confirmed
via `confirmVoiceReady()` for the new match.

`replayReadyMatchId` is published by `VoiceChatService` to signal
that the rebind completed and re-announcement should happen.

## What This Skill Prevents

- blocking match flow on voice connection state
- setting server voice timestamp fields directly from the client
- creating duplicate voice sessions
- skipping voice session cleanup on view disappear
- coupling voice state to game turn logic
- treating voice connection as proof of lifecycle readiness

## Supporting References

- `voice-connection-states.md` — full state machine and availability 
model
- `voice-lobby-integration.md` — lobby flow, server fields, countdown 
relationship
- `voice-replay-rules.md` — rebind strategy and replay re-announcement
- `voice-anti-patterns.md` — explicit never-do list with safe 
alternatives

## Relationship to Other Skills

This skill answers: **how should voice behave in remote flows?**

Use alongside:
- `remote-match-lifecycle` for lobby and countdown lifecycle context
- `realtime-patterns` for how voice readiness triggers refetch
- `swiftui-navigation` for lobby view lifecycle and cleanup guards
- `supabase-patterns` for confirmVoiceReady RPC patterns

## Bottom Line

Voice is always non-blocking.  
Server fields prove readiness, not local connection state.  
One singleton, one session, always clean up.