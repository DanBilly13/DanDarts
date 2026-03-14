# Technical Documentation: Match Pipeline & Lifecycle

## Part 1: Post-Mortem (Remote Match Pipeline Failure)

In the end, it was not one bug. It was a pipeline problem with three separate failure points.

### Overview

Remote matches were intended to flow into the same history and statistics pipeline as local matches. This aligns with the project goal: completed remote matches should appear in history and utilise the existing match-detail pipeline. The feature was designed to treat remote play as a reuse or adaptation of existing local flows rather than a separate universe.

---

### Root Causes

#### 1. Data Ingestion Filtering

**Issue:** Some remote matches were being dropped before the Head-to-Head (H2H) component ever saw them.

- **Details:** Early in the process, the loader excluded remote matches due to strict validation assumptions.
- **Primary Culprits:** Initial duration validation issues and faulty timestamp/date parsing for remote rows.
- **Result:** The raw data existed, but the app silently rejected remote matches while building `MatchResults`.

#### 2. Category Fragmentation

**Issue:** Even after successful loading, remote matches were not being grouped with local 301 matches.

- **Details:** The application treated `"301"` and `"Remote 301"` as distinct game buckets.
- **Result:** H2H rendered two separate categories instead of one combined 301 row. This explains why the debug panel showed the "correct" combined totals while the visible H2H card remained incorrect.

#### 3. Logic Inconsistency

**Issue:** The visible H2H card and the debug panel were using different categorisation rules.

- **The Debug Panel:** Answered the question: *"What matches exist between these two players?"*
- **The H2H Card:** Answered the question: *"What stats do I get after applying the stricter loader and raw-label grouping?"*
- **Result:** Both views were "correct" relative to their own internal logic, but the lack of shared rules created a discrepancy in the UI.

---

## Part 2: The Full Lifecycle & Sync Strategy

### 1. Match Completion (All Games)

When any game ends, the `ViewModel` triggers `saveMatchResult()`. This ensures data is immediately persisted to the device.

```swift
// From CountdownViewModel.swift (301/501), lines 723-726
MatchStorageManager.shared.saveMatch(matchResult)
MatchStorageManager.shared.updatePlayerStats(for: matchPlayers, winnerId: winner.userId)
```

---

### 2. Background Sync Attempt

Immediately after local save, a background task attempts to sync with Supabase for authenticated users.

```swift
// From CountdownViewModel.swift, lines 733-776
Task {
    if let currentUserId = currentUserId {
        do {
            try await matchService.saveMatch(
                matchId: matchId,
                gameId: gameId,
                players: players
            )

            // ✅ SUCCESS: Delete from local storage after sync
            await MainActor.run {
                MatchStorageManager.shared.deleteMatch(withId: matchId)
                print("🗑️ Member match removed from local storage after sync")
            }
        } catch {
            // ❌ FAILURE: Keep in local storage for retry
            print("⚠️ Failed to sync match to Supabase: \(error)")
        }
    } else {
        // Guest match - stays in local storage permanently
        print("💾 Guest match saved to local storage only")
    }
}
```

---

### 3. The Merge Strategy

To protect against partial syncs or stale data, `MatchHistoryService.swift` uses a "local-first" preference if the local data is more complete.

```swift
// If we have a local version with turn data, prefer it
if let localMatch = localMatchesById[match.id] {
    let localTurns = totalTurns(localMatch)
    let supabaseTurns = totalTurns(match)

    if localTurns > 0 {
        print("✅ Keeping LOCAL version to preserve \(localTurns) turns")
        matchesById[match.id] = localMatch
    }
}
```

---

### Summary of Device Storage Roles

**Guest Matches**
- Storage role: Primary storage
- Duration: Permanent

**Member Matches**
- Storage role: Write-ahead log
- Duration: Temporary — kept until sync is confirmed, then deleted from local storage

**Failed Syncs**
- Storage role: Fallback cache
- Duration: Until next successful sync

Device storage acts as a high-integrity buffer; for members, it ensures no match is lost to connectivity issues.
