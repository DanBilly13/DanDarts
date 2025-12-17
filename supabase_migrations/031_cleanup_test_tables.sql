-- Clean up test tables and backup after successful fix

BEGIN;

-- Drop the test table (no longer needed)
DROP TABLE IF EXISTS match_throws_test;

-- Drop the backup table (old broken table)
DROP TABLE IF EXISTS match_throws_old_backup;

-- Verify only the working table remains
SELECT tablename 
FROM pg_tables 
WHERE tablename LIKE 'match_throws%' 
AND schemaname = 'public';

COMMIT;

-- Expected output: Only 'match_throws' should remain
