# Search Performance Debugging Guide

## Debug Logs Added

We've added comprehensive timing and state tracking to identify the hang issue:

### 1. **Button Tap Tracking**
```
🔍 [SEARCH] Button tapped at [timestamp]
🔍 [SEARCH] Current matches count: 107
🔍 [SEARCH] isSearching set to true at 0.001s
🔍 [SEARCH] Attempting focus at 0.5s
```

### 2. **View Body Re-evaluation**
```
🔍 [BODY] View body re-evaluated. isSearching: true, searchText: ''
```
- Shows every time SwiftUI rebuilds the view
- If this appears many times rapidly, we have a state thrashing issue

### 3. **Filter Computation Timing**
```
🔍 [FILTER] Starting filteredMatches computation
🔍 [FILTER] Early return - search active but empty (0.0001s)
🔍 [FILTER] Starting with 107 matches
🔍 [FILTER] After search filter: 5 matches
🔍 [FILTER] Completed in 0.023s, returning 5 matches
```
- Tracks how long filtering takes
- Shows if DateFormatter optimization is working

### 4. **Overlay Lifecycle**
```
🔍 [OVERLAY] Search overlay appeared at [timestamp]
🔍 [OVERLAY] Current isSearchFieldFocused: false
```

### 5. **Focus State Changes**
```
🔍 [FOCUS] Changed: false -> true at [timestamp]
🔍 [FOCUS] ✅ Keyboard should appear now
```
- Shows when focus changes
- Helps identify if keyboard request is being made

## What to Look For

### **Scenario 1: Too Many Body Re-evaluations**
If you see many `[BODY]` logs in quick succession:
- SwiftUI is rebuilding the view repeatedly
- Likely cause: State changes triggering cascading updates
- Solution: Optimize state management

### **Scenario 2: Slow Filter Computation**
If `[FILTER] Completed in X.XXs` shows > 0.1s:
- Filtering is taking too long
- Check if early return is working
- Verify DateFormatter is cached

### **Scenario 3: Focus Not Changing**
If you don't see `[FOCUS] Changed: false -> true`:
- Focus request isn't reaching the TextField
- View hierarchy might not be ready
- Solution: Increase delay or change approach

### **Scenario 4: Focus Changes But No Keyboard**
If you see `[FOCUS] ✅ Keyboard should appear` but no keyboard:
- iOS keyboard session issue (RTIInputSystemClient error)
- View hierarchy not stable enough
- Solution: Increase delay or use different focus mechanism

## Current Configuration

- **Animation Duration**: 0.25s
- **Focus Delay**: 0.5s (after button tap)
- **Early Return**: Active when search is empty
- **DateFormatter**: Cached (created once)

## Next Steps Based on Logs

1. **If hang is before overlay appears**: Issue is in view rendering
2. **If hang is after overlay but before focus**: Issue is in animation/layout
3. **If focus changes but no keyboard**: iOS keyboard session timing issue
4. **If many body re-evaluations**: State thrashing problem

Run the app, tap search, and share the console output to identify the exact bottleneck!
