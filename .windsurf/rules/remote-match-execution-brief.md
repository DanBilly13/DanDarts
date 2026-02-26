---
trigger: manual
---

# 🚀 Remote Matches --- Execution Brief (Before Phase 0)

Before starting implementation of Remote Matches in
`feature/remote-matches`, the following guardrails must be followed.

This brief overrides any assumptions not explicitly defined in the FRD
or Task List.

------------------------------------------------------------------------

# 1️⃣ Architecture Principles (Non-Negotiable)

## Server Is Authoritative For:

-   Match status transitions
-   Score updates
-   Visit persistence
-   Turn switching
-   Leg completion
-   Match completion

The client **must never**: - Predict turn switches - Increment scores
locally without server ack - Advance leg or match state locally

The client reacts to server state only.

------------------------------------------------------------------------

# 2️⃣ VISIT Logic (Locked Definition)

VISIT is shared and global within a leg.

Definition: - A visit = one player's saved turn (up to 3 darts). - VISIT
increments only after both players have completed that visit cycle.

For 2 players:

Turn order: A(0) → B(1) → A(2) → B(3)

VISIT formula:

    visit = (turnIndexInLeg / 2) + 1

Important: - VISIT does NOT increment when a player saves. - VISIT
increments only when a full pair of turns is complete. - VISIT resets to
1 when a new leg starts.

This applies to both Local and Remote modes.

------------------------------------------------------------------------

# 3️⃣ RemoteGameView Must Be Duplicated, Not Rebuilt

Remote gameplay must be implemented as:

Copy existing local 301/501 GameView\
→ Adapt for: - Realtime match binding - Turn lockout - Save visit server
call - Reveal delay (1--2s) - Rotation animation

Do not redesign layout.\
Do not partially reuse local state logic.\
Duplicate → adapt.

UI must remain visually identical to local unless explicitly stated.

------------------------------------------------------------------------

# 4️⃣ Turn Flow (Exact Order)

When active player taps "Save Visit":

1.  Disable input immediately (client)
2.  Call server saveVisit()
3.  Server:
    -   Validates score
    -   Persists visit
    -   Updates scores
    -   Switches currentPlayerId
    -   Updates turnIndexInLeg
4.  Server emits updated match state
5.  Both clients:
    -   Show saved visit reveal (1--2 seconds)
    -   Run card rotation animation
    -   Unlock input for new active player

Client must never rotate before server confirms.

------------------------------------------------------------------------

# 5️⃣ Challenge Concurrency Rule (Strict)

A user may have: - One Ready match - One In Progress match

When a match becomes Ready: - All other Pending and Sent challenges
become disabled/dimmed (not deleted) - They become actionable again only
if Ready match is cancelled or expires

This logic must be enforced server-side. Client UI reflects server
truth.

------------------------------------------------------------------------

# 6️⃣ Expiration Rules

Three separate time systems:

1)  Challenge expiry (e.g. 24h)
2)  Ready join window (e.g. 5 minutes)
3)  Match in progress (no expiry in v1)

Server transitions expired states. Client only renders expired state.

------------------------------------------------------------------------

# 7️⃣ Identity Is Static

Challenger = Red\
Receiver = Green

These identities: - Persist through gameplay - Persist through
EndGameView - Persist through MatchDetail / Stats

Never swap colors based on turn.

Turn indication is positional (front card), not color.

------------------------------------------------------------------------

# 8️⃣ No Client Prediction

The following are forbidden: - Optimistic turn switching - Optimistic
visit increment - Optimistic leg increment - Optimistic match completion

Everything must derive from authoritative backend state.

------------------------------------------------------------------------

# 9️⃣ Implementation Order (Must Follow Task List)

Work strictly in gated phases as defined in:

-   Remote Matches --- Full Implementation Task List (Gated Execution
    Plan) v2\
-   Remote Matches --- FRD v1.2

No skipping phases.\
No jumping ahead to UI polish before backend skeleton exists.

Each phase must be approved before proceeding.

------------------------------------------------------------------------

# 10️⃣ Definition of Success (Remote v1)

-   Deterministic lifecycle
-   No desync between players
-   No duplicate save corruption
-   One Ready + One In Progress max per user
-   Push notifications for:
    -   Challenge received
    -   Challenge accepted / Match ready
-   Local and Remote share identical gameplay UI structure

------------------------------------------------------------------------

This brief ensures:

-   No architectural drift
-   No authority confusion
-   No VISIT miscalculation
-   No UI redesign creep
-   No race-condition instability
