# Task 1 — Architecture Boundaries for Voice Chat
**Phase:** 12  
**Sub-phase:** A (Foundation)  
**Status:** Defined  
**Date:** 2026-03-14

---

## Purpose

This document establishes the architectural boundaries and ownership model for peer-to-peer voice chat in remote matches before any implementation begins.

---

## Core Architectural Rule

### Voice is a Remote Flow Feature, Not a Screen Feature

Voice chat must be owned by the **shared remote match flow layer**, not by individual SwiftUI views.

**Why this matters:**
- Remote matches navigate through multiple screens: lobby → gameplay → end game → replay
- If voice is owned by a single view, it will be torn down during navigation transitions
- Previous phases have shown that features attached to the wrong layer create fragile lifecycle bugs

**Implementation consequence:**
- Voice session must be managed at the same architectural level as the remote match flow itself
- Voice lifecycle must use the same hooks and signals as remote match lifecycle
- Voice must not create a parallel disconnect/cleanup system

---

## Ownership Model

### What Owns Voice

The voice session is owned by the **remote match flow coordinator/manager**.

This is the same layer that currently manages:
- Remote match state synchronization
- Realtime channel subscriptions
- Remote match lifecycle (start, active, ended)
- Disconnect detection and cleanup
- Navigation coordination between lobby/gameplay/end game/replay

### What Does NOT Own Voice

Voice is **not** owned by:
- `RemoteLobbyView`
- `RemoteGameplayView` (or any gameplay view variant)
- `GameEndView`
- Any individual SwiftUI screen

These views may **display** voice state and **trigger** voice actions (like mute), but they do not own the session lifecycle.

**Critical boundary:**
- Views must never directly create, own, or tear down peer connections
- All peer connection lifecycle operations must go through the voice service

---

## Voice Lifecycle

### When Voice Starts

Voice session **initialization** begins when:
- The **receiver** enters the lobby after accepting a challenge
- This is the earliest point where both players are committed to the match

**Important distinction:**
- Voice session setup starts at this point
- Live audio is **not** yet active
- Actual audio only becomes active after the challenger joins and signalling/handshake completes

**Technical trigger:**
- Receiver's lobby `onAppear` or equivalent flow entry point
- Voice service creates WebRTC offer
- Offer is published to the match's Realtime channel
- Audio becomes live only after successful peer connection establishment

### When Voice Stays Active

Voice remains active through all these states:
- **Lobby** — waiting for countdown
- **Gameplay** — active match turns
- **End game** — match completion screen
- **Replay** — viewing the completed match again

**Key principle:**
- As long as the remote match flow context is active, voice stays alive
- Navigation between these screens does NOT terminate voice

### When Voice Terminates

Voice session ends when:
- Either player exits to the main games tab
- Either player abandons the match
- The remote match flow ends unexpectedly (crash, force quit, etc.)
- Existing remote disconnect handling triggers cleanup

**Critical implementation rule:**
- Voice teardown must use the **same lifecycle hooks** as remote match teardown
- Do not build a separate parallel system for voice cleanup
- Voice cleanup should be triggered by the same signals that clean up match state, Realtime subscriptions, etc.

---

## Integration with Existing Remote Match Flow

### Current Remote Match Architecture

The app already has a remote match flow system that manages:

1. **Match creation and acceptance**
   - Challenger creates challenge
   - Receiver accepts challenge
   - Both enter lobby

2. **Lobby coordination**
   - Players ready state
   - Countdown synchronization
   - Match start trigger

3. **Gameplay state synchronization**
   - Turn-based play
   - Server-authoritative state
   - Realtime updates

4. **End game and replay**
   - Match completion
   - Winner determination
   - Replay capability

5. **Disconnect handling**
   - Network loss detection
   - Cleanup on exit
   - State consistency

### Voice Integration Points

Voice hooks into this existing flow at these points:

**Entry point:**
- Receiver enters lobby → voice session starts

**Active state:**
- Voice runs in parallel with match state
- Voice state is independent of match state
- Voice failure never blocks match progression

