-- Migration: pricing v2 + grace period (supersedes 20260812 defaults).
-- Run via `supabase db push` or paste into the Supabase SQL Editor.
--
-- Pricing (now the source of truth for new subscriptions; Razorpay plan is
-- auto-created by the checkout Edge Function at the matching amount):
--   base plan:  INR 2500/month (includes 5 meters)
--   extra meter addon: INR 149/month each (beyond the included 5)
--   free tier:  5 meters + 60 day trial from signup
--   grace:      7 days read-only after a paid plan expires before full lockout

-- 1. Update column defaults so new subscription rows start correct.
alter table public.subscriptions alter column base_amount set default 2500;
alter table public.subscriptions alter column meter_rate set default 149;

-- Monthly / yearly plan selection.
alter table public.subscriptions add column if not exists plan_term text not null default 'monthly';

-- 2. Recreate get_entitlement() with 5 included meters + grace window.
create or replace function public.get_entitlement()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := nullif(auth.jwt() ->> 'email', '');
  v_profile public.profiles%rowtype;
  v_sub public.subscriptions%rowtype;
  v_trial_end timestamptz;
  v_credit_end timestamptz;
  v_grace_end timestamptz;
  v_now timestamptz := now();
  v_sub_active boolean := false;
  v_meters_allowed int := 5;
  v_read_only boolean := false;
  v_trial_active boolean := false;
  v_credit_active boolean := false;
  v_in_grace boolean := false;
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
      'read_only', false, 'grace_end', null, 'in_grace', false,
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
    v_meters_allowed := 5 + v_extra_meters;
  end if;

  v_read_only := not v_sub_active and not v_trial_active and not v_credit_active;

  -- Grace window: paid plan just expired, renewal still possible, data intact.
  if v_sub.current_period_end is not null then
    v_grace_end := v_sub.current_period_end + interval '7 days';
    v_in_grace := (v_now > v_sub.current_period_end)
      and (v_now < v_grace_end) and not v_sub_active;
  end if;

  return jsonb_build_object(
    'is_demo', false,
    'trial_end', v_trial_end, 'trial_active', v_trial_active,
    'subscription_status', coalesce(v_sub.status, 'none'), 'sub_active', v_sub_active,
    'free_months_credit', coalesce(v_profile.free_months_credit, 0),
    'credit_end', v_credit_end, 'credit_active', v_credit_active,
    'meters_allowed', v_meters_allowed, 'extra_meters', v_extra_meters,
    'read_only', v_read_only, 'grace_end', v_grace_end, 'in_grace', v_in_grace,
    'plan_term', coalesce(v_sub.plan_term, 'monthly'),
    'referral_code', coalesce(v_profile.referral_code, ''),
    'current_period_end', v_sub.current_period_end
  );
end;
$$;

revoke execute on function public.get_entitlement() from public;
grant execute on function public.get_entitlement() to authenticated;
