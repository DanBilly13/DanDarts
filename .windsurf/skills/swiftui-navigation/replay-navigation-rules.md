> Supporting reference for: swiftui-navigation  
> Apply when: working on replay lobby entry, replay overlay dismissal, replay end-game transitions, replay route ownership, or any navigation bug where replay flow moves too early, too late, twice, or from the wrong layer  
> Do not apply to: ordinary local game navigation, generic router structure, or non-navigation replay state handling

# Replay Navigation Rules

## Purpose

This document defines how replay navigation should behave in Dart Freak.

Replay navigation is more fragile than normal navigation because it often sits at the intersection of:
- end-game UI
- overlay state
- remote flow state
- authoritative replay state
- router pushes
- dismissal logic
- voice session reuse / rebinding

Because of that, replay navigation bugs are often caused by the wrong layer owning the transition.

This document exists to prevent:
- replay lobby push happening too early
- replay overlay dismissal racing with replay push
- stale replay overlays still navigating
- payload-driven replay routing
- replay flow being treated like simple local navigation

---

## Core Rule

Replay navigation must have one clear owner, and it must follow authoritative replay state.

That means:
- one layer decides when replay navigation should happen
- router performs the actual push/pop
- overlay state does not become a second navigation owner
- realtime does not directly own replay routing
- replay pushes and dismissals happen only after authoritative confirmation

In short:

**replay navigation = one owner + authoritative replay truth + router execution**

---

## Why Replay Navigation Is Special

Replay is special because the user is often not starting from a clean root screen.

Replay may begin while the app is still dealing with:
- remote end game state
- active remote flow cleanup
- replay card updates
- replay overlay visibility
- replay status changes via realtime
- voice session rebinding to a new replay match

That means replay navigation must coordinate:
- route ownership
- overlay ownership
- authoritative remote truth
- stale-instance protection

A replay bug is often not “navigation is broken.”
It is “the wrong layer thought it owned the replay transition.”

---

## Core Ownership Rule

For any replay transition, explicitly answer:

- who owns replay lobby push?
- who owns replay overlay dismissal?
- who is only observing replay status?
- what authoritative source must confirm the transition?

Do not allow replay ownership to be vague.

Replay is exactly where vague ownership becomes duplicate navigation.

---

## Common Replay Transitions

Replay navigation usually involves these transitions:

- replay challenge created → replay overlay shown
- replay becomes ready → replay lobby becomes enterable
- replay lobby entered
- replay cancelled/removed → overlay dismissed
- replay lobby → replay gameplay
- replay gameplay → replay end game

This document focuses on the replay-specific parts:
- overlay → replay lobby
- replay cancellation/removal dismissal
- replay-specific route ownership while another remote flow is still unwinding

---

## Replay Lobby Entry Rule

Replay lobby should only be pushed after authoritative replay state confirms that replay is truly navigable.

That means:
- replay is in the correct authoritative state
- the current replay UI still belongs to the same replay match
- the current screen/overlay is still the correct owner
- no other navigation owner already took over
- stale overlay or stale instance cannot still request the push

Do not push replay lobby because:
- a payload suggested ready
- a local overlay object looks joinable
- a stale replay card still exists
- voice rebind succeeded

Voice/session readiness is not replay navigation authority.

---

## Replay Overlay Dismissal Rule

Replay overlay dismissal is navigation too.

It must have one clear owner and must follow authoritative replay truth.

Valid authoritative dismissal reasons include:
- replay was removed from authoritative arrays
- replay was authoritatively cancelled
- replay transitioned to a state where this overlay no longer belongs
- a new replay route took ownership and the old overlay should stand down

Do not dismiss replay overlay because:
- a payload alone suggested cancelled
- a timer finished
- the overlay “probably should go away now”
- a stale callback fired after ownership changed

Overlay dismissal should be as deliberate as replay push.

---

## Overlay vs Route Ownership

Replay flows often confuse these two:

- **overlay ownership**
- **route ownership**

They are related, but not identical.

Examples:
- an overlay may own whether replay status is still visible
- a replay flow owner may own whether replay lobby should be pushed
- once replay lobby is entered, the overlay should usually stop behaving like a navigation owner

Bad pattern:
- overlay decides to dismiss
- overlay also decides to push replay lobby
- end-game screen also decides to push replay lobby
- realtime also influences both

Good pattern:
- one owner decides replay route transition
- one owner decides overlay dismissal
- those decisions are coordinated, not duplicated

In many cases, the same feature may own both.  
But that ownership should still be explicit.

---

## Replay Is Not Just Another Card Tap

A replay entry route may begin from a card or overlay interaction, but it is not just a normal button navigation.

