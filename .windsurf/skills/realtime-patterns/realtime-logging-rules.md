> Supporting reference for: realtime-patterns  
> Apply when: adding, changing, or reviewing logs around realtime subscriptions, refetch decisions, replay updates, stale UI bugs, or navigation triggered after remote events  
> Do not apply to: local matches or logging unrelated to remote realtime decision chains

# Realtime Logging Rules

## Purpose

This document defines how to log remote realtime behavior in a way that helps debugging without creating noise.

The goal is:
- log decisions, not just events
- make stale UI bugs traceable
- make replay bugs diagnosable
- show why a reload ran, skipped, or was forced
- keep logs useful under pressure

Bad realtime logging creates noise.  
Good realtime logging explains the decision chain.

---

## Core Rule

For realtime, the most important thing to log is not:

- that an event arrived

The most important thing to log is:

- what the client decided to do because it arrived

That means the key logs are:
- relevance
- chosen reload path
- skip/throttle/force reason
- authoritative result
- model update result
- navigation/dismissal decision

---

## Naming Consistency Rule

Use stable prefixes and terms.

Examples:
- `[Realtime]`
- `[Replay]`
- `[Lobby]`
- `[FlowDebug]`

And keep important fields consistent:
- `match=`
- `action=`
- `reason=`
- `status=`
- `relevant=`
- `reload=`
- `decision=`

Consistency matters because debugging often means scanning and grep-ing logs quickly.

If Windsurf is generating new log statements, it should follow this naming pattern by default.

---

## What Good Realtime Logs Should Answer

From logs alone, you should be able to answer:

1. did the realtime event arrive
2. was it relevant
3. what reload path was chosen
4. was that path skipped, throttled, or forced
5. what authoritative state came back
6. did arrays or flowMatch update
7. did navigation or dismissal happen
8. if not, what blocked it

If the logs cannot answer those questions, they are incomplete.

---

## Log the Decision Chain

Realtime logs should follow the same pipeline as realtime behavior.

### 1. Event received
Log:
- event type
- match id or row id
- replay vs non-replay when relevant

Example:
- `RT UPDATE match=ABC123 remoteStatus=lobby replay=false`

---

### 2. Relevance decision
Log:
- relevant or ignored
- why
- user/match/screen context if that explains the decision

Example:
- `Realtime relevant=true reason=current_active_match`
- `Realtime relevant=false reason=wrong_user`

---

### 3. Reload path choice
Log:
- `fetchMatch`
- `loadMatches`
- forced `loadMatches`
- no reload

Example:
- `Realtime action=fetchMatch reason=active_match_screen`
- `Realtime action=forceLoadMatches reason=replay_overlay_array_backed`

---

### 4. Reload execution result
Log:
- ran
- skipped
- throttled
- already in progress
- cancelled
- joined existing in-flight request

Example:
- `Realtime reload=skipped reason=inRemoteFlow`
- `Realtime reload=forced override=inRemoteFlow`
- `Realtime reload=joined existing_fetch=true`

---

### 5. Authoritative result
Log:
- fetched status
- current player id if relevant
- countdown started if relevant
- whether replay/card still exists in arrays if relevant

Example:
- `Realtime authoritative status=in_progress cp=USER123`
- `Realtime authoritative replayFound=false`

---

### 6. Model update
Log:
- flowMatch updated or unchanged
- arrays updated or unchanged
- bucket movement when useful

Example:
- `FLOW_MATCH update old=lobby new=in_progress`
- `LOAD publish pending=[] ready=[ABC123] sent=[]`

---

### 7. UI decision
Log:
- dismiss
- navigate
- no-op
- blocked by guard

Example:
- `Lobby navigation allowed destination=remoteGameplay`
- `Replay overlay dismiss blocked reason=overlay_not_visible`

---

## Log Levels by Usefulness

Think of realtime logs in three levels.

### Level 1 — Always valuable
These should stay in normal debugging:
- event type
- relevance
- chosen action
- skip/force reason
- authoritative result
- navigation/dismissal decision

### Level 2 — Useful for focused bugs
Enable when chasing a specific issue:
- array membership before/after
- exact guard results
- replay-specific context
- stale cache / overlay source details

### Level 3 — Temporary deep debug
Use only while actively diagnosing:
- raw payload dumps
- large object dumps
- repeated polling details every cycle
- verbose array contents every update

Level 3 logs should usually be removed or gated.

---

## What to Log for Replay

Replay bugs are subtle, so replay logs must answer a few extra questions:

- was this event replay-related
- was replay UI active
- was the replay UI array-backed or active-match-driven
- was forced reload chosen
- did replay remain in arrays or disappear
- did overlay dismiss or stay visible

