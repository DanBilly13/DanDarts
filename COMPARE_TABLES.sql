-- Compare the two tables to find what's different

-- Check column definitions
SELECT 
    'match_throws' as table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'match_throws'
UNION ALL
SELECT 
    'match_throws_test' as table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'match_throws_test'
ORDER BY table_name, column_name;

-- Check indexes
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('match_throws', 'match_throws_test')
ORDER BY tablename, indexname;

-- Check constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    conrelid::regclass as table_name
FROM pg_constraint
WHERE conrelid IN ('match_throws'::regclass, 'match_throws_test'::regclass)
ORDER BY table_name, constraint_name;
