-- ============================================================
-- Energy Management System — Cloud-Only Data Migration
-- Run this in Supabase SQL Editor (once).
--
-- Adds the tables that replace local sembast storage:
--   user_meters    — meters managed in Settings > Meter Management
--   user_settings  — per-user tariff settings (JSON blob)
--   bill_reconcile — actual bill amounts per month (reports)
-- ============================================================

-- 1. user_meters — Meters for the Bloc (manual reading) flow.
--    Named user_meters to avoid colliding with the EmsProvider
--    `meters` table (which requires a panel_id FK).
CREATE TABLE IF NOT EXISTS user_meters (
  id                 UUID PRIMARY KEY,
  name               TEXT NOT NULL,
  location           TEXT,
  contract_demand_kw DOUBLE PRECISION DEFAULT 400,
  is_active          BOOLEAN DEFAULT TRUE,
  ct_ratio           DOUBLE PRECISION DEFAULT 1,
  pt_ratio           DOUBLE PRECISION DEFAULT 1,
  site               TEXT DEFAULT 'Main Site',
  user_id            UUID DEFAULT auth.uid(),
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  updated_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_meters_user ON user_meters(user_id);
CREATE INDEX IF NOT EXISTS idx_user_meters_name ON user_meters(name);

-- 2. user_settings — per-user tariff configuration stored as JSONB.
CREATE TABLE IF NOT EXISTS user_settings (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  data       JSONB NOT NULL DEFAULT '{}'::JSONB,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. bill_reconcile — actual bill amount per month key (e.g. "2026-07").
CREATE TABLE IF NOT EXISTS bill_reconcile (
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month_key  TEXT NOT NULL,
  amount     DOUBLE PRECISION NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, month_key)
);

-- Enable Row Level Security
ALTER TABLE user_meters ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_reconcile ENABLE ROW LEVEL SECURITY;

-- user_meters: users can manage only their own meters
CREATE POLICY "Users can view own user_meters"
  ON user_meters FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own user_meters"
  ON user_meters FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own user_meters"
  ON user_meters FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own user_meters"
  ON user_meters FOR DELETE
  USING (auth.uid() = user_id);

-- user_settings: users can manage only their own settings row
CREATE POLICY "Users can view own settings"
  ON user_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
  ON user_settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
  ON user_settings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own settings"
  ON user_settings FOR DELETE
  USING (auth.uid() = user_id);

-- bill_reconcile: users can manage only their own rows
CREATE POLICY "Users can view own bills"
  ON bill_reconcile FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bills"
  ON bill_reconcile FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bills"
  ON bill_reconcile FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own bills"
  ON bill_reconcile FOR DELETE
  USING (auth.uid() = user_id);
