-- Verify existing constraints on match_players table
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'public.match_players'::regclass
ORDER BY conname;
