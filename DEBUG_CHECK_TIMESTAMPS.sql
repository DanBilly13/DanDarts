-- Check timestamp formats in matches table
SELECT 
    id,
    timestamp,
    pg_typeof(timestamp) as timestamp_type,
    started_at,
    pg_typeof(started_at) as started_at_type,
    ended_at,
    pg_typeof(ended_at) as ended_at_type
FROM matches
ORDER BY created_at DESC
LIMIT 5;
