# 301/501 Ranking System - Implementation Summary

## Overview
Implemented V1 ranking system for 301 and 501 dart games with match-level rank, Winner Darts Thrown bar, and Profile Rank KPI.

## Files Created

### 1. RankingHelper.swift
**Location:** `/DanDart/Utilities/RankingHelper.swift`

**Features:**
- `RankTier` enum: unranked, newby, intermediate, advanced, proLevel, worldClass, immortal
- `rankForWinningDarts(game:dartsThrown:)` - Calculate match-level rank
- `tierScore(for:)` - Convert rank to numeric score (1-6)
- `profileRankFromAverageTierScore(_:)` - Calculate profile rank from average
- `thresholdMarkers(for:)` - Get visual bar threshold positions

**Rank Thresholds:**
- **301:** Immortal ≤6, World Class 7-9, Pro-Level 10-12, Advanced 13-18, Intermediate 19-27, Newby 28+
- **501:** Immortal ≤9, World Class 10-12, Pro-Level 13-15, Advanced 16-21, Intermediate 22-30, Newby 31+

### 2. WinnerDartsThrownBar.swift
**Location:** `/DanDart/Views/Components/WinnerDartsThrownBar.swift`

**Features:**
- Fixed 0-30 dart visual range with linear mapping
- Threshold markers at rank boundaries
- Pointer with rank label (e.g., "PRO LEVEL")
- Pointer clamping to far right for > 30 darts
- Matches existing stat bar styling

### 3. Database Migration
**Location:** `/supabase_migrations/085_add_ranking_fields.sql`

**Schema Changes:**
```sql
ALTER TABLE users
ADD COLUMN ranked_wins_count_301_501 INTEGER DEFAULT 0,
ADD COLUMN ranked_tier_score_total_301_501 INTEGER DEFAULT 0;
```

## Files Modified

### 1. User.swift
**Changes:**
- Added `rankedWinsCount301501: Int`
- Added `rankedTierScoreTotal301501: Int`
- Added computed `rankedAverageTierScore301501: Double`
- Added computed `profileRank: RankTier`
- Updated `toPlayer()` to pass ranking fields
- Updated CodingKeys for snake_case mapping

### 2. Player.swift
**Changes:**
- Added `rankedWinsCount301501: Int`
- Added `rankedTierScoreTotal301501: Int`
- Added computed `rankedAverageTierScore301501: Double`
- Added computed `profileRank: RankTier`
- Added computed `rankDisplayName: String`
- Updated initializer with ranking defaults
- Updated `withUpdatedStats()` to preserve ranking

### 3. MatchService.swift
**Changes:**
- Updated `saveMatch()` signature to accept `winnerDartsThrown` and `gameType`
- Updated `saveRemoteMatchDetails()` signature to accept ranking parameters
- Updated `updatePlayerStats()` to:
  - Accept `winnerDartsThrown` and `gameType` parameters
  - Calculate rank tier for 301/501 winners
  - Increment `ranked_wins_count_301_501`
  - Add tier score to `ranked_tier_score_total_301_501`
  - Update database with new fields
  - Return updated User with ranking stats

### 4. CountdownViewModel.swift (Local 301/501)
**Changes:**
- Extract winner's `totalDartsThrown` from `MatchPlayer`
- Pass `winnerDartsThrown` and `gameType` to `MatchService.saveMatch()`

### 5. RemoteGameViewModel.swift (Remote 301/501)
**Changes:**
- Extract winner's `totalDartsThrown` from `MatchPlayer`
- Pass `winnerDartsThrown` and `gameType` to `MatchService.saveRemoteMatchDetails()`

### 6. MatchDetailView.swift
**Changes:**
- Added `WinnerDartsThrownBar` component for 301/501 matches
- Positioned at top of stats section
- Conditional rendering: `if match.gameType == "301" || match.gameType == "501"`

### 7. ProfileHeaderView.swift
**Changes:**
- Added 4th StatCard for Rank
- Icon: `star.circle.fill`
- Value: `player.rankDisplayName`
- Reduced spacing from 12 to 8 to fit 4 cards

## Data Flow

### Match Completion (Local)
1. `CountdownViewModel.saveMatchResult()` builds `MatchPlayer` with `totalDartsThrown`
2. Extract winner's darts: `matchPlayers.first { $0.id == winnerId }?.totalDartsThrown`
3. Pass to `MatchService.saveMatch(winnerDartsThrown:gameType:)`
4. `MatchService.updatePlayerStats()` calculates rank and updates DB
5. Returns updated `User` with new ranking stats
6. `AuthService.currentUser` updated with fresh data

### Match Completion (Remote)
1. `RemoteGameViewModel.saveMatchResult()` builds `MatchPlayer` with `totalDartsThrown`
2. Extract winner's darts from `matchPlayers`
3. Pass to `MatchService.saveRemoteMatchDetails(winnerDartsThrown:gameType:)`
4. Same `updatePlayerStats()` logic as local
5. Returns updated `User`
6. `AuthService.currentUser` updated

### Profile Display
1. `User.profileRank` computed from `rankedAverageTierScore301501`
2. `User.toPlayer()` passes ranking fields to `Player`
3. `Player.rankDisplayName` returns `profileRank.displayName`
4. `ProfileHeaderView` displays via `StatCard`

## Key Design Decisions

### V1 Minimal Storage
- **Stored:** Count + total tier score only
- **Derived:** Average tier score and rank label in code
- **Rationale:** Simpler schema, easier to maintain, no cached data staleness

### Authoritative Data Source
- **Source:** `MatchPlayer.totalDartsThrown` (already calculated from turns)
- **No Recalculation:** Trust the saved match data
- **Rationale:** Single source of truth, avoid duplicate logic

### Fixed Visual Range (0-30 darts)
- **Mapping:** Linear scale to bar width
- **Clamping:** Pointer at far right for > 30 darts
- **Rationale:** Consistent UX, handles edge cases gracefully

### Tier Score Averaging
- **Method:** Average tier scores (1-6), not raw darts
- **Rationale:** Properly combines 301 and 501 performances

## Testing Checklist

- [ ] **Match-level rank accuracy**
  - [ ] 301 winner in 6 darts → Immortal
  - [ ] 301 winner in 11 darts → Pro-Level
  - [ ] 501 winner in 14 darts → Pro-Level
  - [ ] 501 winner in 31 darts → Newby

- [ ] **Winner Darts Thrown bar**
  - [ ] Displays for 301/501 matches only
  - [ ] Pointer position correct for various dart counts
  - [ ] Pointer clamps at right edge for > 30 darts
  - [ ] Rank label shows correct tier
  - [ ] Threshold markers at correct positions

- [ ] **Profile Rank KPI**
  - [ ] Shows "Unranked" for 0 wins
  - [ ] Shows correct rank after 1 win
  - [ ] Updates correctly after multiple wins
  - [ ] Averages tier scores correctly across 301 and 501

- [ ] **Database persistence**
  - [ ] Migration runs successfully
  - [ ] Rank fields update on local match win
  - [ ] Rank fields update on remote match win
  - [ ] Stats persist across app restarts

- [ ] **UI integration**
  - [ ] Rank KPI fits in profile stats row
  - [ ] Winner bar matches existing stat bar styling
  - [ ] No layout issues on various screen sizes

## Future Enhancements (Not in V1)

- Leaderboards (global/friends)
- Rank history tracking
- Rank badges/achievements
- Separate ranks for 301 vs 501
- Rank decay over time
- Minimum games requirement
- Rank distribution analytics