Useful examples:
- `Replay realtime relevant=true status=cancelled`
- `Replay action=forceLoadMatches reason=overlay_depends_on_arrays`
- `Replay authoritative replayFound=false`
- `Replay dismiss decision=run reason=missing_from_arrays`

---

## What to Log for In-Remote-Flow Cases

When `isInRemoteFlow` affects behavior, always log the effect.

Do not just log that the app is in remote flow.

Log:
- whether it caused a skip
- whether it was overridden
- why that was correct

Good:
- `Realtime loadMatches skipped reason=inRemoteFlow active_match_only`
- `Realtime forceLoadMatches override=inRemoteFlow reason=replay_overlay_array_backed`

Bad:
- `inRemoteFlow=true`

That alone is not useful.

---

## What to Log for Navigation

If realtime eventually leads to navigation or dismissal, log:

- current authoritative status
- current screen instance / match identity if helpful
- whether the correct owner handled navigation
- which guard passed or blocked

Good:
- `Lobby nav check status=in_progress match=ABC123 owner=current_view guard=passed`
- `Replay dismiss blocked reason=stale_instance`

Bad:
- `navigating now`
- `dismissing overlay`

That tells you nothing about why.

---

## Prefer Compact Structured Logs

Good realtime logs are compact and consistent.

Prefer patterns like:
- prefix
- match id
- decision
- reason
- result

Examples:
- `[Realtime] relevant=true match=ABC123 reason=current_match`
- `[Realtime] action=fetchMatch match=ABC123 reason=active_lobby`
- `[Realtime] reload=skipped match=ABC123 reason=throttled`
- `[Realtime] authoritative match=ABC123 status=lobby cp=nil`
- `[Replay] action=forceLoadMatches match=ABC123 reason=overlay_array_backed`

This is much more useful than long prose logs.

---

## Log Reasons, Not Just Outcomes

A log that says what happened but not why is weak.

Bad:
- `loadMatches skipped`

Good:
- `loadMatches skipped reason=inRemoteFlow_no_forceReload`

Bad:
- `overlay dismissed`

Good:
- `overlay dismissed reason=authoritative_replay_missing_from_arrays`

The reason is what makes the log actionable.

---

## Avoid Logging Only Raw Payloads

Raw payload logs can help temporarily, but they are not enough.

Why:
- they do not show the client decision
- they do not show reload path
- they do not show whether authoritative state changed
- they do not show whether navigation guards passed

Payload dumps are supporting evidence, not the main log strategy.

---

## Avoid Noisy Repeated Logs

Do not spam logs on every timer tick or polling cycle unless actively debugging a very specific issue.

Be careful with:
- voice-window poll loops
- repeated overlay polling
- repeated render cycles
- repeated “unchanged” logs with no new decision value

If a repeated log is necessary, gate it or make it concise.

Bad:
- dumping the same array contents every 500ms

Good:
- logging only on state transition, decision change, or first/last poll condition

---

## What Good Looks Like

A good realtime bug log sequence looks like this:

1. event arrived
2. relevant=true
3. action=forceLoadMatches
4. reload ran
5. authoritative replayFound=false
6. overlay dismiss decision=run
7. dismiss complete

That tells the whole story.

A good active match sequence looks like this:

1. event arrived
2. relevant=true
3. action=fetchMatch
4. fetch ran
5. authoritative status=in_progress
6. flowMatch updated
7. navigation allowed

Again, the whole story is visible.

---

## Bad Logging Patterns

### Bad: payload-only logging
- raw event dumps
- no relevance decision
- no reload decision
- no authoritative result

### Bad: outcome-only logging
- “updated”
- “skipped”
- “dismissed”
- no reason

### Bad: UI-only logging
- “card disappeared”
- “overlay stayed open”
- no record of reload path or authoritative state

### Bad: constant spam
- every poll tick
- every render
- unchanged state dumps every time
- huge arrays printed repeatedly

### Bad: mixed naming
- different prefixes for the same decision type
- inconsistent match id formatting
- vague labels that make grep hard

---

## Logging for the Debug Order

Good realtime logs should support the standard debug order directly:

1. event arrived
2. relevance decision
3. path chosen
4. execution result
5. authoritative result
6. model update
7. UI/navigation decision

If your logs map cleanly to that order, the system is observable.

If they do not, debugging will be slow and expensive.

---

## Client May / Must Not

### Client may
- log compact structured decisions
- add temporary deep debug logs when chasing a specific bug
- gate noisy logs behind debug flags
- log skip/force reasons explicitly

### Client must not
- rely only on payload dumps
- log only final UI symptoms
- flood logs with unchanged polling output
- omit the reason behind reload/navigation decisions

---

## Bottom Line

For realtime, the valuable log is not “an event happened.”

The valuable log is:  
**“an event happened, here is what we decided, here is why, and here is what authoritative state said next.”**