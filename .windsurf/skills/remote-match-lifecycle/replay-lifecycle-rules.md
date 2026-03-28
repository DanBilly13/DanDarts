> Supporting reference for: remote-match-lifecycle  
> Apply when: working on replay creation, replay request handling, replay card behavior, replay ready/lobby entry, replay cancellation or decline, or any bug where replay flow behaves differently from first-time remote matches  
> Do not apply to: ordinary first-time remote challenge flow unless the comparison with replay is the point, or to generic voice/realtime/navigation work that is not specifically about replay lifecycle behavior

# Replay Lifecycle Rules

## Purpose

This document defines how replay fits into the remote match lifecycle in Dart Freak.

Replay is not a completely separate game system, but it is also not just “the same match continuing.”

Replay is special because it starts from a completed remote match context and then creates a **new remote match** that re-enters the same broad lifecycle family.

This document exists to prevent mistakes such as:
- treating replay as the old match continuing
- skipping the early challenge phase because replay feels “already agreed”
- forgetting outgoing vs incoming replay asymmetry
- mixing replay overlay/UI state up with authoritative replay lifecycle state
- assuming replay readiness means gameplay is already authorized
- forgetting that replay still uses role-specific lifecycle logic

## Core Rule

Replay should be reasoned about as:

1. completed old match context
2. replay request creates a **new** remote match
3. that new replay match follows the remote lifecycle again
4. replay-specific UI/ownership rules may sit on top of that lifecycle

In short:

**replay is a new remote match in the same lifecycle family, started from a completed match context**

## Core Replay Principle

Replay reuses the normal remote lifecycle shape:

completed old match
→ replay request
→ new replay match created
→ pending
→ ready
→ lobby
→ in_progress
→ completed


That means replay is:
- not the old match resuming
- not a shortcut straight into gameplay
- not a role-neutral convenience action

It is a new lifecycle entry with replay-specific context.

## Replay Starts From Completed Context

### Meaning

Replay only makes sense after a remote match has already ended normally and the user is in a post-match context.

This usually means:
- end-game UI
- completed match result context
- replay request affordance

### Important rule

The replay request belongs to the **completed old match context**, but the replay itself belongs to a **new match record**.

This distinction matters a lot.

### Common mistake

Treating replay as:
- the same match ID continuing
- the same lifecycle continuing
- a rematch flag on the already completed match that skips new-match lifecycle reasoning

That is usually wrong.

## Replay Creation

### Meaning

Replay creation is the moment a completed match context causes a new remote match to be created.

### What replay creation should mean

A correct replay creation flow should:
- create a new authoritative remote match
- preserve replay-specific linkage to the old match if the implementation does so
- place the new replay match into the first actionable replay challenge state
- cause the correct outgoing/incoming replay UI for the two players

### Important rule

Replay creation is not the replay match being “ready to play immediately.”

It is the creation event that starts the new replay lifecycle.

## Replay Re-Enters the Challenge Phase

Once created, replay usually re-enters the same early challenge phase as a first-time remote match.

That means replay may still need:
- outgoing/incoming presentation
- sent vs pending asymmetry
- accept/decline behavior
- cancel behavior
- expiry handling
- ready transition
- lobby entry later

### Key rule

Do not skip challenge-phase reasoning just because the players already know each other and just completed a match.

Replay still usually follows:
- creation
- pending/sent asymmetry
- acceptance or refusal
- ready
- lobby
- gameplay

## Outgoing vs Incoming Replay Presentation

Replay usually preserves the same broad role asymmetry as ordinary remote challenges.

Typical pattern:
- replay requester sees an outgoing replay request
- the other player sees an incoming replay request

This often maps like:
- requester sees **sent**
- recipient sees **pending**

### Key rule

Replay is not automatically symmetric just because it originates from a shared end-game context.

The new replay match usually still has:
- an initiating side
- a receiving side
- outgoing vs incoming presentation

## Replay Roles

A replay match still needs challenger/receiver role interpretation.

Questions that matter:
- who becomes challenger in the new replay match?
- who becomes receiver?
- does replay preserve original challenger/receiver assignment?
- or does the replay requester become the new challenger?

The implementation’s chosen rule should be followed consistently.

### Important rule

Do not assume replay roles are irrelevant.

Even if both players just completed the previous match together, the new replay match still needs a correct role model for:
- UI mapping
- allowed actions
- authoritative field ownership
- lobby readiness fields
- gameplay interpretation

