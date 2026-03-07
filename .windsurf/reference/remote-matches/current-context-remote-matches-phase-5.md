---
trigger: manual
---

# DanDart — current-context (Phase 5)

## Project (short)
DanDart is a native iOS darts scoring companion app built with SwiftUI + Supabase (auth, sync, realtime).
It supports:
- **Local games**: players score together in the same room on one device
- **Remote matches**: matches played from different locations (challenge → lobby → gameplay)

Current focus is **Remote Matches**.

---

## Current focus: Remote Matches (Phase 5)

### Status
- Phases 1–4 are complete.
- Phase 5 is mostly complete, but gameplay has correctness + sync issues.
- Primary goal right now: make Remote Gameplay reliable end-to-end (checkouts + win propagation + lobby abort).

### Known issues (Phase 5)
1) Checkout / finishing logic is buggy
- Checkout validation sometimes incorrect (finishes / busts / remaining score edge cases).
- Result: players can end up with inconsistent score state or unexpected outcomes.

2) Win state doesn’t reliably propagate to the opponent
- When one player wins, the other player doesn’t always transition/end.
- Likely cause: realtime updates not consistently driving client state transitions, or the receiving client ignores/overwrites the “ended” state.

3) Abort-from-lobby edge function errors
- The “abort game from lobby” path currently errors (edge function +/or client call).
- Needs a clean, reliable abort outcome for both players (and correct UI exit state).

### What “done” means for Phase 5
- Checkout logic is deterministic + matches expected darts rules.
- When match ends (win/abort), BOTH clients converge to the same final state within realtime update latency.
- Lobby abort works without throwing, and cleans up match state + UI navigation reliably.

### Where to look first (code pointers)
- RemoteGameplayView / RemoteGameplayViewModel (or RemoteGameVM): scoring + checkout + win detection
- RemoteMatchService realtime UPDATE handling: status transitions + ensuring opponent receives terminal state
- RemoteLobbyView abort flow: client callsite + edge function contract + error handling

### Reference docs (do not load unless needed)
- Remote matches overview + requirements:
  - .windsurf/reference/remote-matches/remote-matches-frd-v2.md
- Historical build phases:
  - .windsurf/reference/remote-matches/remote-matches-phase-1-2-3.md
  - .windsurf/reference/remote-matches/remote-matches-phase-4.md
  - .windsurf/reference/remote-matches/remote-matches-phase-4-tasks.md
- Task tracker:
  - .windsurf/reference/remote-matches/remote-matches-task-list-v2.md