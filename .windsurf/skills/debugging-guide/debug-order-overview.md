> Supporting reference for: debugging-guide  
> Apply when: starting to debug any Dart Freak bug where the broken layer is not yet clear and you need a consistent app-wide diagnostic order before proposing a fix  
> Do not apply to: pure styling issues, copy edits, or simple one-line bugs where the failure layer is already obvious

# Debug Order Overview

## Purpose

This document defines the default debugging order for Dart Freak.

It exists because a lot of debugging goes wrong before the code is ever changed.

The usual failure pattern is:
- start from the visible symptom
- guess the cause
- patch the nearest piece of UI
- create a second bug
- only later realize the real broken layer was somewhere else

This document prevents that.

It gives a consistent order for debugging bugs across the app, especially when the failure could live in:
- authoritative truth
- lifecycle transition
- UI mapping
- delivery/update flow
- navigation
- stale instance or stale async request
- terminal-state interpretation

## Core Rule

Do not propose a fix until you can name the broken layer.

Always debug in this order:

1. define the exact symptom
2. define what should be true instead
3. identify the responsible layer
4. gather the evidence that proves whether that layer is correct or broken
5. only then propose the smallest correct fix

In short:

**identify the layer first, then change the code**

## The General Debug Ladder

Use this ladder for almost every app bug that is not purely visual:

### 1. Symptom
What exactly is wrong?

### 2. Expected truth
What should be true right now?

### 3. Broken layer hypothesis
Which layer is most likely responsible?

### 4. Evidence
What logs, fields, state, or UI behavior prove it?

### 5. Classification
Is this definitely the real layer, or only the nearest visible symptom?

### 6. Fix
What is the smallest fix that corrects the real broken layer?

Do not reorder this ladder.

## Step 1 — Define the Exact Symptom

Start by naming the symptom precisely.

Bad:
- “remote is broken”
- “navigation is weird”
- “the card is wrong”
- “replay is buggy”

Good:
- “receiver declined, but challenger still sees the outgoing challenge”
- “match is authoritatively ready, but UI still shows pending”
- “countdown appears, but gameplay starts before authoritative in_progress”
- “completed match disappears instead of moving to history”
- “push happened twice after the same lifecycle change”

The more exact the symptom, the easier it is to locate the layer.

## Step 2 — Define the Expected Truth

After naming the symptom, define what should be true instead.

Examples:
- the match should be in `ready`
- the current user should be treated as receiver
- this completed match should appear in history, not disappear
- the replay should be a new match, not old-match continuation
- the app should still be in lobby, not gameplay

This step is critical because debugging without an expected truth usually becomes guesswork.

## Step 3 — Identify the Responsible Layer

Before looking for a fix, decide which layer should actually own the correct behavior.

Common layers in Dart Freak include:

### Truth layer
The authoritative state itself.

### Transition layer
The movement from one valid state to the next.

### Mapping layer
How correct truth is turned into visible UI.

### Delivery layer
How updated truth reaches the current screen, card, list, or overlay.

### Navigation layer
How route changes or dismissals happen from already-known truth.

### Stale instance/request layer
How old views or old async work keep acting after ownership changed.

### Terminal interpretation layer
How ended/non-actionable states are classified and shown.

A good debugging pass identifies one of these explicitly.

## Step 4 — Gather Evidence

Once you have a likely layer, gather evidence before changing code.

Good evidence includes:
- authoritative status or fields
- role identity
- expected next transition
- current list placement
- action availability
- router logs
- realtime/update logs
- lifecycle logs
- terminal reason
- replay old-match vs new-match identity

Bad evidence includes:
- “it looked wrong”
- “the screen felt late”
- “I think realtime didn’t work”
- “it probably needs a delay”

Evidence should tell you whether the chosen layer is actually broken.

## Step 5 — Classify the Bug Correctly

This is the step where you stop confusing symptoms with causes.

Examples:

### Visible symptom
Wrong card shown

Possible real cause
- wrong lifecycle state
- wrong role interpretation
- wrong mapping
- stale delivery