## Replay Accept Rules

Replay accept behavior should usually follow the same broad rule as ordinary challenge accept behavior.

That means:
- the incoming replay recipient usually decides whether to accept
- the outgoing replay requester usually does not “accept” their own replay request
- once accepted, the replay match advances out of the waiting challenge phase

### Typical next result

Typical replay progression after acceptance:
- replay challenge state advances to `ready`

### Common mistake

Treating replay request as already mutually agreed and therefore skipping accept logic entirely.

That is only valid if the implementation explicitly does that, and most remote lifecycle systems do not.

## Replay Decline Rules

Replay decline usually mirrors ordinary decline logic:
- recipient declines incoming replay request
- requester experiences the consequence of that decline
- the replay request should no longer remain actionable for either side

### Important rule

Decline ownership and decline presentation remain different things.

The replay recipient owns the decline action.  
The replay requester experiences the outcome.

### Common bug pattern

- recipient declines replay
- recipient UI resolves correctly
- requester’s outgoing replay card/overlay remains stale

That is usually wrong unless there is an explicit temporary presentation rule.

## Replay Cancel Rules

Replay cancel usually mirrors ordinary outgoing cancel logic in the early replay phase.

That means:
- replay requester may cancel an outgoing replay request before it progresses
- recipient should then stop seeing the replay as actionable
- requester should stop seeing it as still pending/sent

### Important rule

Replay cancel should be treated as a lifecycle outcome for the **new replay match**, not as a mutation of the old completed match.

## Replay Ready Stage

Once replay is accepted, it typically enters the same broad **ready** stage as a first-time remote match.

That means:
- replay is no longer just a request waiting for response
- replay is not yet gameplay
- replay is now eligible to proceed into the match-start flow

### Important rule

Replay ready is still only ready.

It is not:
- replay gameplay
- replay lobby by default
- proof that countdown/start already happened

## Replay Lobby Entry

After replay reaches ready, it should follow the same broad ready → lobby rule as ordinary remote flow.

That means:
- replay lobby entry should be authoritatively confirmed
- a local replay UI action is not enough by itself
- replay should not skip directly into gameplay unless the implementation explicitly says so

### Key rule

Replay lobby is still a real start-flow stage.

Do not collapse:
- replay ready
- replay lobby
- replay gameplay

into one blurry transition.

## Replay Lobby Sub-Phases

Once a replay match is in lobby, it usually follows the same kind of pre-game sub-phase model as first-time matches:
- joined or entered
- lobby view entered
- connecting
- readiness confirmation
- countdown
- gameplay authorization

### Important rule

Replay does not stop being a normal remote match just because it originated from a replay button.

Once the new replay match exists, its start-flow should still be reasoned about through authoritative remote lifecycle progression.

## Replay → Gameplay Rule

Replay gameplay should only begin after the replay match is authoritatively `in_progress`.

That means:
- replay countdown is not gameplay
- replay readiness is not gameplay
- replay lobby is not gameplay
- a replay overlay or end-game continuation UI should not push gameplay simply because replay “looks close enough”

### Common mistake

Treating replay as a UX convenience flow that can skip lifecycle gates because it came from a completed match.

That usually creates bugs.

## Replay Overlay / Replay UI State

Replay often has more UI around it than a normal first-time challenge, especially when it starts from end-game context.

Examples may include:
- replay overlay
- replay card state inside end-game UI
- replay-specific ownership flags
- replay-specific visibility logic

### Important rule

Replay UI state is not the same thing as replay lifecycle state.

Always separate:
- authoritative replay match state
- replay card/overlay presentation
- navigation or dismissal behavior around replay UI

A replay overlay being visible does not prove the replay lifecycle is in any specific stage.  
It only proves the UI is currently presenting that replay context.

## Replay Visibility vs Replay Truth

A common replay bug pattern is confusing:
- “the replay UI is still there”
with
- “the replay is still authoritatively active and actionable”

These are not the same thing.

Correct replay reasoning must distinguish:
- replay still exists authoritatively
- replay is still actionable
- replay UI still chooses to show it
- replay overlay has or has not dismissed yet

Those layers should not be collapsed together.

## Replay and Terminal Outcomes

Replay, as a new match, can also terminate without ever reaching gameplay.

Examples include:
- replay declined
- replay cancelled
- replay expired

