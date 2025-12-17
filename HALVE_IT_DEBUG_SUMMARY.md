# Halve-It Match Sync Debug Summary

## Problem
After a Halve-It match is synced to Supabase and the local copy is deleted, viewing match details shows 0% hit rates and missing round-by-round breakdown.

## What We Know

### ✅ Data Saves Successfully
```
📤 Attempting to insert 12 throw records...
✅ Insert response status: 201
✅ Match saved successfully
```

### ❌ Data Loading Fails
```
⚠️ Failed to query turn data for match: 
PostgrestError(code: "22023", message: "cannot extract elements from a scalar")
```

### 🔍 Key Findings

1. **INSERT works** - Status 201, data accepted by Supabase
2. **SELECT fails** - PostgreSQL error when querying back
3. **Error code 22023** - "cannot extract elements from a scalar"
   - This means PostgreSQL is trying to use array operators on non-array data
   - OR trying to extract from JSONB in an incompatible way

4. **Database column type**: `throws` is JSONB (confirmed in screenshot)

5. **Data structure**: `dart_scores: [Int]` mapped to `throws` column

## Hypothesis

The issue is likely one of:

1. **PostgREST array operator issue**: When PostgREST sees a JSONB array column, it might be trying to apply PostgreSQL array operators (`[]`, `array_length`, etc.) which don't work on JSONB
   
2. **Encoding mismatch**: The Swift `[Int]` array is being encoded as JSONB, but PostgREST is expecting a PostgreSQL native array type

3. **Query parameter issue**: The Supabase Swift client might be adding query parameters that cause PostgREST to treat the JSONB as a native array

## Next Steps

1. Try SELECT * instead of explicit column selection
2. If that fails, check actual database data with raw SQL
3. May need to change column back to INTEGER[] or use a different encoding strategy
