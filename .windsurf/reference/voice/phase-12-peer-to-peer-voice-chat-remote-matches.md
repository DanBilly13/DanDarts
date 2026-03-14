# Phase 12 — Peer-to-Peer Voice Chat for Remote Matches (iOS)

**Platform:** iOS only  
**Status:** Revised for implementation planning  
**Phase:** 12

---

## Overview

Remote matches currently have no live voice communication between players. This phase adds peer-to-peer voice chat so players can talk during a remote match, continue talking through the end game view, and keep the same voice session alive during replay, only terminating when either player exits the remote match context entirely.

The initial implementation uses WebRTC with Supabase Realtime signalling and STUN-based direct connectivity. This avoids introducing a paid voice platform for the first release. The architecture should remain TURN-ready so relay support can be added later as a reliability follow-up if needed.

---

## Core Product Position

This should be treated as a **remote match flow feature**, not a screen feature.

Voice must belong to the shared remote match flow layer so it survives:

- lobby
- gameplay
- end game
- replay

It must not be owned by an individual SwiftUI screen, otherwise navigation between views will make the voice lifecycle fragile and inconsistent.

---

## Goals

- Players can speak to each other during a remote match
- Voice is established before the match starts, during the lobby countdown
- Either player can mute themselves at any point
- Voice continues through the end game view and replay
- Voice terminates cleanly when either player exits the remote match context
- Voice failure must never delay countdown, block lobby progression, or prevent the match from starting
- Audio continues when the phone screen locks
- The signalling/session design stays TURN-ready for a later reliability phase

---

## Technical Approach

The initial implementation uses three components, all with no additional paid voice platform:

### Supabase Realtime — signalling channel
- Exchanges the small connection messages needed to establish the WebRTC peer connection
- Already in use for match state
- No new signalling service required

### Google STUN server — connection setup
- Helps each device discover its public IP for direct peer connectivity
- Public server: `stun.l.google.com:19302`
- No account required

### WebRTC — audio transport
- Carries the actual audio stream device-to-device
- Used for the live peer audio connection
- The implementation should use the iOS/WebRTC stack appropriate for the app architecture

---

## Reliability Boundary for Phase 12

### Phase 12 scope
- STUN-first direct connection attempt only
- No TURN relay yet
- No automatic reconnect logic if voice drops mid-match

### Planned reliability follow-up
Some users behind stricter NAT/firewall setups may fail to establish a direct peer connection with STUN alone. That is normal WebRTC behavior and should be treated as a known limitation of the first release.

Future follow-up:
- Add TURN relay fallback for failed direct connections
- Add optional reconnect behavior if needed after initial rollout

Important constraint now:
- The signalling/session layer should be designed so TURN can be added later **without rearchitecting the full voice pipeline**

---

## Match Flow Integration

Voice hooks into the existing remote match flow without changing match-state behavior.

### Receiver accepts
- Receiver enters lobby
- Receiver creates a WebRTC offer
- Offer is published to the match Realtime channel

### Challenger joins
- Challenger taps Join and enters lobby
- Challenger receives the offer
- Challenger sends back an answer
- Handshake completes

### Lobby countdown
- Lobby continues behaving normally
- Voice attempts to connect during the existing countdown window
- On normal mobile networks, voice should typically connect before the 5 second countdown ends
- Failure to connect must not affect match start

### Match starts
- Voice is already active when successful
- Players can hear each other immediately

### Match ends
- Voice remains active on the end game view
- The remote match context is still active

### Replay
- Voice continues in the same session
- Replay is treated as continuing inside the same remote match context

### Either player exits to main tab
- Voice terminates for both players
- Teardown is triggered by the same remote-flow exit/disconnect lifecycle

---

## Lobby Voice Status

A small voice status line should sit underneath **Players Ready** in the lobby.

This gives honest feedback without any disruptive alerting or blocking behavior.

States:

- **Connecting voice...** — handshake in progress, dimmed, subtle pulse
- **Voice ready** — connected, neutral or soft positive tint
- **Voice not available** — failed/unavailable, dimmed, low-drama presentation

Rules:
- Countdown behavior is unaffected by all three states
- Voice failure should be visible, but never alarming
- The UI must never show a false connected state

---

## Voice Lifecycle

### When voice starts
- Receiver enters the lobby after accepting the challenge

### When voice stays active
- During gameplay
- On end game view
- During replay

### When voice terminates
- Either player taps back to the main games tab
- Either player abandons or disconnects mid-match
- The remote match flow ends unexpectedly
- Existing remote disconnect handling tears the session down

