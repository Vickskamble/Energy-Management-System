-- alert_log: stores every email alert sent so the daily digest can batch
-- unsent warnings and track delivery status.
CREATE TABLE IF NOT EXISTS alert_log (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  alert_type TEXT NOT NULL,          -- 'pf' | 'md' | 'bill_spike' | 'consumption' | 'reminder'
  severity   TEXT NOT NULL DEFAULT 'warning', -- 'critical' | 'warning' | 'info'
  site       TEXT,
  meter      TEXT,
  title      TEXT NOT NULL,
  message    TEXT NOT NULL,
  sent_at    TIMESTAMPTZ DEFAULT NOW(),
  emailed    BOOLEAN DEFAULT FALSE,
  email_sent_at TIMESTAMPTZ
);

ALTER TABLE alert_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own alerts"
  ON alert_log FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "System inserts alerts"
  ON alert_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System updates alerts"
  ON alert_log FOR UPDATE
  USING (auth.uid() = user_id);

-- Index for daily digest: find unemailed warnings per user.
CREATE INDEX IF NOT EXISTS idx_alert_log_digest
  ON alert_log (user_id, emailed, severity)
  WHERE emailed = FALSE AND severity = 'warning';
