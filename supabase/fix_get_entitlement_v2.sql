create or replace function public.get_entitlement()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := nullif(auth.jwt() ->> 'email', '');
  v_profile public.profiles%rowtype;
  v_has_profile boolean := false;
  v_sub public.subscriptions%rowtype;
  v_has_sub boolean := false;
  v_trial_end timestamptz;
  v_credit_end timestamptz;
  v_grace_end timestamptz;
  v_now timestamptz := now();
  v_sub_active boolean := false;
  v_dp_allowed int := 0;
  v_read_only boolean := false;
  v_trial_active boolean := false;
  v_credit_active boolean := false;
  v_in_grace boolean := false;
  v_extra_dp int := 0;
  v_plan_name text := 'growth';
  v_base_dp int := 5;
begin
  if v_email = 'demo@powerems.com' then
    return jsonb_build_object(
      'is_demo', true,
      'trial_end', null, 'trial_active', true,
      'subscription_status', 'active', 'sub_active', true,
      'free_months_credit', 0, 'credit_end', null, 'credit_active', false,
      'data_points_allowed', 999, 'extra_data_points', 0,
      'plan_name', 'pro', 'plan_term', 'yearly',
      'read_only', false, 'grace_end', null, 'in_grace', false,
      'referral_code', coalesce((select referral_code from public.profiles where user_id = v_user_id), ''),
      'current_period_end', null,
      'meters_allowed', 999, 'extra_meters', 0
    );
  end if;

  begin
    select * into v_profile from public.profiles where user_id = v_user_id;
    v_has_profile := true;
  exception when no_data_found then
    v_has_profile := false;
  end;

  begin
    select * into v_sub from public.subscriptions where user_id = v_user_id;
    v_has_sub := true;
  exception when no_data_found then
    v_has_sub := false;
  end;

  if v_has_profile then
    v_trial_end := coalesce(v_profile.trial_started_at, v_now) + interval '30 days';
  else
    v_trial_end := v_now + interval '30 days';
  end if;
  v_trial_active := v_now < v_trial_end;

  if v_has_profile then
    v_credit_end := v_trial_end + (coalesce(v_profile.free_months_credit, 0) * interval '1 month');
  else
    v_credit_end := v_trial_end;
  end if;
  v_credit_active := v_now < v_credit_end;

  if v_has_sub then
    v_sub_active := coalesce(v_sub.status, 'none') in ('active', 'authenticated');
    v_extra_dp := coalesce(v_sub.extra_data_points, coalesce(v_sub.extra_meters, 0));
    v_plan_name := coalesce(v_sub.plan_name, 'growth');
  end if;

  v_base_dp := case v_plan_name
    when 'starter' then 2
    when 'pro' then 10
    else 5
  end;

  if v_sub_active then
    v_dp_allowed := v_base_dp + v_extra_dp;
  elsif v_trial_active then
    v_dp_allowed := v_base_dp + v_extra_dp;
  end if;

  if v_trial_active and (not v_has_sub or v_sub.plan_name is null) then
    v_dp_allowed := 5;
    v_plan_name := 'growth';
  end if;

  v_read_only := not v_sub_active and not v_trial_active and not v_credit_active;

  if v_has_sub and v_sub.current_period_end is not null then
    v_grace_end := v_sub.current_period_end + interval '7 days';
    v_in_grace := (v_now > v_sub.current_period_end)
      and (v_now < v_grace_end) and not v_sub_active;
  end if;

  return jsonb_build_object(
    'is_demo', false,
    'trial_end', v_trial_end, 'trial_active', v_trial_active,
    'subscription_status', coalesce(v_sub.status, 'none'), 'sub_active', v_sub_active,
      'free_months_credit', case when v_has_profile then coalesce(v_profile.free_months_credit, 0) else 0 end,
    'credit_end', v_credit_end, 'credit_active', v_credit_active,
    'data_points_allowed', v_dp_allowed, 'extra_data_points', v_extra_dp,
    'plan_name', v_plan_name, 'plan_term', coalesce(v_sub.plan_term, 'monthly'),
    'read_only', v_read_only, 'grace_end', v_grace_end, 'in_grace', v_in_grace,
      'referral_code', case when v_has_profile then coalesce(v_profile.referral_code, '') else '' end,
    'current_period_end', v_sub.current_period_end,
    'meters_allowed', v_dp_allowed, 'extra_meters', v_extra_dp
  );
end;
$$;

revoke execute on function public.get_entitlement() from public;
grant execute on function public.get_entitlement() to authenticated;
