-- ============================================================
-- Data governance: Delete Account + Reset All Data (DPDP Act 2023)
-- Run via `supabase db push` (needs DB password) or paste into SQL Editor.
--
-- Two security-definer RPCs:
--   delete_all_user_data()  -> wipes ALL business rows for the signed-in
--                              user, across every table with a user_id
--                              column (app data + sessions + legacy tables).
--                              Keeps the account (email, auth, subscription).
--   delete_account()        -> wipes the same rows AND deletes the auth
--                              user record (full erasure per DPDP s12/13).
-- Both accept calls only from authenticated users (auth.uid()).
-- ============================================================

-- ------------------------------------------------------------
-- 1. delete_all_user_data()
-- ------------------------------------------------------------
create or replace function public.delete_all_user_data()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r record;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Every public table carrying a user_id column (dynamic, so future
  -- tables are covered automatically). Subscriptions/profiles/billing
  -- are intentionally excluded: the account and paid entitlement stay.
  for r in
    select t.table_name
    from information_schema.tables t
    join information_schema.columns c
      on c.table_name = t.table_name and c.table_schema = t.table_schema
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name = 'user_id'
  loop
    execute format('delete from public.%I where user_id = $1', r.table_name)
      using v_uid;
  end loop;

  -- Referral graph references the user too.
  delete from public.referrals where referred_by = v_uid;
end;
$$;

grant execute on function public.delete_all_user_data() to authenticated;
revoke execute on function public.delete_all_user_data() from anon;

-- ------------------------------------------------------------
-- 2. delete_account()  (full erasure: data + auth + profile)
-- ------------------------------------------------------------
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  r record;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Same full wipe as delete_all_user_data()...
  for r in
    select t.table_name
    from information_schema.tables t
    join information_schema.columns c
      on c.table_name = t.table_name and c.table_schema = t.table_schema
    where t.table_schema = 'public'
      and t.table_type = 'BASE TABLE'
      and c.column_name = 'user_id'
  loop
    execute format('delete from public.%I where user_id = $1', r.table_name)
      using v_uid;
  end loop;
  delete from public.referrals where referred_by = v_uid;

  -- ...then the account itself. profiles cascades via FK
  -- (user_id references auth.users(id) on delete cascade); rows in
  -- auth.audit_log_entries / auth.identities are handled by Supabase
  -- when the user record is removed.
  delete from auth.users where id = v_uid;
end;
$$;

grant execute on function public.delete_account() to authenticated;
revoke execute on function public.delete_account() from anon;