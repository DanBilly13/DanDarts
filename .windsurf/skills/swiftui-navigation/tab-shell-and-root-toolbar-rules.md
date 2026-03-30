> Supporting reference for: swiftui-navigation  
> Apply when: working on MainTabView, root toolbar behavior, root navigation titles, tab-specific toolbar actions, or any bug where root tab chrome behaves incorrectly when pushing deeper screens  
> Do not apply to: deep remote transition guards, replay route ownership, or generic view styling that does not affect root navigation shell behavior

# Tab Shell and Root Toolbar Rules

## Purpose

This document explains the navigation-shell responsibilities of `MainTabView`.

It exists to stop mistakes like:
- treating root toolbar behavior as if it belongs to child screens
- breaking the root title when pushing deeper routes
- putting tab-root actions in the wrong layer
- mixing root tab chrome with deep pushed-screen navigation
- making toolbar logic harder to reason about by scattering it across the app

This document is about the **tab shell layer** of navigation.

## Core Rule

`MainTabView` owns the root tab shell.

That means it owns:
- the root `NavigationStack`
- root tab title behavior
- root toolbar switching by selected tab
- root-only toolbar actions
- tab-shell state that affects root navigation chrome

In short:

**child screens own their screen content; `MainTabView` owns the root shell chrome**

## What the Tab Shell Is

The tab shell is the app layer that exists before you push deeper into a feature flow.

In Dart Freak, that means:
- the `TabView`
- the selected tab
- the shared root toolbar
- the root title
- root-level toolbar actions like search, invite, challenge, profile access
- the decision about when root chrome is visible versus hidden

This is different from:
- router execution
- feature-level push/pop decisions
- remote flow guard logic
- deep child-screen toolbar behavior

## MainTabView Is the Root Shell Owner

`MainTabView` is not just a container.

It is the owner of:
- tab selection
- root navigation title behavior
- tab-specific root toolbar content
- the distinction between root state and pushed state

This is important because it means child views should not try to recreate or compete with root tab-shell behavior.

## Root Title Rule

The root title belongs to the tab shell, not to child feature screens.

In the current structure:
- the title is derived from the selected tab
- title display is tied to root-level navigation state
- the title should only appear when the app is at the root of the stack

### Practical rule

If the app is showing root tab content, `MainTabView` owns the title.

If the app has pushed deeper into a route, the root title should stand down.

## `navigationPath.isEmpty` Rule

The root toolbar/title behavior should follow whether the app is still at the root of the stack.

That means:
- root title and root toolbar content are shown only when `navigationPath.isEmpty`
- once a deeper route is pushed, root chrome should stop behaving like the active screen chrome

This keeps a clean boundary between:
- root tab shell
- pushed feature screens

### Important rule

Do not let root toolbar/title logic ignore stack depth.

If the stack is not at root, the root shell should not pretend it still owns the visible screen.

## Selected Tab Drives Root Chrome

The selected tab determines:
- the root title
- the root toolbar actions
- the root toolbar configuration

This is the correct pattern because the tab shell is a selected-tab-driven UI layer.

Examples of tab-root behavior:
- Games tab shows profile access
- Friends tab shows invite and search
- Remote tab shows challenge
- History tab shows search

These are root-shell concerns, not deep feature-screen concerns.

## Root Toolbar Actions Rule

A toolbar action belongs in `MainTabView` when it is:

- a root-level action for a tab
- visible only at the root of that tab’s shell
- part of the root navigation chrome
- driving tab-root presentation state

Examples:
- root search button for a tab
- root invite button
- root challenge button
- profile button from the Games root

### Important rule

Do not move a root-shell toolbar action into a child view if the action belongs to the tab root experience.

## Tab-Specific Root State Rule

Some state belongs in `MainTabView` because it controls root toolbar behavior.

Examples:
- search presented state for a tab
- root-level invite/challenge presentation toggles
- tab-specific root toolbar UI flags

This is different from feature-internal screen state.

### Good pattern

Keep state in `MainTabView` when it exists to coordinate:
- selected tab
- root toolbar
- root-level presentation/action behavior

### Bad pattern

Push that state down into child screens when the real owner is still the tab shell.

## Child Screen Rule

Child screens should not fight the root shell.

That means child screens should not:
- try to own the root title
- assume root toolbar actions still apply while deep in a pushed flow
- recreate root-shell toolbar logic locally
- compete with `MainTabView` for root navigation chrome decisions

