-- VERIFY_user_entitlements.sql: run after 099. Every row should say true.
select 'table exists' as check, to_regclass('public.user_entitlements') is not null as ok
union all
select 'rls enabled', relrowsecurity from pg_class where oid = 'public.user_entitlements'::regclass
union all
select 'only a select policy', count(*) = 1 and bool_and(cmd = 'SELECT')
  from pg_policies where tablename = 'user_entitlements'
union all
select 'unique store tx index', count(*) = 1
  from pg_indexes where tablename = 'user_entitlements' and indexname = 'user_entitlements_store_transaction';
