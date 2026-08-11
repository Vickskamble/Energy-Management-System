-- SaaS subscription engine: plans, subscriptions, referrals, entitlement.
-- Run via `supabase db push` (needs DB password) or paste into SQL Editor.
-- Pricing (defaults; Razorpay source of truth once first subscription created):
--   base plan: INR 799/month (includes 1 meter)
--   extra meter addon: INR 99/month each
--   free tier: 1 meter + 60 day trial from signup
--   referral: referrer gets +1 month free per referred client's first payment

-- ============================================================
-- 1. profiles (created automatically on signup via trigger)
-- ============================================================
create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  referral_code text not null,
  referred_by uuid references public.profiles(user_id) on delete set null,
  trial_started_at timestamptz not null default now(),
  free_months_credit integer not null default 0,
  created_at timestamptz not null default now()
);

create unique index if not exists profiles_referral_code_key on public.profiles (referral_code);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = user_id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = user_id);

-- Auto-create profile with a unique referral code on signup.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_tries int := 0;
begin
  if exists (select 1 from public.profiles where user_id = new.id) then
    return new;
  end if;
  loop
    v_code := upper(substr(md5(random()::text || new.id::text), 1, 8));
    v_code := regexp_replace(v_code, '[^A-Z0-9]', 'A', 'g');
    exit when not exists (select 1 from public.profiles where referral_code = v_code);
    v_tries := v_tries + 1;
    if v_tries > 10 then
      v_code := 'EMS' || floor(random() * 90000 + 10000)::int;
      exit;
    end if;
  end loop;
  insert into public.profiles (user_id, referral_code)
  values (new.id, v_code);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 2. subscriptions (1 row per paying user; webhook-maintained)
-- ============================================================
create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  razorpay_subscription_id text,
  status text not null default 'none', -- none|created|authenticated|active|halted|completed|cancelled|paused|resumed|expired
  current_period_start timestamptz,
  current_period_end timestamptz,
  extra_meters integer not null default 0,
  base_amount integer not null default 799,
  meter_rate integer not null default 99,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.subscriptions enable row level security;

drop policy if exists "subscriptions_select_own" on public.subscriptions;
create policy "subscriptions_select_own" on public.subscriptions
  for select using (auth.uid() = user_id);

-- ============================================================
-- 3. referrals (each referred user appears once)
-- ============================================================
create table if not exists public.referrals (
  id uuid primary key default gen_random_uuid(),
  referrer_user_id uuid not null references public.profiles(user_id) on delete cascade,
  referred_user_id uuid not null references public.profiles(user_id) on delete cascade,
  referral_code text not null,
  status text not null default 'pending', -- pending|rewarded
  reward_months integer not null default 1,
  created_at timestamptz not null default now(),
  unique (referred_user_id)
);

alter table public.referrals enable row level security;

drop policy if exists "referrals_select_own" on public.referrals;
create policy "referrals_select_own" on public.referrals
  for select using (auth.uid() = referrer_user_id or auth.uid() = referred_user_id);

-- ============================================================
-- 4. billing_events (webhook audit log; service-role only)
-- ============================================================
create table if not exists public.billing_events (
  id bigint generated always as identity primary key,
  razorpay_event_id text unique,
  event_type text not null,
  user_id uuid references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.billing_events enable row level security;

-- ============================================================
-- 5. RPC: claim a referral code at signup (once, not self)
-- ============================================================
create or replace function public.claim_referral(p_code text)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_referrer uuid;
begin
  select user_id into v_referrer
    from public.profiles
    where upper(referral_code) = upper(p_code);
  if v_referrer is null or v_referrer = auth.uid() then
    return false;
  end if;
  if exists (select 1 from public.referrals where referred_user_id = auth.uid()) then
    return false;
  end if;
  update public.profiles set referred_by = v_referrer where user_id = auth.uid();
  insert into public.referrals (referrer_user_id, referred_user_id, referral_code)
  values (v_referrer, auth.uid(), upper(p_code))
  on conflict (referred_user_id) do nothing;
  return true;
end;
$$;

revoke execute on function public.claim_referral(text) from public;
grant execute on function public.claim_referral(text) to authenticated;

-- ============================================================
-- 6. RPC: entitlement (single source of truth, client-side checks)
--    Trial 60d | referral credits extend access | paid adds meters
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
  v_meters_allowed int := 1;
  v_read_only boolean := false;
  v_trial_active boolean := false;
  v_credit_active boolean := false;
  v_extra_meters int := 0;
begin
  -- Demo account is always fully entitled (matches session-guard exemption).
  if v_email = 'demo@example.com' then
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

  v_sub_active := coalesce(v_sub.status, 'none') in ('active', 'authenticated');
  v_extra_meters := coalesce(v_sub.extra_meters, 0);
  if v_sub_active then
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
    'current_period_end', v_sub.current_period_end
  );
end;
$$;

revoke execute on function public.get_entitlement() from public;
grant execute on function public.get_entitlement() to authenticated;

-- ============================================================
-- 7. RPC: apply referral reward (+1 month to referrer) — called by webhook
-- ============================================================
create or replace function public.reward_referral(p_referred_user_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_ref public.referrals%rowtype;
begin
  select * into v_ref from public.referrals
    where referred_user_id = p_referred_user_id and status = 'pending';
  if v_ref is null then
    return false;
  end if;
  update public.profiles
    set free_months_credit = free_months_credit + v_ref.reward_months
    where user_id = v_ref.referrer_user_id;
  update public.referrals set status = 'rewarded'
    where id = v_ref.id;
  return true;
end;
$$;

revoke execute on function public.reward_referral(uuid) from public;
grant execute on function public.reward_referral(uuid) to service_role;

-- ============================================================
-- 8. Server-side enforcement (hard gates — clients can't bypass)
-- ============================================================

-- Block creating meters beyond the plan allowance (incl. trial limit).
create or replace function public.enforce_meter_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_ent jsonb;
  v_allowed int;
  v_count int;
begin
  v_ent := public.get_entitlement();
  if (v_ent ->> 'is_demo') = 'true' then
    return new;
  end if;
  v_allowed := (v_ent ->> 'meters_allowed')::int;
  select count(*) into v_count from public.user_meters
    where user_id = auth.uid();
  if v_count >= v_allowed then
    raise exception 'METER_LIMIT_REACHED (allowed: %) — upgrade your plan to add more meters', v_allowed;
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_meter_limit_insert on public.user_meters;
create trigger enforce_meter_limit_insert
  before insert on public.user_meters
  for each row execute function public.enforce_meter_limit();

-- Block new readings when the account is in read-only (expired) state.
create or replace function public.enforce_read_only()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_ent jsonb;
begin
  v_ent := public.get_entitlement();
  if (v_ent ->> 'read_only') = 'true' then
    raise exception 'ACCOUNT_READ_ONLY — your trial/subscription has expired. Renew to keep recording readings.';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_read_only_insert on public.energy_logs;
create trigger enforce_read_only_insert
  before insert on public.energy_logs
  for each row execute function public.enforce_read_only();
