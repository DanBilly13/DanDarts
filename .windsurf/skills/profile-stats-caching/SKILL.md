---
name: profile-stats-caching
description: how profile statistics are cached, persisted, and refreshed in dart freak. use when working on ProfileView, ProfileStatsService, profile stat charts, slow or repeated stat loading, stale stats after a match, the persisted stats snapshot, or any task touching profile stat freshness, loading spinners on the profile, or per-user stat isolation. do not use for History tab match lists, match detail loading in general, or server-side aggregation unless specifically extending this caching system.
---

# Profile Stats Caching

How Dart Freak loads, persists, and refreshes the statistics shown on the
user profile. This system makes the profile feel instant and avoids
recomputing on every visit.

It is the rule set for `ProfileStatsService` and the profile stat charts.

## Why This Exists

Profile stats are computed client-side from the user's full 301/501 match
history (turn-by-turn data). Recomputing on every visit was slow and showed
a loading spinner each time. This system fixes that with three layers:

1. **Persisted snapshot** — instant display, survives relaunch.
2. **Freshness gate** — skip recompute when recently computed.
3. **Silent refresh** — spinner only on first-ever load.

## Key Files

| File | Role |
|------|------|
| `ProfileStatsService.swift` | Owns computation, persistence, freshness gate |
| `ProfileStats.swift` | Stat models (all `Codable` for persistence) |
| `ProfileView.swift` | Calls the gated entry point; forces refresh on match completion |
| `AuthService.swift` | Clears the snapshot on sign-out |

## Core Rules

### 1. Always call the gated entry point from the UI
`ProfileView` must call `calculateStatsIfNeeded(userId:force:)`, never
`calculateStats` directly. The gate skips recompute when stats for the same
user were computed within `cacheTTL` (currently 60s).

```swift
// .task
await statsService.calculateStatsIfNeeded(userId: userId)
// MatchCompleted notification
await statsService.calculateStatsIfNeeded(userId: userId, force: true)
```

### 2. Spinner only on first-ever load
`isLoading` is set **only** when `lastCalculatedAt == nil` (no data yet).
Every other refresh updates the published values in place, silently.
Do not reintroduce unconditional `isLoading = true`.

### 3. Persistence is user-scoped
The snapshot (`profile_stats.json`) stores `userId`. On launch,
`loadPersistedSnapshot()` adopts it **only if** it matches
`AuthService.shared.currentUser?.id`. Sign-out calls
`clearPersistedStats()` (via `clearAuthenticationState`). This prevents one
account from showing another's stats.

### 4. Coalesce concurrent computes
`calculateStats` is guarded by `isCalculating` so a `.task` firing alongside
a `MatchCompleted` notification cannot double-run.

### 5. Detail fetches run in parallel
`loadCountdownMatches` uses `withTaskGroup` to fetch per-match detail
concurrently, then sorts by timestamp. Do not revert to a serial
`for` loop — that was the original N+1 bottleneck.

## Refresh Triggers

| Trigger | Behavior |
|---------|----------|
| Revisit Profile (< TTL) | Skip — instant, no work |
| Revisit Profile (> TTL) | Silent background refresh |
| App relaunch | Show persisted snapshot instantly, refresh if stale |
| `MatchCompleted` (local or remote) | Forced silent refresh |
| Sign out | Snapshot + in-memory stats cleared |

`MatchCompleted` is posted by `CountdownViewModel`, `HalveItViewModel`, and
`RemoteGameViewModel` after a successful save — so both local and remote
completions refresh profile stats.

## Gotchas

- **Stat models must stay `Codable`.** Adding a non-Codable field to a
  persisted stat type breaks the snapshot. Decode is `try?`-guarded so it
  fails safe (recomputes), but you lose the instant display.
- **`refreshSummaries` still calls `detailCache.removeAll()`.** Forced
  refreshes re-fetch all detail. This is intentional (avoids History-tab
  side effects); TTL + persistence keep forced refreshes infrequent.
- **Only 301/501 countdown matches** feed these stats; the summary filter
  in `loadCountdownMatches` enforces this.

## Scope Boundary

This skill covers the profile stat caching system only. It does not govern
the History tab match list, generic match detail loading, or server-side
aggregation. Server-side aggregation remains the durable option if match
histories grow very large.
