alter table public.subscriptions
  add column if not exists payment_link_id text,
  add column if not exists paid_at timestamptz;