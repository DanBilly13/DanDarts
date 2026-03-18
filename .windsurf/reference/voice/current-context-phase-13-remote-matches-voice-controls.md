---
trigger: manual
---

# Current Context — Phase 13: Remote Matches Voice Controls

## Project Overview

The app is a darts scoring app with both local and remote play.

Relevant gameplay contexts:

- **Local matches**
  - same-device play
  - no voice feature in this phase

- **Remote matches**
  - asynchronous / remote multiplayer flow
  - lobby
  - gameplay
  - end game
  - replay
  - voice feature applies here only

Current remote game types already in active use include:

- Remote 301
- Remote 501

The broader app also supports non-remote game types such as:

- 301
- 501
- Knockout
- Killer
- Halve It
- Sudden Death

## Product Context

A remote match is a turn-based asynchronous game backed by Supabase and existing remote-flow infrastructure. The app already supports:

- creating remote challenges
- accepting and joining matches
- playing remote turns with server-authoritative state
- showing end game and match history
- replaying from remote end game
- loading history lazily for performance
- working remote voice chat between players

Voice itself is already live and working. This phase is **not** about building voice chat from scratch or changing the core remote match flow. This phase is about improving the **voice control surface inside remote gameplay**, so players can better understand voice status and later control audio output options such as speaker and Bluetooth.

## Phase

**Phase 1 — Voice control menu shell**

## Why This Phase Exists

Voice chat is now working reliably enough that the next step is to improve the control surface around it. We do **not** want to tackle menu design, audio routing, speaker output, Bluetooth routing, and fallback behavior all at once.

This phase is intentionally focused on building the **UI shell and state contract first**, without destabilising the live voice implementation.

## Design Decision

Use **Voice B** as the design direction for this phase.

That means:

- the remote gameplay screen gets a compact **voice status/control button** in the top-left
- tapping it opens a small **menu / popover**
- the visible control reflects overall voice state better than a plain mic-only icon
- the menu can show route options and mute in a structured way

## Phase 1 Goal

Build the **voice menu UI** and its supporting state model.

At the end of this phase, the app should have a clean, stable voice control surface that:

- matches the **Voice B** direction
- displays **connected** vs **unavailable** state clearly
- exposes route choices in the menu
- exposes mute in the menu
- is safe to ship even if only part of the routing is truly active underneath

## What Is In Scope for Phase 1

### 1) Replace the current top-left voice button behavior

The current button should evolve from a simple icon tap into a proper entry point for voice controls.

Expected behavior:

- tap the voice control button
- show a popover / menu / anchored panel
- menu closes when dismissed normally

### 2) Implement the Voice B menu structure

The menu should include:

- a **status header**
- a list of **output route rows**
- a **mute** control row

Recommended structure:

- **Header**
  - `Voice connected` when voice is available
  - `Voice unavailable` when voice failed or is not available

- **Route rows**
  - Speaker
  - Bluetooth
  - Phone

- **Footer / last row**
  - Mute toggle

### 3) Implement voice state presentation

The top-level button should visually communicate voice state.

For this phase:

- **Connected / available** state should look active
- **Unavailable** state should look disabled or failed
- the selected route can appear in the menu, even if routing is not fully implemented yet

### 4) Add a clean state model behind the menu

Before routing logic expands, define a stable UI-facing model.

Suggested state model:

- `voiceAvailability`
  - available
  - unavailable

- `voiceConnectionState`
  - idle
  - connecting
  - connected
  - failed / unavailable

- `selectedOutputRoute`
  - speaker
  - bluetooth
  - phone

- `availableOutputRoutes`
  - list of currently supported or currently visible route options

- `isMuted`

This state model is important even if some values are partially stubbed in Phase 1.

## What Is Deliberately Out of Scope for Phase 1

Do **not** try to fully solve routing yet.

That means:

- no full speaker routing implementation yet
- no Bluetooth routing implementation yet
- no advanced device discovery work yet
- no route persistence polish yet
- no attempt to perfect phone / earpiece behavior yet

Phase 1 is about **surface + structure**, not full audio device control.

## Behavior Guidance for Phase 1

### Connected state

When voice is working:

- top-left control appears active
- menu header shows `Voice connected`
- one route row can appear selected
- mute row is enabled

### Unavailable state

When voice is not available:

- top-left control reflects unavailable state
- menu header shows `Voice unavailable`
- optional short helper copy can explain that voice could not connect
- route rows should be disabled
- mute should also be disabled

### Route rows in Phase 1

For now, treat route rows primarily as **UI/state rows**.

Recommended behavior:

- Phone can remain the default / current practical route
- Speaker and Bluetooth can exist visually before they are fully live
- only wire a route row to real behavior if it is safe and already supported

## Product Reasoning

This phased approach is intentional:

- **Phase 1** builds the control surface
- **Phase 2** adds real speaker output
- **Phase 3** adds Bluetooth support

This reduces risk and makes debugging much easier.

If something breaks later, we will know whether the issue is:

- menu / UI state
- speaker routing
- Bluetooth routing
- voice session lifecycle

## Proposed Future Phases

### Phase 2 — Speaker output

Add real speaker routing.

Goal:

- allow the user to switch between current / default route and speaker
- make the menu actually control speaker output
- keep behavior stable during a live remote match

### Phase 3 — Bluetooth output

Add Bluetooth / external route support.

Goal:

- detect supported Bluetooth audio routes
- show Bluetooth only when relevant / available
- allow switching cleanly
- handle disconnects safely

## Notes on Route Priority

For the actual product, likely priority is:

1. Speaker
2. Bluetooth
3. Phone

Phone is probably the least important real-world play mode, but it should remain present for now because it is the current fallback / baseline behavior.

## UX Notes

- The visible control should communicate more than “there is a microphone.”
- The menu is the right place for the detailed controls.
- Users should be able to understand at a glance whether voice is working.
- Mute should remain easy to find and easy to toggle.

## Suggested Implementation Guardrails

- Do not rewrite the working voice session lifecycle unless necessary.
- Keep menu UI separate from low-level audio route logic.
- Keep route state in one place.
- Do not block gameplay if voice is unavailable.
- Unavailable voice should degrade gracefully.

## Acceptance Criteria for Phase 1

Phase 1 is complete when:

- the **Voice B** direction is reflected in the gameplay UI
- the top-left voice control opens a menu / popover
- connected and unavailable states are both represented visually
- the menu shows status, route rows, and mute
- unavailable state disables the route controls cleanly
- the implementation does not regress the currently working voice experience
- the code structure clearly supports later speaker and Bluetooth phases

## Nice-to-Have, But Not Required in Phase 1

- perfect animation polish
- exact final iconography
- exact final copy for unavailable state
- permanent route memory
- Bluetooth-specific edge case handling

## Summary

This phase is **not** about solving all audio routing.

This phase is about creating the **right control surface first**, using **Voice B**, so that speaker and Bluetooth can be added safely in later phases without destabilising the working voice feature.