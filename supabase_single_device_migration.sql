-- ============================================================
-- Single-device login — user_sessions table
-- One account can be active on only ONE device at a time.
-- Run this in Supabase SQL Editor (once) after updating the app.
-- ============================================================

CREATE TABLE IF NOT EXISTS user_sessions (
  user_id      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  device_name  TEXT,
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own session" ON user_sessions;
DROP POLICY IF EXISTS "Users can insert own session" ON user_sessions;
DROP POLICY IF EXISTS "Users can update own session" ON user_sessions;
DROP POLICY IF EXISTS "Users can delete own session" ON user_sessions;

-- Users can only read/write their OWN session row (auth.uid() scoping).
CREATE POLICY "Users can view own session" ON user_sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own session" ON user_sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own session" ON user_sessions
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own session" ON user_sessions
  FOR DELETE USING (auth.uid() = user_id);
