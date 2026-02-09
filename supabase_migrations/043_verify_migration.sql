-- Quick verification query to check migration success

-- Count total participants
SELECT COUNT(*) as total_participants FROM public.match_participants;

-- Count by type
SELECT 
    is_guest,
    COUNT(*) as count
FROM public.match_participants
GROUP BY is_guest;

-- Sample a few rows
SELECT 
    match_id,
    user_id,
    is_guest,
    display_name
FROM public.match_participants
LIMIT 10;
