-- 099_user_entitlements.sql
-- DartFreak Full: one row per account that has unlocked the full app.
-- Written only by edge functions (service role) or by hand (source 'manual', e.g. Android testers).
-- Each signed-in user can read their own row, so both iOS and Android can show the unlock.
-- Match data is unaffected: free users' matches are saved exactly as before.

create table if not exists public.user_entitlements (
    user_id uuid primary key references public.users(id) on delete cascade,
    source text not null check (source in ('apple', 'google', 'manual')),
    store_transaction_id text,
    granted_at timestamptz not null default now()
);

-- One store purchase can only unlock one DartFreak account.
create unique index if not exists user_entitlements_store_transaction
    on public.user_entitlements (source, store_transaction_id)
    where store_transaction_id is not null;

alter table public.user_entitlements enable row level security;

drop policy if exists "Users read own entitlement" on public.user_entitlements;
create policy "Users read own entitlement"
    on public.user_entitlements
    for select
    to authenticated
    using (auth.uid() = user_id);

-- No insert/update/delete policies: only the service role (edge functions) writes.