Replay entry must account for:
- authoritative replay state
- current end-game/replay context
- whether this replay still exists
- whether this view instance is still active
- whether remote flow ownership has changed
- whether lobby entry async work still belongs to this request

Just because the user tapped a replay card does **not** mean replay lobby should be pushed immediately.

Replay entry still needs the same kind of guarded async thinking as normal remote lobby entry.

That means preserving checks like:
- request still valid
- replay match identity still matches
- current owner is still active
- authoritative state still supports entry
- no newer transition has taken over

Treat replay entry as guarded remote navigation, not as simple UI navigation.

The “card tap” is only the start of the flow.  
It is not proof that the route change is already valid.

---

## Realtime Is Not a Replay Navigation Owner

Realtime may:
- trigger authoritative replay reload
- wake replay UI up
- cause the replay owner to re-evaluate whether navigation or dismissal is allowed

Realtime must not:
- directly push replay lobby
- directly dismiss replay overlay
- directly decide replay gameplay route changes

This is especially important because replay state often changes through realtime before the UI has authoritatively refreshed.

---

## Replay and Voice Reuse Rule

Replay may reuse or rebind voice session state.

That does **not** give permission to navigate.

Keep these separate:

### Voice/session layer
- connection reuse
- rebind
- replay-ready signalling
- local readiness

### Navigation layer
- replay overlay dismissal
- replay lobby push
- replay gameplay push
- replay route ownership

Good:
- voice/session layer completes
- authoritative replay state still gets checked
- replay navigation owner decides whether route change is valid

Bad:
- voice reuse succeeded
- replay lobby pushed immediately from that fact alone

Voice reuse is not navigation authority.

---

## Replay End-Game Context Rule

Replay often starts from end-game context.

That means replay navigation must also consider:
- whether the old remote flow is still unwinding
- whether the current end-game view is still the owner
- whether a new replay route is replacing old route context
- whether old end-game or overlay callbacks are still alive

Replay navigation is especially vulnerable to stale-instance problems here.

So before replay push or dismissal:
- validate active instance
- validate replay match identity
- validate ownership
- validate authoritative state

Do not assume end-game context is stable just because it is visible.

---

## Good Replay Navigation Patterns

### Good: replay becomes ready, owner pushes lobby
- replay update arrives
- authoritative replay source confirms ready/joinable state
- current replay owner is still active
- replay match identity still matches
- router pushes replay lobby once

### Good: replay cancelled, overlay dismisses
- authoritative replay reload shows cancelled or missing replay
- overlay is still active
- designated replay dismissal owner acts
- overlay dismisses once

### Good: replay lobby replaces overlay ownership
- replay lobby route is entered
- old overlay stands down
- stale callbacks from old overlay can no longer navigate

---

## Bad Replay Navigation Patterns

### Bad: payload-driven replay push
- realtime suggests replay ready
- replay lobby pushed immediately

### Bad: voice-driven replay push
- voice rebind succeeds
- replay route changes before authoritative replay state confirms navigation

### Bad: overlay and parent both own replay push
- overlay decides to push replay lobby
- end-game screen also decides to push replay lobby
- duplicate/racing transition occurs

### Bad: stale replay overlay dismisses late
- overlay schedules delayed dismiss
- replay already moved to a new context
- stale callback still dismisses or interferes with current flow

### Bad: replay navigation treated like local flow
- no authoritative re-check
- no replay-specific identity/ownership checks
- simple button semantics used for guarded remote replay entry

---

## Replay Transition Checklist

Before changing replay navigation code, answer these questions:

1. what exact replay transition is this?
2. who owns that transition?
3. what authoritative replay state must be true first?
4. is the current replay UI overlay-backed, route-backed, or both?
5. is this instance still active?
6. does this request still belong to the same replay match?
7. could another owner also trigger this transition?
8. does voice/session logic incorrectly influence navigation authority here?

If any of those are unclear, the replay navigation design is probably unsafe.

---

## Relationship to Other Docs

This doc is replay-specific.

Use it with:
- `one-navigation-owner.md` for ownership model
- `remote-navigation-guards.md` for remote guard stack
- `authoritative-navigation-checks.md` for replay truth requirements
- `lifecycle-and-instance-guards.md` for stale overlay/view safety
- `router-architecture.md` for execution model
- `navigation-debug-order.md` for diagnosis sequence

This doc answers:

**how replay navigation differs from ordinary remote navigation**

The others explain the general framework around it.

---

## Bottom Line

Replay navigation is fragile because overlays, remote truth, and route transitions all meet in the same place.

Make ownership explicit.  
Wait for authoritative replay truth.  
Let router execute exactly once.