### Visible symptom
Did not navigate

Possible real cause
- transition never completed
- authoritative truth never changed
- stale instance blocked navigation correctly
- routing is wrong

### Visible symptom
Card disappeared

Possible real cause
- completed
- cancelled
- expired
- decline-resolved
- moved to another surface
- bad mapping

This step matters because the same symptom can come from very different layers.

## Step 6 — Propose the Minimal Correct Fix

Only after the broken layer is identified should you propose a code change.

The best fix is usually:
- the smallest one
- at the correct layer
- preserving the rest of the architecture

Bad fixes are usually:
- delays
- force reloads everywhere
- hiding UI instead of fixing truth
- duplicating navigation ownership
- patching one side while the other side still stays stale
- changing UI copy to mask wrong logic

The goal is not “make the symptom go away.”  
The goal is “fix the layer that caused the symptom.”

## App-Wide Diagnostic Priority

In Dart Freak, this is usually the safest priority:

1. authoritative truth
2. lifecycle meaning
3. role interpretation
4. UI mapping
5. delivery/update path
6. navigation/overlay behavior
7. animation/timing polish

This priority prevents a lot of wasted work.

If you start at step 6 or 7 first, you often patch the wrong thing.

## Common Bug Classifications

These are the most common high-level bug classes in the app.

### Truth bug
The authoritative state is wrong or missing.

### Transition bug
The expected stage or state change never actually completed.

### Mapping bug
The authoritative truth is right, but the UI interpretation is wrong.

### Delivery bug
Truth changed correctly, but the current surface did not update.

### Navigation bug
The route push/pop/dismiss behavior is wrong after the lifecycle truth is already known.

### Stale actor bug
An old view or old async request is still acting after it should have stopped.

### Terminal reasoning bug
The match is no longer actionable, but the app is using the wrong reason or wrong outcome.

A strong diagnosis names one of these and explains why.

## What Not To Do

Avoid these debugging habits:

### Do not start with a fix
Do not begin with:
- “let’s add a delay”
- “let’s force reload”
- “let’s hide the card”
- “let’s push from here instead”

### Do not assume visible UI equals truth
The card, button, or overlay is not the source of truth.

### Do not assume navigation is the first problem
A route symptom often comes from lifecycle truth or stale-instance behavior.

### Do not assume realtime is broken just because UI is stale
The update may have arrived correctly, but mapping or refresh logic may be wrong.

### Do not flatten all terminal outcomes together
Completed, cancelled, expired, declined, and hidden are not interchangeable.

## Good Debug Questions

Ask questions like:
- what exactly is wrong?
- what should be true right now?
- which layer owns that truth or behavior?
- what evidence proves whether that layer is correct?
- is the visible symptom actually downstream of another broken layer?
- what is the smallest fix at the real layer?

These questions lead to useful debugging.

## Bad Debug Questions

Avoid starting with:
- “can we just hide it?”
- “should we add another callback?”
- “should we force a refresh every time?”
- “should we push from onAppear instead?”
- “can we treat this like cancelled?”
- “can we just make the UI match the screenshot?”

Those questions often bypass diagnosis.

## The Debugging Output Standard

A good debugging answer in Dart Freak should usually include:

1. the exact symptom
2. the likely broken layer
3. the evidence that supports that diagnosis
4. the expected truth/behavior
5. the minimal fix

That structure is much better than immediately producing code.

## Relationship to Other Docs

This is the general debug-order document.

Use it with:
- `remote-debug-order.md` for remote-specific diagnosis
- `lifecycle-vs-mapping.md` for truth-vs-UI interpretation bugs
- `realtime-vs-truth.md` for stale update bugs
- `navigation-vs-lifecycle.md` for route symptoms with unclear causes
- `evidence-and-logging.md` for what logs and proof to collect

This doc answers:

**what order should I debug in before deciding what to change?**

## Bottom Line

In Dart Freak, good debugging starts by identifying the broken layer, not by editing the nearest visible symptom.

Define the symptom.  
Define the expected truth.  
Identify the layer.  
Gather evidence.  
Then fix it.