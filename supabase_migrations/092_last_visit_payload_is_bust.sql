-- =====================================================
-- DanDarts Database Migration 092
-- Echo is_bust into last_visit_payload
-- =====================================================
-- Date: 2026-08-20
--
-- Problem:
--   save_remote_visit already receives p_is_bust as an input parameter
--   (stored into match_throws.is_bust), but never echoes it into
--   last_visit_payload -- the only per-visit data the client actually
--   reads to drive the Pre-Turn Reveal / turn-lock overlay. Android's
--   remote gameplay screen wants to show a "Bust" subtitle under its
--   lockout overlay when the opponent's last visit busted, and currently
--   has no way to know that from the client-visible data.
--
-- Fix:
--   Reissue save_remote_visit (unchanged from migration 090's body
--   otherwise) with 'is_bust', COALESCE(p_is_bust, false) added to all
--   three last_visit_payload jsonb_build_object(...) calls.
--
-- IMPORTANT: migration 091 pinned this function's search_path via
--   ALTER FUNCTION ... SET search_path = public. A plain CREATE OR
--   REPLACE FUNCTION here would silently drop that pin, so this
--   definition explicitly re-declares SET search_path = public itself.
--
-- Backward compatible: existing rows' last_visit_payload simply lack the
-- key until their next visit; LastVisitPayload.isBust defaults to false
-- client-side for any payload missing the field.
-- =====================================================

BEGIN;

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
SET search_path = public
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
    v_legs_won JSONB;
    v_player_legs INTEGER;
    v_legs_needed INTEGER;
    v_starting_score INTEGER;
BEGIN
    -- 1) Fetch match and validate
    SELECT * INTO v_match
    FROM matches
    WHERE id = p_match_id
    FOR UPDATE;

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

    -- 7) Insert match_throws row
    INSERT INTO match_throws (
        match_id, player_order, turn_index, throws,
        score_before, score_after, is_bust, game_metadata, created_at
    ) VALUES (
        p_match_id, v_player_order, v_turn_index, p_throws,
        p_score_before, p_score_after, p_is_bust, NULL, p_timestamp
    );

    -- 8) Update player_scores (this player's score -- overwritten below by
    -- a full reset for BOTH players if this visit ends a leg but not the match)
    v_current_scores := COALESCE(v_match.player_scores, '{}'::jsonb);
    v_current_scores := jsonb_set(v_current_scores, ARRAY[p_player_id::text], to_jsonb(p_score_after));

    -- 9) Increment global turn counter (reset to 0 on a leg boundary below)
    v_new_turn_index := COALESCE(v_match.turn_index_in_leg, 0) + 1;

    -- 10) Determine next player (also this leg's next-leg starter if this
    -- visit ends a leg -- same flip either way, no special-casing needed)
    IF p_player_id = v_match.challenger_id THEN
        v_next_player_id := v_match.receiver_id;
    ELSE
        v_next_player_id := v_match.challenger_id;
    END IF;

    -- 11) Leg-aware win-check (from migration 090, unchanged here)
    v_winner_id := NULL;
    IF p_score_after = 0 AND NOT p_is_bust THEN
        v_legs_won := COALESCE(v_match.legs_won, '{}'::jsonb);
        v_player_legs := COALESCE((v_legs_won ->> p_player_id::text)::INTEGER, 0) + 1;
        v_legs_won := jsonb_set(v_legs_won, ARRAY[p_player_id::text], to_jsonb(v_player_legs));
        v_legs_needed := (v_match.match_format / 2) + 1;

        IF v_player_legs >= v_legs_needed THEN
            -- 11a) Match complete -- unchanged from migration 090
            v_winner_id := p_player_id;

            UPDATE matches SET
                remote_status = 'completed',
                winner_id = v_winner_id,
                ended_at = p_timestamp,
                duration = EXTRACT(EPOCH FROM (p_timestamp - COALESCE(v_match.started_at, p_timestamp)))::INTEGER,
                current_player_id = NULL,
                last_visit_payload = jsonb_build_object(
                    'player_id', p_player_id, 'darts', to_jsonb(p_throws),
                    'score_before', p_score_before, 'score_after', p_score_after,
                    'is_bust', COALESCE(p_is_bust, false),
                    'timestamp', p_timestamp
                ),
                player_scores = v_current_scores,
                legs_won = v_legs_won,
                turn_index_in_leg = v_new_turn_index,
                updated_at = p_timestamp
            WHERE id = p_match_id;

            v_result := jsonb_build_object(
                'success', true, 'status', 'completed', 'winner_id', v_winner_id,
                'turn_index', v_turn_index, 'player_order', v_player_order
            );
        ELSE
            -- 11b) Leg complete, match continues -- unchanged from migration 090
            v_starting_score := v_match.game_type::INTEGER;
            v_current_scores := jsonb_build_object(
                v_match.challenger_id::text, v_starting_score,
                v_match.receiver_id::text, v_starting_score
            );

            UPDATE matches SET
                current_player_id = v_next_player_id,
                last_visit_payload = jsonb_build_object(
                    'player_id', p_player_id, 'darts', to_jsonb(p_throws),
                    'score_before', p_score_before, 'score_after', p_score_after,
                    'is_bust', COALESCE(p_is_bust, false),
                    'timestamp', p_timestamp
                ),
                player_scores = v_current_scores,
                legs_won = v_legs_won,
                turn_index_in_leg = 0,
                updated_at = p_timestamp
            WHERE id = p_match_id;

            v_result := jsonb_build_object(
                'success', true, 'status', 'in_progress', 'next_player_id', v_next_player_id,
                'turn_index', v_turn_index, 'player_order', v_player_order, 'leg_completed', true
            );
        END IF;
    ELSE
        -- 12) Non-leg-ending visit -- unchanged from migration 090
        UPDATE matches SET
            current_player_id = v_next_player_id,
            last_visit_payload = jsonb_build_object(
                'player_id', p_player_id, 'darts', to_jsonb(p_throws),
                'score_before', p_score_before, 'score_after', p_score_after,
                'is_bust', COALESCE(p_is_bust, false),
                'timestamp', p_timestamp
            ),
            player_scores = v_current_scores,
            turn_index_in_leg = v_new_turn_index,
            updated_at = p_timestamp
        WHERE id = p_match_id;

        v_result := jsonb_build_object(
            'success', true, 'status', 'in_progress', 'next_player_id', v_next_player_id,
            'turn_index', v_turn_index, 'player_order', v_player_order
        );
    END IF;

    RETURN v_result;
END;
$$;

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Migration 092 Complete';
    RAISE NOTICE 'Updated: save_remote_visit (echoes is_bust into last_visit_payload, search_path pin preserved)';
    RAISE NOTICE '========================================';
END $$;

COMMIT;
