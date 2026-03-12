# H2H Debug Panel Implementation Complete

## Overview
Implemented a comprehensive debug panel for head-to-head match inspection on the FriendProfileView. This panel exposes all raw data, filtering decisions, and data sources to identify why matches aren't appearing correctly in the UI.

## Files Created

### 1. H2HDebugData.swift
**Location**: `DanDart/Models/H2HDebugData.swift`

Data structures for debug information:
- `H2HDebugData` - Main container with player stats, H2H summary, match details, category stats, and excluded matches
- `MatchDebugDetail` - Individual match with all fields including match_mode, remote_status, duration, participants, source, and inclusion status
- `CategoryStats` - Win/loss counts for specific categories (301 local, remote, combined)
- `ExcludedMatchDetail` - Matches that were filtered out with reasons
- `DataSource` enum - Tracks whether data came from local, Supabase, or merged

### 2. H2HDebugService.swift
**Location**: `DanDart/Services/H2HDebugService.swift`

Service for collecting comprehensive debug data:
- `collectDebugData()` - Main method that gathers all debug information
- Queries raw `matches` table directly to get match_mode and remote_status fields
- Queries `match_participants` table for participant information
- Queries local storage via MatchStorageManager
- Compares and merges data from both sources
- Applies same filtering logic as real H2H but tracks exclusion reasons
- Categorizes matches into 301 local, 301 remote, and combined
- Identifies excluded matches with specific reasons:
  - Missing duration
  - Missing winner_id
  - Missing participants
  - Not both participants
  - Duration is 0

### 3. H2HDebugPanelView.swift
**Location**: `DanDart/Views/Debug/H2HDebugPanelView.swift`

Collapsible debug UI component with 5 sections:

**Section 1: Player Stats**
- Current user total wins/losses
- Friend total wins/losses

**Section 2: H2H Summary (App Display)**
- Current user wins
- Friend wins
- Total matches displayed

**Section 3: Match Details (Scrollable)**
For each match shows:
- ✅ INCLUDED or ❌ EXCLUDED status (color-coded)
- Match ID (truncated)
- Created date
- Game type and name
- Match mode (local/remote)
- Remote status (if applicable)
- Winner ID
- Duration (highlighted in red if null)
- Participant names
- Data source (Local/Supabase/Merged)
- Exclusion reason (if excluded)

**Section 4: Category Breakdown**
Three separate stats blocks:
- 301 (Local Only)
- 301 (Remote Only)
- 301 (Combined)

Each shows:
- Current user wins
- Friend wins
- Total matches
- Match IDs (truncated)

**Section 5: Excluded Matches**
List of all excluded matches with:
- Match ID
- Exclusion reason (in red)
- Game type
- Created date
- Data source

### 4. FriendProfileView.swift (Modified)
**Location**: `DanDart/Views/Friends/FriendProfileView.swift`

Integrated debug panel:
- Added `#if DEBUG` wrapped state for debug data and service
- Added debug panel view below normal H2H section
- Loads debug data alongside normal H2H matches
- Panel is collapsible and defaults to collapsed
- Only visible in DEBUG builds

## Key Features

1. **Complete Data Visibility**
   - Shows raw player stats from users table
   - Displays all matches found in both local and Supabase
   - Exposes fields not in MatchResult model (match_mode, remote_status)

2. **Inclusion/Exclusion Tracking**
   - Every match clearly marked as included or excluded
   - Specific reason shown for each exclusion
   - Color-coded (green for included, red for excluded)

3. **Multi-Source Comparison**
   - Queries both local storage and Supabase
   - Shows which source each match came from
   - Identifies discrepancies between sources

4. **Category Breakdown**
   - Separate counts for 301 local, remote, and combined
   - Shows exactly which matches are in each category
   - Helps identify if remote matches are being filtered

5. **Raw Database Fields**
   - Queries matches table directly for all fields
   - Shows match_mode and remote_status
   - Displays duration as null when missing (highlighted in red)

6. **Clean Integration**
   - Collapsible section (default collapsed)
   - Below normal H2H section
   - `#if DEBUG` only - won't appear in production
   - Labeled "H2H DEBUG (temporary)"

## Usage

1. Build app in DEBUG mode
2. Navigate to a friend's profile
3. Scroll down below the normal head-to-head section
4. Tap to expand the "H2H DEBUG (temporary)" section
5. Review all 5 sections to identify data issues

## Expected Findings

Based on the database query showing 9 matches but UI showing none, the debug panel should reveal:

- **Section 1**: Player stats showing correct total wins/losses
- **Section 2**: H2H summary showing 0 matches (current bug)
- **Section 3**: All 9 matches listed with most/all marked as EXCLUDED
- **Exclusion reasons**: Likely "Missing duration" for remote matches
- **Section 4**: Category breakdown showing matches exist but aren't included
- **Section 5**: All 9 matches in excluded list with "Missing duration" reason

This will confirm that the root cause is null duration values preventing matches from being included in H2H stats.

## Next Steps

Once the debug panel confirms the issue:
1. Deploy the updated `join-match` edge function (sets started_at)
2. Run migration 078 (adds duration calculation to save_remote_visit)
3. Play a new remote match
4. Check debug panel to verify duration is now populated
5. Confirm match appears in normal H2H section
6. Remove debug panel code when issue is resolved

## Files Summary

**Created:**
- `DanDart/Models/H2HDebugData.swift`
- `DanDart/Services/H2HDebugService.swift`
- `DanDart/Views/Debug/H2HDebugPanelView.swift`

**Modified:**
- `DanDart/Views/Friends/FriendProfileView.swift`

All code is wrapped in `#if DEBUG` to ensure it doesn't appear in production builds.