These should be understood as terminal outcomes of the **new replay match**, not as changes to the old completed match.

### Key rule

Keep the two matches mentally separate:
- old completed match
- new replay match

The old match stays completed.  
The new replay match progresses or terminates on its own lifecycle.

## Replay and Expiry

Replay requests may also expire before being accepted or before starting successfully.

When that happens:
- the replay requester should no longer see an actionable outgoing replay
- the replay recipient should no longer see an actionable incoming replay
- replay UI should stop behaving as if the replay is still live

### Important rule

Replay expiry is still a lifecycle outcome of the new replay match, not a mutation of the old completed match.

## Replay and Role Asymmetry

Replay is especially vulnerable to accidental symmetry bugs because it starts from a shared completed experience.

But replay is still usually role-sensitive in all the familiar places:
- outgoing vs incoming request
- accept/decline ownership
- cancel ownership
- challenger/receiver field mapping
- readiness field ownership
- gameplay field interpretation

### Key rule

Do not let the shared emotional context of “we both just finished a match” erase the technical role model of the new replay match.

## Replay vs First-Time Remote Matches

### What is the same

Replay usually shares the same broad lifecycle family:
- pending/sent asymmetry
- accept/decline/cancel logic
- ready
- lobby
- in_progress
- terminal handling

### What is different

Replay differs because it begins from:
- completed match context
- replay-specific UI surfaces
- replay-specific linkage to an old match
- replay-specific ownership and visibility issues

### Best mental model

Replay is:
- **same lifecycle family**
- **special entry context**

That is the safest way to think about it.

## Good Patterns

### Good: replay creates a new match

- old match is completed
- replay is requested
- a new replay match is created
- new replay match enters challenge-phase behavior
- lifecycle reasoning continues from there

### Good: replay preserves outgoing/incoming asymmetry

- requester sees outgoing replay request
- recipient sees incoming replay request
- actions differ by role
- same new match, different correct UI by role

### Good: replay still respects ready/lobby/gameplay gates

- replay accepted
- replay becomes ready
- replay enters lobby
- replay start-flow gates pass
- replay becomes in_progress
- gameplay UI starts only then

### Good: replay terminal outcomes stay separate from the old match

- old match remains completed
- new replay match may be cancelled, declined, expired, or completed
- UI and history reasoning keep those two match identities distinct

## Bad Patterns

### Bad: replay treated as continuation of the old match

- same mental model
- same lifecycle
- no new-match reasoning

### Bad: replay skips challenge-phase asymmetry

- requester and recipient shown the same request UI
- accept/decline ownership flattened away

### Bad: replay ready treated as replay gameplay

- replay accepted
- UI races straight to gameplay without correct start-flow lifecycle steps

### Bad: replay overlay treated as authoritative truth

- overlay still visible
- code assumes replay is still actionable
- authoritative replay state not checked

### Bad: replay terminal outcome mutates the meaning of the old completed match

- replay fails
- app behaves as if the previous completed match changed meaning

## Replay Checklist

Before changing replay lifecycle behavior, ask:

1. am I reasoning about the old completed match or the new replay match?
2. has a new authoritative replay match actually been created?
3. who is challenger and who is receiver in the new replay match?
4. is the replay still in challenge phase, ready, lobby, or in_progress?
5. am I accidentally skipping outgoing/incoming asymmetry?
6. am I confusing replay UI visibility with authoritative replay lifecycle truth?
7. am I treating replay like a shortcut instead of a new lifecycle entry?

If those answers are unclear, the replay lifecycle change is probably unsafe.

## Relationship to Other Docs

Use this doc for replay-specific lifecycle behavior.

Use it with:
- `lifecycle-stages.md` for the canonical stage model
- `challenger-vs-receiver-rules.md` for role asymmetry
- `create-accept-decline-cancel.md` for the early challenge-action phase that replay often re-enters
- `ready-lobby-gameplay-flow.md` for the replay match start flow once it reaches ready
- `authoritative-state-and-ui-mapping.md` for exact state-to-UI interpretation
- `expiry-and-terminal-states.md` for how replay can terminate before or after starting

This doc answers:

**how does replay fit into the remote lifecycle, and how is it different from a first-time remote match?**

## Bottom Line

Replay in Dart Freak is not the old match continuing.

It is a new remote match, created from a completed match context, that usually re-enters the same lifecycle family with replay-specific UI and ownership rules layered on top.