Important:
- Voice teardown should use the **same remote match lifecycle hooks and disconnect signals**
- Do not build a separate parallel disconnect system for voice

That avoids cases where:
- match is disconnected but audio remains open
- audio disconnects but the app still thinks the session is valid

---

## Reconnect Behavior (Phase 12 scope)

For this phase:

- Gameplay continues uninterrupted if voice drops
- Voice loss never affects match state
- The icon and status line must reflect disconnection honestly
- No automatic reconnect attempt in phase 12
- If the connection drops, it shows as unavailable for the remainder of that match flow

Reconnect behavior can be added later if real-world testing shows it is needed.

---

## Controls and UX

## Voice control placement

### Lobby
- Place the voice control in the **top-left**
- Keep the existing help control on the **top-right**
- This avoids crowding the help affordance and keeps voice consistent and visible

### Gameplay
- Keep the voice control in the **top-left**
- Keep help on the **top-right**
- The voice control should remain in the same general location across lobby and gameplay

This consistency matters more than saving a few pixels of space.

---

## Icon language

Use SF Symbols:

- `microphone` — connected / open mic
- `microphone.slash` — connected / locally muted

For unavailable/disconnected, use a mic-based treatment rather than a refresh/retry metaphor. The base visual identity should remain clearly voice-first.

Recommended state mapping:

- **Connecting** — `microphone` with subtle pulsing opacity
- **Connected, mic open** — `microphone`
- **Connected, muted** — `microphone.slash`
- **Failed / unavailable** — mic-based unavailable treatment, dimmed warning tint

Important UX note:
- Avoid using a circular refresh/reconnect-looking symbol as the primary control state
- The control should read immediately as **voice/mute**, not **retry/sync**

---

## Mute behavior

- Tapping the control mutes the **local microphone only**
- It does not mute the other player
- Mute state is local-only and does not sync to the other device

Rules:
- Mute state transitions must be stable
- Icon state should not flicker during transient signalling changes
- The control should always prioritize clarity over animation

---

## Failure handling

If voice fails:

- The match still starts normally
- No disruptive alert is shown
- The status line and icon must honestly reflect the unavailable state
- Match progression is never blocked or delayed

Important clarification:
- “Silent failure” means **no interruptive alert**
- It does **not** mean pretending the connection worked

---

## Background audio

To support voice during screen lock/background use:

- Enable the iOS background mode: **Audio, AirPlay and Picture in Picture**
- Configure `AVAudioSession` correctly for voice chat behavior
- Handle interruptions appropriately, including:
  - phone calls
  - Siri
  - route changes
  - audio session interruptions

Goal:
- Voice should continue when the device screen locks during a remote match flow

---

## Design Guidance

### What looks strong already
- A compact single-button voice control is the right approach
- Top-corner placement keeps the scoring interface clean
- Carrying the same control through lobby and gameplay creates consistency
- A lobby status line under **Players Ready** gives the feature a natural home

### What should be adjusted
- The voice control should be on the **top-left**
- Help remains on the **top-right**
- The base symbol should clearly read as **microphone / mute**
- The visual treatment should stay quieter than primary gameplay controls like **Save Score**
- Connected state should feel calm and neutral, not overly “alert colored”

### State styling guidance
- **Connecting:** dimmed, subtle pulse
- **Connected:** neutral/active
- **Muted:** clearly muted but still calm
- **Unavailable:** dimmed warning tint, not dramatic red failure UI

---

## Out of Scope

- Android support
- TURN relay implementation
- Automatic reconnect after mid-match drop
- Group voice for more than two players
- Push-to-talk
- Voice in local same-device matches
- Voice recording or logging
- Remote mute sync

---

## Success Criteria

- Players can hear each other during a remote match
- On normal mobile networks, voice typically connects before the 5 second countdown ends
- Lobby shows accurate voice connection status underneath **Players Ready**
- Voice control is placed top-left and help remains top-right
- The voice control uses clear microphone-based SF Symbols
- Mute button correctly reflects both connection state and local mute state
- The UI never shows a false connected state
- Voice continues through gameplay, end game, and replay without being torn down by navigation
- Voice terminates for both players when either exits the remote match flow
- Voice failure never blocks or delays the match from starting
- Audio continues when the phone screen locks
- The signalling/session architecture is ready for a later TURN reliability follow-up
- No new paid voice service is required for the initial release

---

## Recommendation

This is a strong MVP direction for voice in remote matches.

The key implementation rule is:

> Build voice as part of the shared remote match flow layer, not as a per-screen feature.

The key UX rule is:

> Make the control read immediately as microphone/mute, keep it top-left, and let the lobby status line communicate connection truth without ever blocking match flow.