**Exit point:**
- Remote match flow cleanup → voice session cleanup
- Use existing disconnect/exit hooks

---

## Phase 12 Scope Boundaries

### What IS in Phase 12

- STUN-based direct peer connection
- Supabase Realtime signalling
- WebRTC audio transport
- Local mute control
- Honest connection state UI
- Background audio support (screen lock)
- Non-blocking failure behavior

### What is NOT in Phase 12

- **TURN relay** — deferred to reliability follow-up
- **Automatic reconnect** — deferred, may add later if needed
- **Remote mute sync** — local mute only
- **Group voice** — two players only
- **Push-to-talk** — always-on mic (with mute)
- **Voice recording** — no logging or recording
- **Android support** — iOS only
- **Local match voice** — remote matches only

### TURN-Ready Design Constraint

While TURN is not implemented in Phase 12, the architecture must be designed so TURN can be added later without rearchitecting the entire voice pipeline.

**What this means:**
- Signalling contract should support ICE candidate exchange generically
- Peer connection setup should accept TURN server configuration
- Connection state model should handle relay vs direct connections
- No hardcoded assumptions that all connections are direct

---

## Non-Blocking Philosophy

### Voice Never Blocks Match Flow

This is a critical product rule:

- Voice connection failure → match still starts normally
- Voice drop mid-match → gameplay continues unaffected
- Voice unavailable → no disruptive alert, just honest UI state

**Why:**
- Voice is an enhancement, not a requirement
- Match state is server-authoritative and must always work
- Some users will be on networks where STUN-only connections fail
- Phase 12 accepts this limitation rather than blocking users

### Honest UI State

"Non-blocking" does not mean "pretend it worked":

- If voice is connecting → show "Connecting voice..."
- If voice is connected → show "Voice ready"
- If voice failed → show "Voice not available"

The UI must never show a false connected state.

---

## State Independence

### Voice State vs Match State

Voice state and match state are **independent**:

- Match can be active while voice is unavailable
- Voice can drop while match continues
- Voice failure does not affect match validity
- Match completion does not immediately terminate voice (it continues through end game and replay)

### Mute State

Mute is **local only**:

- Tapping mute affects the local microphone
- Mute state does not sync to the other player
- Each player controls their own mic independently
- The other player has no visibility into mute state

---

## Dependency and Service Architecture

### Voice Service Layer

Create a dedicated voice service/manager:

**Responsibilities:**
- Manage WebRTC peer connection lifecycle
- Handle signalling message exchange
- Maintain voice session state
- Provide mute/unmute controls
- Expose connection state for UI binding

**Dependencies:**
- Supabase Realtime (for signalling)
- AVAudioSession (for audio configuration)
- WebRTC framework (for peer connection)

**Injection:**
- Should be injected at the same level as other remote match services
- The voice service should live in / be injected from the same shared layer that already survives lobby → gameplay → end game transitions
- Accessible to the remote match flow coordinator
- Observable by UI views for state display

### Separation of Concerns

- **Voice service** — owns WebRTC session, signalling, audio
- **Remote match flow** — owns lifecycle, triggers voice start/stop
- **UI views** — observe state, trigger mute actions, display controls

---

## Background Audio Requirements

### iOS Background Mode

Voice must continue when the device screen locks during a remote match.

**Required capability:**
- Enable "Audio, AirPlay and Picture in Picture" background mode in Xcode

**AVAudioSession configuration:**
- Expected starting point: Category `.playAndRecord`, Mode `.voiceChat`
- Common options include: `.allowBluetooth`, `.defaultToSpeaker`
- Final option set will be validated during implementation and testing
- Configuration may be adjusted based on real-world audio behavior

**Interruption handling:**
- Phone calls
- Siri
- Other audio apps
- Route changes (headphones plugged/unplugged)

---

## Error Handling Philosophy

### Graceful Degradation

Voice errors should degrade gracefully:

- Connection failure → show unavailable state, match continues
- Mid-match drop → show disconnected state, match continues
- Signalling timeout → show unavailable state, match continues

### No Disruptive Alerts

Do not show alerts for:
- Voice connection failure
- Voice drop during match
- STUN connection timeout

