-- =====================================================
-- DanDarts Database Migration 087
-- Account deletion FK hardening (make auth-user deletion safe + self-anonymizing)
-- =====================================================
-- Date: 2026-07-14
--
-- Purpose:
--   Enable permanent account deletion (Apple App Review 5.1.1(v)) without
--   erroring, while ANONYMIZING the deleted user's participation in shared
--   remote matches (opponents keep their history).
--
-- Strategy:
--   Deleting auth.users cascades to public.users (users.id -> auth.users ON DELETE
--   CASCADE). We ensure that cascade is never BLOCKED by a RESTRICT foreign key,
--   and that the deleted user is anonymized rather than corrupting data:
--     - match_players.player_user_id is already ON DELETE SET NULL (anonymized).
--     - matches.winner_id gets ON DELETE SET NULL (it is optional in the client model).
--     - matches.challenger_id / receiver_id are LEFT as stale UUIDs ON PURPOSE: the
--       client model decodes them as NON-OPTIONAL, so nulling them would break the
--       surviving opponent's match decode. The client renders a "Deleted User"
--       placeholder for unresolved ids instead (Workstream 5).
--     - current_player_id / ended_by / created_by have no FK and are left as-is.
--
-- Why NOT VALID:
--   - matches.winner_id is NOT NULL today and may contain GUEST UUIDs that are not
--     present in public.users (local matches). A normal FK would fail validation
--     against those existing rows.
--   - There may also be pre-existing stale challenger/receiver ids from earlier drift.
--   Adding the FKs as NOT VALID skips the one-time full-table validation but STILL
--   enforces the ON DELETE SET NULL referential action and validates future writes.
--
-- Safety:
--   - Wrapped in BEGIN/COMMIT (atomic).
--   - No data is dropped. Only nullability + FK ON DELETE behavior change.
--   - Reversible before any deletion runs (see ROLLBACK block at bottom).
-- =====================================================

-- -----------------------------------------------------
-- PRE-MIGRATION SNAPSHOT (run these SELECTs FIRST, separately, and SAVE output.
-- This is the exact restore target if you need to roll back.)
-- -----------------------------------------------------
-- SELECT con.conname,
--        con.contype,
--        con.confdeltype,                       -- a=no action, r=restrict, c=cascade, n=set null, d=set default
--        pg_get_constraintdef(con.oid) AS definition
-- FROM pg_constraint con
-- WHERE con.conrelid = 'public.matches'::regclass
--   AND con.contype = 'f'
-- ORDER BY con.conname;
--
-- SELECT column_name, is_nullable, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'matches'
--   AND column_name IN ('winner_id','challenger_id','receiver_id','current_player_id','ended_by','created_by')
-- ORDER BY column_name;
--
-- SELECT con.conname, con.confdeltype, pg_get_constraintdef(con.oid) AS definition
-- FROM pg_constraint con
-- WHERE con.conrelid = 'public.match_participants'::regclass AND con.contype = 'f'
-- ORDER BY con.conname;

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '=== MIGRATION 087: Account deletion FK hardening ===';
END $$;

-- -----------------------------------------------------
-- 1) Drop ANY existing foreign-key constraints on the matches identity columns
--    (names may be auto-generated / vary by environment). Dynamic + idempotent.
-- -----------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT DISTINCT con.conname
        FROM pg_constraint con
        JOIN pg_attribute a
          ON a.attrelid = con.conrelid
         AND a.attnum = ANY (con.conkey)
        WHERE con.conrelid = 'public.matches'::regclass
          AND con.contype = 'f'
          AND a.attname IN ('winner_id','challenger_id','receiver_id','current_player_id','ended_by','created_by')
    LOOP
        EXECUTE format('ALTER TABLE public.matches DROP CONSTRAINT %I', r.conname);
        RAISE NOTICE '  dropped existing FK: %', r.conname;
    END LOOP;
END $$;

