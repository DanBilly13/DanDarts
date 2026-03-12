-- =====================================================
-- DanDarts Database Migration 077
-- Fix Duration Calculation in save_remote_visit
-- =====================================================
-- Purpose: Calculate and set duration when match completes
-- Date: 2026-03-12
-- 
-- ISSUE:
-- - started_at is now being set correctly on first visit
-- - duration remains null because it's not calculated
-- - head-to-head loader skips matches with null duration
--
-- FIX:
-- - Calculate duration in save_remote_visit when match completes
-- - Use COALESCE(v_match.started_at, p_timestamp) to handle edge case
--   where winning visit is also the first visit
-- - Guarantees duration is never null for completed matches
-- =====================================================

BEGIN;

-- ============================================
-- UPDATE RPC FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION save_remote_visit(
    p_match_id UUID,
    p_player_id UUID,
    p_throws INTEGER[],
    p_score_before INTEGER,
    p_score_after INTEGER,
    p_is_bust BOOLEAN DEFAULT false,
    p_timestamp TIMESTAMPTZ DEFAULT now()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_match RECORD;
    v_player_order INTEGER;
    v_turn_index INTEGER;
    v_next_player_id UUID;
    v_current_scores JSONB;
    v_new_turn_index INTEGER;
    v_winner_id UUID;
    v_result JSONB;
BEGIN
    -- 1) Fetch match and validate
    SELECT * INTO v_match
    FROM matches
    WHERE id = p_match_id
    FOR UPDATE;  -- Lock row for atomic update
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Match not found: %', p_match_id;
    END IF;
    
    -- 2) Validate user is participant
    IF v_match.challenger_id != p_player_id AND v_match.receiver_id != p_player_id THEN
        RAISE EXCEPTION 'User % is not a participant in match %', p_player_id, p_match_id;
    END IF;
    
    -- 3) Validate match status
    IF v_match.remote_status != 'in_progress' THEN
        RAISE EXCEPTION 'Match is not in progress (status: %)', v_match.remote_status;
    END IF;
    
    -- 4) Validate turn
    IF v_match.current_player_id != p_player_id THEN
        RAISE EXCEPTION 'Not player''s turn (current: %)', v_match.current_player_id;
    END IF;
    
    -- 5) Determine player_order (CANONICAL: challenger=0, receiver=1)
    IF p_player_id = v_match.challenger_id THEN
        v_player_order := 0;
    ELSE
        v_player_order := 1;
    END IF;
    
    -- 6) Compute per-player turn_index
    SELECT COALESCE(MAX(turn_index), -1) + 1
    INTO v_turn_index
    FROM match_throws
    WHERE match_id = p_match_id AND player_order = v_player_order;
    
    -- 7) Insert match_throws row (write is_bust to the boolean column)
    INSERT INTO match_throws (
        match_id,
        player_order,
        turn_index,
        throws,
        score_before,
        score_after,
        is_bust,
        game_metadata,
        created_at
    ) VALUES (
        p_match_id,
        v_player_order,
        v_turn_index,
        p_throws,
        p_score_before,
        p_score_after,
        p_is_bust,
        NULL,
        p_timestamp
    );
    
    -- 8) Update player_scores
    v_current_scores := COALESCE(v_match.player_scores, '{}'::jsonb);
    v_current_scores := jsonb_set(v_current_scores, ARRAY[p_player_id::text], to_jsonb(p_score_after));
    
    -- 9) Increment global turn counter
    v_new_turn_index := COALESCE(v_match.turn_index_in_leg, 0) + 1;
    
    -- 10) Determine next player
    IF p_player_id = v_match.challenger_id THEN
        v_next_player_id := v_match.receiver_id;
    ELSE
        v_next_player_id := v_match.challenger_id;
    END IF;
    
    -- 11) Check for winner (score = 0 and not bust)
    v_winner_id := NULL;
    IF p_score_after = 0 AND NOT p_is_bust THEN
        v_winner_id := p_player_id;
    END IF;
    
    -- 12) Update matches table
    IF v_winner_id IS NOT NULL THEN
        -- Match completed - calculate duration inline using COALESCE
        -- This handles the edge case where winning visit is also first visit
        UPDATE matches SET
            remote_status = 'completed',
            winner_id = v_winner_id,
            started_at = COALESCE(started_at, p_timestamp),
            ended_at = p_timestamp,
            duration = EXTRACT(EPOCH FROM (p_timestamp - COALESCE(v_match.started_at, p_timestamp)))::INTEGER,
            current_player_id = NULL,
            last_visit_payload = jsonb_build_object(
                'player_id', p_player_id,
                'darts', to_jsonb(p_throws),
                'score_before', p_score_before,
                'score_after', p_score_after,
                'timestamp', p_timestamp
            ),
            player_scores = v_current_scores,
            turn_index_in_leg = v_new_turn_index,
            updated_at = p_timestamp
        WHERE id = p_match_id;
        
        v_result := jsonb_build_object(
            'success', true,
            'status', 'completed',
            'winner_id', v_winner_id,
            'turn_index', v_turn_index,
            'player_order', v_player_order
        );
    ELSE
        -- Continue match - set started_at if first visit
        UPDATE matches SET
            started_at = COALESCE(started_at, p_timestamp),
            current_player_id = v_next_player_id,
            last_visit_payload = jsonb_build_object(
                'player_id', p_player_id,
                'darts', to_jsonb(p_throws),
                'score_before', p_score_before,
                'score_after', p_score_after,
                'timestamp', p_timestamp
            ),
            player_scores = v_current_scores,
            turn_index_in_leg = v_new_turn_index,
            updated_at = p_timestamp
        WHERE id = p_match_id;
        
        v_result := jsonb_build_object(
            'success', true,
            'status', 'in_progress',
            'next_player_id', v_next_player_id,
            'turn_index', v_turn_index,
            'player_order', v_player_order
        );
    END IF;
    
    RETURN v_result;
END;
$$;

-- ============================================
-- VERIFICATION
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 077 Complete';
    RAISE NOTICE 'Updated: save_remote_visit RPC function';
    RAISE NOTICE 'Fix: Duration now calculated on match completion';
    RAISE NOTICE 'Edge case: First-visit wins get duration=0';
    RAISE NOTICE 'Guarantee: Duration never null for completed matches';
    RAISE NOTICE '========================================';
END $$;

COMMIT;

-- ============================================
-- ROLLBACK SCRIPT (DO NOT RUN UNLESS NEEDED)
-- ============================================
--
-- If something goes wrong, restore the previous version
-- by running migration 066 again
--
-- ============================================