**Instead:**
- Update status line in lobby
- Update control icon state
- Log errors for debugging
- Continue match flow normally

### When to Show Alerts

**For microphone permissions:**
- Normal iOS first-time permission prompt (system-level)
- Additional app-level explanatory UI only if genuinely necessary for user understanding

**For critical failures:**
- Only show alerts for audio session failures that prevent the app from functioning

**Clarification:**
- "No disruptive alerts" applies to connection issues (failure, drop, timeout)
- Permission-related UX is allowed where necessary for user consent and understanding

---

## Testing and Validation Strategy

### Key Test Scenarios

1. **Happy path**
   - Both players on good networks
   - Voice connects before countdown ends
   - Voice stays active through full flow

2. **Failure path**
   - Voice fails to connect
   - Match still starts normally
   - UI shows unavailable state honestly

3. **Mid-match drop**
   - Voice drops during gameplay
   - Match continues unaffected
   - UI updates to disconnected state

4. **Lifecycle continuity**
   - Voice survives lobby → gameplay
   - Voice survives gameplay → end game
   - Voice survives end game → replay
   - Voice terminates on exit to main tab

5. **Background behavior**
   - Screen locks during match
   - Voice continues
   - Screen unlocks, voice still active

6. **Interruptions**
   - Phone call interrupts voice
   - Voice resumes after call ends
   - Match state unaffected

### Validation Checkpoints

Each sub-phase has its own approval checkpoint:
- Foundation approved before signalling work begins
- Signalling approved before voice engine work begins
- Voice engine approved before UI integration begins
- UI integration approved before lifecycle work begins
- Lifecycle approved before validation phase begins

---

## Architecture Decision Records

### ADR 1: Voice Owned by Remote Match Flow

**Decision:** Voice session is owned by the remote match flow layer, not individual views.

**Rationale:**
- Voice must survive navigation between lobby/gameplay/end game/replay
- Previous phases showed that screen-owned features create lifecycle bugs
- Remote match flow already manages similar lifecycle concerns

**Consequences:**
- Voice service injected at flow level
- Views observe state but don't own session
- Cleanup uses existing flow hooks

### ADR 2: STUN-First, TURN-Ready

**Decision:** Phase 12 uses STUN only, but architecture must support TURN later.

**Rationale:**
- STUN is free and works for most users
- TURN adds cost and complexity
- Better to ship STUN-first and add TURN based on real-world failure rates

**Consequences:**
- Some users behind strict NAT will fail to connect
- Signalling contract must support generic ICE candidates
- Peer connection setup must accept TURN configuration
- Connection failure is expected and handled gracefully

### ADR 3: Non-Blocking Failure

**Decision:** Voice failure never blocks match progression.

**Rationale:**
- Voice is an enhancement, not a requirement
- Match state is server-authoritative and must always work
- Some networks will fail STUN-only connections

**Consequences:**
- Match can start without voice
- Match can continue if voice drops
- UI must show honest state without disruption

### ADR 4: No Automatic Reconnect in Phase 12

**Decision:** If voice drops, it stays disconnected for that match flow.

**Rationale:**
- Reconnect adds complexity
- Unclear if it's needed without real-world data
- Can add later if testing shows it's valuable

**Consequences:**
- Dropped voice shows as unavailable
- Players can exit and restart match if voice is critical
- Simpler implementation for Phase 12
- If reconnect is added in a later phase, it must also remain non-blocking and flow-owned

---

## Success Criteria for Task 1

This task is complete when:

- ✅ Architecture ownership model is documented
- ✅ Voice lifecycle rules are defined
- ✅ Integration points with existing remote match flow are identified
- ✅ Phase 12 scope boundaries are clear
- ✅ TURN-ready design constraints are documented
- ✅ Non-blocking philosophy is established
- ✅ State independence rules are defined
- ✅ Service architecture is outlined

**Approval checkpoint:** Architecture boundaries reviewed and accepted before Task 2 begins.

---

## Next Task

**Task 2:** Define the voice session state model

This will create the state enums and model that represent voice connection state, mute state, and session validity.
