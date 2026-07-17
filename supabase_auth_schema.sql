-- Add user_id to energy_logs table for auth-based RLS
ALTER TABLE public.energy_logs
  ADD COLUMN user_id UUID REFERENCES auth.users(id);

-- Enable RLS
ALTER TABLE public.energy_logs ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies first
DROP POLICY IF EXISTS "Authenticated users can read energy_logs" ON public.energy_logs;
DROP POLICY IF EXISTS "Authenticated users can insert energy_logs" ON public.energy_logs;
DROP POLICY IF EXISTS "Authenticated users can update energy_logs" ON public.energy_logs;
DROP POLICY IF EXISTS "Authenticated users can delete energy_logs" ON public.energy_logs;

-- User-scoped policies
CREATE POLICY "Users manage their own energy_logs"
  ON public.energy_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Index for user-scoped queries
CREATE INDEX IF NOT EXISTS idx_energy_logs_user_date
  ON public.energy_logs (user_id, logged_at DESC);
