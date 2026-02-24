-- ============================================
-- Migration 059: Add Automatic Match Expiration
-- ============================================
-- Purpose: Automatically expire matches past their expiry times
-- and clean up locks, even when no users are online
-- ============================================

-- Function to expire old matches and clean up locks
CREATE OR REPLACE FUNCTION expire_old_matches()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_count INTEGER := 0;
  lock_count INTEGER;
BEGIN
  -- Update expired challenges (past challenge_expires_at)
  -- Applies to: pending, ready states
  WITH updated AS (
    UPDATE matches
    SET 
      remote_status = 'expired',
      ended_at = now(),
      ended_reason = 'expired',
      ended_by = NULL,
      updated_at = now()
    WHERE 
      match_mode = 'remote'
      AND remote_status IN ('pending', 'ready')
      AND challenge_expires_at < now()
    RETURNING id
  )
  SELECT count(*) INTO expired_count FROM updated;
  
  -- Update expired lobby/in_progress matches (past join_window_expires_at)
  -- Only if you want lobby/in_progress to auto-expire
  WITH updated AS (
    UPDATE matches
    SET 
      remote_status = 'expired',
      ended_at = now(),
      ended_reason = 'expired',
      ended_by = NULL,
      updated_at = now()
    WHERE 
      match_mode = 'remote'
      AND remote_status IN ('lobby', 'in_progress')
      AND join_window_expires_at < now()
    RETURNING id
  )
  SELECT count(*) + expired_count INTO expired_count FROM updated;
  
  -- Delete locks for all terminal matches
  WITH deleted AS (
    DELETE FROM remote_match_locks
    WHERE match_id IN (
      SELECT id FROM matches
      WHERE remote_status IN ('expired', 'cancelled', 'completed')
    )
    RETURNING match_id
  )
  SELECT count(*) INTO lock_count FROM deleted;
  
  -- Log if anything was cleaned up
  IF expired_count > 0 OR lock_count > 0 THEN
    RAISE NOTICE '🧹 Expired % matches, cleaned % locks', expired_count, lock_count;
  END IF;
END;
$$;

-- Schedule to run every 1 minute
SELECT cron.schedule(
  'expire-old-matches',
  '* * * * *', -- Every minute
  'SELECT expire_old_matches();'
);

-- Success message
DO $$
BEGIN
  RAISE NOTICE '✅ Migration 059 complete: Automatic match expiration enabled';
END $$;