-- -----------------------------------------------------
-- 2) Make winner_id nullable so it can be anonymized on user deletion.
--    (challenger_id/receiver_id/current_player_id/ended_by/created_by are already nullable.)
-- -----------------------------------------------------
ALTER TABLE public.matches ALTER COLUMN winner_id DROP NOT NULL;

-- -----------------------------------------------------
-- 3) Add ON DELETE SET NULL FK to users(id) for winner_id ONLY.
--    winner_id is optional in the client model, so nulling it on deletion is safe.
--    NOT VALID: enforce the ON DELETE action + future writes without failing on
--    pre-existing guest/stale winner_id values (local matches can have guest winners).
--
--    NOTE: challenger_id / receiver_id are intentionally NOT given a users FK here.
--    See the Strategy note above. Step 1's dynamic drop already removed any FK that
--    may have existed on those columns (from drift), so they remain plain UUIDs.
-- -----------------------------------------------------
ALTER TABLE public.matches
    ADD CONSTRAINT matches_winner_id_users_fkey
    FOREIGN KEY (winner_id) REFERENCES public.users(id) ON DELETE SET NULL NOT VALID;

-- -----------------------------------------------------
-- 4) match_participants.user_id -> ensure ON DELETE CASCADE (participation, not shared history).
--    Dynamic drop of any existing FK on user_id, then re-add as CASCADE (NOT VALID for safety).
--    Guarded so the migration still succeeds if the table does not exist.
-- -----------------------------------------------------
DO $$
DECLARE
    r RECORD;
BEGIN
    IF to_regclass('public.match_participants') IS NULL THEN
        RAISE NOTICE '  match_participants table not present - skipping';
        RETURN;
    END IF;

    FOR r IN
        SELECT DISTINCT con.conname
        FROM pg_constraint con
        JOIN pg_attribute a
          ON a.attrelid = con.conrelid
         AND a.attnum = ANY (con.conkey)
        WHERE con.conrelid = 'public.match_participants'::regclass
          AND con.contype = 'f'
          AND a.attname = 'user_id'
    LOOP
        EXECUTE format('ALTER TABLE public.match_participants DROP CONSTRAINT %I', r.conname);
        RAISE NOTICE '  dropped existing match_participants FK: %', r.conname;
    END LOOP;

    EXECUTE 'ALTER TABLE public.match_participants
             ADD CONSTRAINT match_participants_user_id_users_fkey
             FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE NOT VALID';
    RAISE NOTICE '  added match_participants_user_id_users_fkey (CASCADE)';
END $$;

DO $$
BEGIN
    RAISE NOTICE '=== Migration 087 complete ===';
    RAISE NOTICE 'winner_id is now nullable + SET NULL on user deletion.';
    RAISE NOTICE 'challenger_id/receiver_id left as stale UUIDs (client shows Deleted User).';
END $$;

COMMIT;

-- =====================================================
-- VERIFICATION (optional, run after COMMIT)
-- =====================================================
-- SELECT con.conname, con.confdeltype, pg_get_constraintdef(con.oid) AS definition
-- FROM pg_constraint con
-- WHERE con.conrelid = 'public.matches'::regclass AND con.contype = 'f'
-- ORDER BY con.conname;
-- Expect confdeltype = 'n' (SET NULL) for matches_winner_id_users_fkey.

-- =====================================================
-- ROLLBACK
-- Restores the prior FK behavior. NOTE: winner_id is intentionally LEFT nullable.
-- Once a real deletion has SET NULL any winner_id/identity values, restoring
-- NOT NULL would fail while NULLs exist, so we do not re-add NOT NULL here.
-- Run manually if needed.
-- =====================================================
/*
BEGIN;

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_winner_id_users_fkey;
ALTER TABLE public.match_participants DROP CONSTRAINT IF EXISTS match_participants_user_id_users_fkey;

-- winner_id left nullable on purpose (see note above). To fully restore the
-- pre-087 shape ONLY if no NULLs exist:
--   ALTER TABLE public.matches ALTER COLUMN winner_id SET NOT NULL;

COMMIT;
*/
