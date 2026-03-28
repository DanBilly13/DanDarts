---
name: debugging-guide
description: compact debugging workflow for Dart Freak. Use when a bug’s real failure layer is unclear, especially for remote matches, stale UI, wrong-player rendering, lifecycle confusion, delivery/realtime issues, replay bugs, or route symptoms that may not actually be navigation bugs. Do not use for pure styling, copy edits, or obvious one-line fixes.
---

# Debugging Guide

Use this skill when the task is not just “change code,” but:

**figure out what is actually broken first.**

## Use When
- the visible symptom may not be the real failure
- the broken layer is unclear
- the bug could involve truth, transition, mapping, delivery, navigation, stale actor, or terminal-state interpretation
- the issue is in remote matches, stale UI, replay, role-based rendering, or lifecycle behavior

## Do Not Use When
- the task is purely visual/styling
- the task is copy-only
- the broken line is already obvious
- the user is asking for straightforward implementation, not diagnosis

## Core Rule
Do not propose a fix until the broken layer is identified.

**Diagnose first. Patch second.**

## Default Debug Order
Use this order unless a more specific support doc is clearly needed:

1. **Symptom**  
   What exactly is wrong?

2. **Authoritative truth**  
   What should actually be true right now?

3. **Owner / layer**  
   Which layer should own the correct behavior?

4. **Classification**  
   Is this mainly:
   - truth
   - transition
   - mapping
   - delivery
   - navigation
   - stale actor / stale request
   - terminal interpretation

5. **Evidence**  
   What logs, fields, state, or surface behavior prove it?

6. **Fix**  
   What is the smallest correct fix at that layer?

## App-Specific Rule for Dart Freak
In Dart Freak, debug in this priority order:

- authoritative truth
- lifecycle meaning
- role interpretation
- UI mapping
- delivery/update path
- navigation/overlay behavior
- animation/timing polish

Do not debug from the visible card backward.

## Required Output Format
When diagnosing a bug, answer in this structure:

1. exact symptom  
2. likely broken layer  
3. expected truth  
4. evidence needed or evidence found  
5. likely root cause  
6. minimal correct fix

Do not jump straight to:
- add a delay
- force reload
- hide the card
- push from here
- blame realtime
- blame navigation

## Use Supporting References Only When Needed
Pull a support doc only if the bug clearly matches that domain:

- `remote-debug-order.md` → remote-match lifecycle bugs
- `debug-order-overview.md` → general app-wide debugging
- `realtime-vs-truth.md` → “didn’t update” / stale UI bugs
- `navigation-vs-lifecycle.md` → route symptoms where the real cause is unclear
- `lifecycle-vs-mapping.md` → correct truth vs wrong UI interpretation
- `evidence-and-logging.md` → missing proof / unclear logs

## Bottom Line
A visible bug is not the same as the broken layer.

In Dart Freak, identify the broken layer first, then change code.