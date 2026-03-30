# Fix X01 Filtering to Include Remote Games

**Update filtering logic so "301" filter includes both "301" and "Remote 301" games, and "501" filter includes both "501" and "Remote 501" games.**

## Current Issue

**Line 67 in MatchHistoryView.swift:**
```swift
filtered = filtered.filter { $0.gameName == selectedFilter.rawValue }
```

**Problem**: Exact match filtering excludes remote games:
- "301" filter only matches `gameName == "301"`
- "501" filter only matches `gameName == "501"`
- Remote games have `gameName == "Remote 301"` and `gameName == "Remote 501"`

## Solution Strategy

**Update filtering logic to use `contains()` instead of exact match for X01 games:**

### Option 1: Simple Contains (Recommended)
```swift
if !isSearchPresented && selectedFilter != .all {
    if selectedFilter == .threeOhOne {
        filtered = filtered.filter { $0.gameName.contains("301") }
    } else if selectedFilter == .fiveOhOne {
        filtered = filtered.filter { $0.gameName.contains("501") }
    } else {
        filtered = filtered.filter { $0.gameName == selectedFilter.rawValue }
    }
}
```

### Option 2: Helper Method
```swift
private func matchesFilter(_ summary: MatchSummary, filter: GameFilter) -> Bool {
    switch filter {
    case .threeOhOne:
        return summary.gameName.contains("301")
    case .fiveOhOne:
        return summary.gameName.contains("501")
    default:
        return summary.gameName == filter.rawValue
    }
}
```

## Implementation Plan

**Update `updateFilteredMatches()` method** (lines 65-68):

1. Replace exact match logic with conditional logic
2. Handle X01 filters with `contains()` 
3. Keep exact match for other game types
4. Maintain existing search and local match filtering

## Expected Outcome

- **"301" filter**: Shows both "301" and "Remote 301" games
- **"501" filter**: Shows both "501" and "Remote 501" games  
- **Other filters**: Unchanged (exact match still works)
- **Search**: Unchanged (already uses `contains()`)

## Files to Modify

**MatchHistoryView.swift** - Update `updateFilteredMatches()` method

## Benefits

- **Complete grouping**: All X01 variants grouped together
- **User-friendly**: Users don't need to know about "Remote" prefix
- **Minimal change**: Only affects X01 filtering logic
- **Future-proof**: Will handle other X01 variants (701, 901)
