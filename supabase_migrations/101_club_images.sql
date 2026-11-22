-- DanDarts Database Migration 101
-- Purpose: Clubs: a club photo. The admin picks a photo; everyone sees it in place of the letter
--          tile (Clubs tab, search, the join sheet, the club page). No photo = the letter tile.
-- Safety:  Additive. Adds clubs.image_url, a public "club-images" storage bucket with its rules,
--          and set_club_image(). Replaces my_clubs, search_clubs and preview_club_by_code with
--          the same columns plus image_url at the end (DROP + CREATE, because the returned
--          columns change; older app builds ignore the extra column). Safe to re-run.
-- Apply:   Supabase SQL editor. First run it wrapped as is but with the final COMMIT changed to
--          ROLLBACK to prove it applies, then run it again with COMMIT.
-- Notes:   Files live at club-images/<club id>/<random>.jpg. Only the club's admin can add,
--          replace or delete files in that club's folder. Anyone can read (the URL is public,
--          like avatars), which is fine: the app only shows it to people allowed to see the club.
--          Reporting: report_content('club', id, 'photo') records a report about the photo.

BEGIN;

ALTER TABLE public.clubs
  ADD COLUMN IF NOT EXISTS image_url TEXT CHECK (image_url IS NULL OR char_length(image_url) <= 500);

-- Storage bucket: public read, JPEG/PNG/HEIC up to 2 MB.
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('club-images', 'club-images', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/heic'])
ON CONFLICT (id) DO UPDATE
  SET public = EXCLUDED.public,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

-- True when the caller is the admin of the club whose id is the first folder of a storage path.
-- A path whose first folder isn't a uuid is simply refused (no cast error).
CREATE OR REPLACE FUNCTION public.can_manage_club_image(p_object_name TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_folder TEXT := split_part(coalesce(p_object_name, ''), '/', 1);
BEGIN
  IF v_folder !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' THEN
    RETURN false;
  END IF;
  RETURN public.is_club_admin(v_folder::UUID);
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_club_image(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_club_image(TEXT) TO authenticated;

DROP POLICY IF EXISTS "Club images are publicly readable" ON storage.objects;
CREATE POLICY "Club images are publicly readable"
  ON storage.objects FOR SELECT TO public
  USING (bucket_id = 'club-images');

DROP POLICY IF EXISTS "Club admins can upload club images" ON storage.objects;
CREATE POLICY "Club admins can upload club images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'club-images' AND public.can_manage_club_image(name));

DROP POLICY IF EXISTS "Club admins can replace club images" ON storage.objects;
CREATE POLICY "Club admins can replace club images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'club-images' AND public.can_manage_club_image(name))
  WITH CHECK (bucket_id = 'club-images' AND public.can_manage_club_image(name));

DROP POLICY IF EXISTS "Club admins can delete club images" ON storage.objects;
CREATE POLICY "Club admins can delete club images"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'club-images' AND public.can_manage_club_image(name));

-- Set or clear (p_url NULL) the photo. Admin only, and the URL must point into this club's own
-- folder in the club-images bucket, so nobody can set a photo hosted anywhere else.
-- Result codes: ok, not_authenticated, not_admin, invalid_url.
CREATE OR REPLACE FUNCTION public.set_club_image(p_club_id UUID, p_url TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url TEXT := nullif(btrim(coalesce(p_url, '')), '');
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 'not_authenticated';
  END IF;
  IF NOT public.is_club_admin(p_club_id) THEN
    RETURN 'not_admin';
  END IF;
  IF v_url IS NOT NULL AND (
       char_length(v_url) > 500
       OR v_url NOT LIKE 'https://%/storage/v1/object/public/club-images/' || p_club_id::TEXT || '/%'
     ) THEN
    RETURN 'invalid_url';
  END IF;

  UPDATE public.clubs SET image_url = v_url WHERE id = p_club_id;
  RETURN 'ok';
END;
$$;

REVOKE ALL ON FUNCTION public.set_club_image(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_club_image(UUID, TEXT) TO authenticated;

-- my_clubs, search_clubs and preview_club_by_code: as in 096/100, plus image_url at the end.

DROP FUNCTION IF EXISTS public.my_clubs();
CREATE FUNCTION public.my_clubs()
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  visibility TEXT,
  member_count INTEGER,
  join_code TEXT,
  role TEXT,
  joined_at TIMESTAMPTZ,
  image_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT c.id, c.name, c.town, c.visibility, c.member_count, c.join_code, m.role, m.joined_at, c.image_url
  FROM public.club_members m
  JOIN public.clubs c ON c.id = m.club_id
  WHERE m.user_id = auth.uid()
  ORDER BY m.joined_at, c.name;
END;
$$;

DROP FUNCTION IF EXISTS public.search_clubs(TEXT);
CREATE FUNCTION public.search_clubs(p_query TEXT)
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  member_count INTEGER,
  avatars TEXT[],
  is_member BOOLEAN,
  image_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_q TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_q := public.club_normalize(p_query);
  IF char_length(v_q) < 2 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.town,
    c.member_count,
    coalesce((
      SELECT array_agg(a.avatar_url)
      FROM (
        SELECT u.avatar_url
        FROM public.club_members m
        JOIN public.users u ON u.id = m.user_id
        WHERE m.club_id = c.id AND u.club_discoverable AND u.avatar_url IS NOT NULL
        ORDER BY m.joined_at, m.user_id
        LIMIT 3
      ) a
    ), ARRAY[]::TEXT[]),
    EXISTS (SELECT 1 FROM public.club_members mm WHERE mm.club_id = c.id AND mm.user_id = v_uid),
    c.image_url
  FROM public.clubs c
  WHERE c.visibility = 'open'
    AND (c.name_key LIKE '%' || v_q || '%' OR coalesce(c.town_key, '') LIKE '%' || v_q || '%')
  ORDER BY c.member_count DESC, c.name
  LIMIT 20;
END;
$$;

DROP FUNCTION IF EXISTS public.preview_club_by_code(TEXT);
CREATE FUNCTION public.preview_club_by_code(p_code TEXT)
RETURNS TABLE (
  club_id UUID,
  name TEXT,
  town TEXT,
  visibility TEXT,
  member_count INTEGER,
  is_member BOOLEAN,
  image_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_uid UUID := auth.uid();
  v_code TEXT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;

  v_code := regexp_replace(upper(coalesce(p_code, '')), '[^A-Z0-9]', '', 'g');

  RETURN QUERY
  SELECT
    c.id,
    c.name,
    c.town,
    c.visibility,
    c.member_count,
    EXISTS (SELECT 1 FROM public.club_members m WHERE m.club_id = c.id AND m.user_id = v_uid),
    c.image_url
  FROM public.clubs c
  WHERE c.join_code = v_code;
END;
$$;

REVOKE ALL ON FUNCTION public.my_clubs() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.search_clubs(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.preview_club_by_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_clubs() TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_clubs(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.preview_club_by_code(TEXT) TO authenticated;

DO $$
BEGIN
  RAISE NOTICE 'Migration 101 complete: club photos (clubs.image_url, club-images bucket, set_club_image)';
END $$;

COMMIT;
