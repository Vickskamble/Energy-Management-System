-- G12: Server-side session revocation — helper for the session-gate Edge Function.
-- Run via `supabase db push` (needs DB password) or paste into SQL Editor.

-- Hard server-side check helper: true when this device token is the CURRENT owner.
create or replace function public.is_session_owner(p_token text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_sessions
    where user_id = auth.uid()
      and device_token = p_token
      and last_seen_at > now() - interval '3 minutes'
  );
$$;

-- Grant to authenticated role (Edge Function calls it as the signed-in user).
revoke execute on function public.is_session_owner(text) from public;
grant execute on function public.is_session_owner(text) to authenticated;