Child screens may own:
- their own screen content
- their own guarded route decisions
- local screen-specific toolbar behavior if appropriate

But they should not replace the root shell.

## Root Shell vs Deep Navigation Rule

Keep these two layers separate:

### Root shell layer
Owned by `MainTabView`
- selected tab
- root title
- root toolbar switching
- root-only toolbar actions
- root chrome visibility

### Deep navigation layer
Owned by feature views + router architecture
- route transition decisions
- feature pushes/pops
- remote guarded transitions
- replay route logic
- screen-specific content flows

### Important rule

Do not mix shell logic with deep route logic.

They are related, but they are not the same layer.

## Toolbar Switching Rule

At root level, toolbar content should switch by selected tab.

This is correct because each tab has a different root purpose.

### Good pattern
- one centralized toolbar builder
- tab-based switch
- root-only visibility guard

### Bad pattern
- multiple scattered toolbar definitions trying to act as root toolbar
- child screens duplicating root tab actions
- root toolbar rules hidden inside feature files

## Root Title Mapping Rule

A computed property like `rootNavTitle` is a valid tab-shell pattern.

Its job is simple:
- map selected tab to root title
- keep root title logic centralized
- avoid duplicating tab-root title text across features

### Important rule

This mapping belongs in the root shell because it is tab-root UI, not feature navigation logic.

## Search / Invite / Challenge Buttons Rule

Buttons like:
- search
- invite
- challenge
- profile access

belong in the root shell when they are intended as tab-root affordances.

That means:
- they appear at the root
- they disappear when pushing deeper
- they are driven by selected tab
- they trigger root-level presentation or routing state

### Important rule

These actions are part of the tab shell experience, not general-purpose toolbar actions for every screen in that feature.

## Common Mistakes

### Mistake: putting root title logic in child screens
Why it is wrong:
- the root title belongs to the tab shell
- child screens should not own root tab naming

### Mistake: leaving root toolbar visible while deep in the stack
Why it is wrong:
- it blurs root shell and pushed-screen ownership

### Mistake: pushing tab-root toolbar state down into feature views
Why it is wrong:
- the real owner is still `MainTabView`

### Mistake: using deep screen logic to control root shell chrome
Why it is wrong:
- deep route logic and tab shell logic are separate layers

### Mistake: duplicating root toolbar definitions
Why it is wrong:
- root shell should stay centralized and predictable

## Good Questions To Ask

Ask:
- is this a root tab-shell concern or a deep feature concern?
- should this toolbar action exist only at the root?
- is `MainTabView` the right owner of this chrome/state?
- should this disappear when `navigationPath` is no longer empty?
- does this behavior belong to the selected tab, or to a pushed screen?

These questions usually reveal the correct layer.

## Bad Questions To Ask

Avoid starting with:
- “can we just put this toolbar item in the child view?”
- “can this screen just set the root title itself?”
- “can we leave the root actions visible everywhere?”
- “can this feature own the tab toolbar state itself?”

Those shortcuts usually blur shell ownership.

## Decision Checklist

Before changing root toolbar or title behavior, ask:

1. is this root tab-shell behavior?
2. does it belong only when `navigationPath.isEmpty`?
3. is it selected-tab-driven?
4. should `MainTabView` own this state/action?
5. would moving it into a child screen blur root-shell ownership?

If those answers are unclear, the change is probably being made at the wrong layer.

## Relationship to Other Docs

Use this doc when the main question is:

**what does `MainTabView` own as the root tab shell, and what should not be pushed down into child screens?**

Use it with:
- `router-architecture.md` for root stack ownership and router execution model
- `one-navigation-owner.md` for route transition ownership
- `navigation-anti-patterns.md` for shortcuts that blur ownership
- `remote-navigation-guards.md` for deep remote transition safety

This doc answers:

**how root tab chrome and root toolbar behavior should be owned**

The other docs answer:
- how routes are executed
- who owns deep transitions
- how guarded remote navigation works

## Bottom Line

In Dart Freak, `MainTabView` is not just a wrapper around tabs.

It owns the root tab shell:
- root title
- root toolbar switching
- root-only toolbar actions
- root chrome visibility

Keep root shell logic in `MainTabView`.  
Keep deep route logic in the feature layers.