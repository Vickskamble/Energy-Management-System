-- Owner access key: entering NEW20 grants 6 months of full access.
-- Adds subscriptions.owner_access_until + redeem_owner_key RPC, and makes
-- get_entitlement treat active owner access as full access (999 meters).
-- Run via `supabase db push` (needs DB password) or paste into SQL Editor.

alter table public.subscriptions add column if not exists owner_access_until timestamptz;

-- ============================================================
-- RPC: redeem the owner key (once; grants 6 months full access)
-- ============================================================
create or replace function public.redeem_owner_key(p_code text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_now timestamptz := now();
  v_until timestamptz;
begin
  if upper(trim(p_code)) <> 'NEW20' then
    return jsonb_build_object('ok', false, 'error', 'INVALID_KEY');
  end if;

  insert into public.subscriptions (user_id, status, extra_meters, owner_access_until, updated_at)
  values (v_user_id, 'none', 0, v_now + interval '6 months', v_now)
  on conflict (user_id) do update set
    owner_access_until = case
      when public.subscriptions.owner_access_until is null
        or public.subscriptions.owner_access_until <= v_now
        then v_now + interval '6 months'
      else public.subscriptions.owner_access_until
    end,
    updated_at = v_now;

  select owner_access_until into v_until
    from public.subscriptions where user_id = v_user_id;
  return jsonb_build_object('ok', true, 'until', v_until);
end;
$$;

revoke execute on function public.redeem_owner_key(text) from public;
grant execute on function public.redeem_owner_key(text) to authenticated;

-- ============================================================
-- Entitlement: owner access = full access (never read-only, 999 meters)
-- ============================================================
create or replace function public.get_entitlement()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := nullif(auth.jwt() ->> 'email', '');
  v_profile public.profiles%rowtype;
  v_sub public.subscriptions%rowtype;
  v_trial_end timestamptz;
  v_credit_end timestamptz;
  v_now timestamptz := now();
  v_sub_active boolean := false;
  v_owner_active boolean := false;
  v_meters_allowed int := 1;
  v_read_only boolean := false;
  v_trial_active boolean := false;
  v_credit_active boolean := false;
  v_extra_meters int := 0;
begin
  -- Demo account is always fully entitled (matches session-guard exemption).
  if v_email = 'demo@powerems.com' then
    return jsonb_build_object(
      'is_demo', true,
      'trial_end', null, 'trial_active', true,
      'subscription_status', 'active', 'sub_active', true,
      'free_months_credit', 0, 'credit_end', null, 'credit_active', false,
      'meters_allowed', 999, 'extra_meters', 0,
      'read_only', false,
      'referral_code', coalesce((select referral_code from public.profiles where user_id = v_user_id), '')
    );
  end if;

  select * into v_profile from public.profiles where user_id = v_user_id;
  select * into v_sub from public.subscriptions where user_id = v_user_id;

  v_trial_end := coalesce(v_profile.trial_started_at, v_now) + interval '60 days';
  v_trial_active := v_now < v_trial_end;
  v_credit_end := v_trial_end + (coalesce(v_profile.free_months_credit, 0) * interval '1 month');
  v_credit_active := v_now < v_credit_end;

  v_owner_active := v_sub.owner_access_until is not null and v_now < v_sub.owner_access_until;
  v_sub_active := coalesce(v_sub.status, 'none') in ('active', 'authenticated') or v_owner_active;
  v_extra_meters := coalesce(v_sub.extra_meters, 0);
  if v_owner_active then
    v_meters_allowed := 999;
  elsif v_sub_active then
    v_meters_allowed := 1 + v_extra_meters;
  end if;

  v_read_only := not v_sub_active and not v_trial_active and not v_credit_active;

  return jsonb_build_object(
    'is_demo', false,
    'trial_end', v_trial_end, 'trial_active', v_trial_active,
    'subscription_status', coalesce(v_sub.status, 'none'), 'sub_active', v_sub_active,
    'free_months_credit', coalesce(v_profile.free_months_credit, 0),
    'credit_end', v_credit_end, 'credit_active', v_credit_active,
    'meters_allowed', v_meters_allowed, 'extra_meters', v_extra_meters,
    'read_only', v_read_only,
    'referral_code', coalesce(v_profile.referral_code, ''),
    'current_period_end', v_sub.current_period_end,
    'owner_access_until', v_sub.owner_access_until
  );
end;
$$;

revoke execute on function public.get_entitlement() from public;
grant execute on function public.get_entitlement() to authenticated;