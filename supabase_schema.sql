-- ============================================================
-- Energy Management System — Complete Supabase Schema
-- Run this in Supabase SQL Editor (once)
-- ============================================================

-- 1. energy_logs — Main reading & bill breakdown table (Bloc flow)
CREATE TABLE IF NOT EXISTS energy_logs (
  id            UUID PRIMARY KEY,
  meter_name    TEXT NOT NULL,
  kwh           DOUBLE PRECISION DEFAULT 0,
  kvah          DOUBLE PRECISION DEFAULT 0,
  rkvarh_lag    DOUBLE PRECISION DEFAULT 0,
  rkvarh_lead   DOUBLE PRECISION DEFAULT 0,
  power_factor  DOUBLE PRECISION DEFAULT 0,
  md_recorded   DOUBLE PRECISION DEFAULT 0,
  contract_demand DOUBLE PRECISION DEFAULT 0,
  estimated_bill DOUBLE PRECISION DEFAULT 0,
  logged_at     TIMESTAMPTZ DEFAULT NOW(),
  is_synced     BOOLEAN DEFAULT FALSE,
  user_id       UUID,
  -- Bill breakdown columns
  energy_charges   DOUBLE PRECISION DEFAULT 0,
  demand_charges   DOUBLE PRECISION DEFAULT 0,
  fac_charges      DOUBLE PRECISION DEFAULT 0,
  wheeling_charges DOUBLE PRECISION DEFAULT 0,
  electricity_duty DOUBLE PRECISION DEFAULT 0,
  taxes            DOUBLE PRECISION DEFAULT 0,
  pf_rebate        DOUBLE PRECISION DEFAULT 0,
  pf_surcharge     DOUBLE PRECISION DEFAULT 0,
  subsidy          DOUBLE PRECISION DEFAULT 0,
  net_bill         DOUBLE PRECISION DEFAULT 0,
  billing_demand   DOUBLE PRECISION DEFAULT 0,
  load_factor      DOUBLE PRECISION DEFAULT 0,
  avg_unit_cost    DOUBLE PRECISION DEFAULT 0,
  multiplying_factor DOUBLE PRECISION DEFAULT 5
);

CREATE INDEX IF NOT EXISTS idx_energy_logs_meter ON energy_logs(meter_name);
CREATE INDEX IF NOT EXISTS idx_energy_logs_logged_at ON energy_logs(logged_at);

-- 2. sites — Site/master locations (EmsProvider flow)
CREATE TABLE IF NOT EXISTS sites (
  id                UUID PRIMARY KEY,
  name              TEXT NOT NULL,
  location          TEXT,
  contract_demand_kva DOUBLE PRECISION,
  user_id           UUID,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- 3. panels — Electrical panels under each site
CREATE TABLE IF NOT EXISTS panels (
  id         UUID PRIMARY KEY,
  site_id    UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  name       TEXT NOT NULL,
  panel_type TEXT,
  user_id    UUID,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_panels_site ON panels(site_id);

-- 4. meters — Energy meters under each panel
CREATE TABLE IF NOT EXISTS meters (
  id           UUID PRIMARY KEY,
  panel_id     UUID NOT NULL REFERENCES panels(id) ON DELETE CASCADE,
  meter_number TEXT NOT NULL,
  meter_type   TEXT,
  ct_ratio     DOUBLE PRECISION,
  pt_ratio     DOUBLE PRECISION,
  contract_demand DOUBLE PRECISION DEFAULT 400,
  user_id      UUID,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meters_panel ON meters(panel_id);

-- 5. readings — Detailed meter readings (EmsProvider flow)
CREATE TABLE IF NOT EXISTS readings (
  id           UUID PRIMARY KEY,
  meter_id     UUID NOT NULL REFERENCES meters(id) ON DELETE CASCADE,
  reading_date DATE NOT NULL,
  kwh_import   DOUBLE PRECISION,
  kwh_export   DOUBLE PRECISION,
  kvah_import  DOUBLE PRECISION,
  kvah_export  DOUBLE PRECISION,
  kw_demand    DOUBLE PRECISION,
  kva_demand   DOUBLE PRECISION,
  voltage_ln_avg DOUBLE PRECISION,
  current_avg  DOUBLE PRECISION,
  power_factor DOUBLE PRECISION,
  frequency    DOUBLE PRECISION,
  thd          DOUBLE PRECISION,
  user_id      UUID,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_readings_meter ON readings(meter_id);
CREATE INDEX IF NOT EXISTS idx_readings_date ON readings(reading_date);

-- 6. contract_demands — Contract demand history per site
CREATE TABLE IF NOT EXISTS contract_demands (
  id                 UUID PRIMARY KEY,
  site_id            UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
  contract_demand_kva DOUBLE PRECISION NOT NULL,
  effective_from     DATE NOT NULL,
  effective_to       DATE,
  user_id            UUID,
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contract_demands_site ON contract_demands(site_id);

-- 7. analysis_results — Analysis findings (rule-based)
CREATE TABLE IF NOT EXISTS analysis_results (
  id             UUID PRIMARY KEY,
  site_id        UUID REFERENCES sites(id) ON DELETE CASCADE,
  panel_id       UUID REFERENCES panels(id) ON DELETE CASCADE,
  meter_id       UUID REFERENCES meters(id) ON DELETE CASCADE,
  reading_id     UUID REFERENCES readings(id) ON DELETE CASCADE,
  type           TEXT NOT NULL,
  severity       TEXT NOT NULL,
  title          TEXT NOT NULL,
  description    TEXT,
  recommendation TEXT,
  metrics        JSONB,
  user_id        UUID,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_analysis_site ON analysis_results(site_id);
CREATE INDEX IF NOT EXISTS idx_analysis_severity ON analysis_results(severity);

-- Enable Row Level Security
ALTER TABLE energy_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE panels ENABLE ROW LEVEL SECURITY;
ALTER TABLE meters ENABLE ROW LEVEL SECURITY;
ALTER TABLE readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_demands ENABLE ROW LEVEL SECURITY;
ALTER TABLE analysis_results ENABLE ROW LEVEL SECURITY;

-- Default user_id to the authenticated user for all rows
ALTER TABLE energy_logs ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE sites ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE panels ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE meters ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE readings ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE contract_demands ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE analysis_results ALTER COLUMN user_id SET DEFAULT auth.uid();

-- RLS: Users can only see their own data (full CRUD)
CREATE POLICY "Users can view own energy_logs"
  ON energy_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own energy_logs"
  ON energy_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own energy_logs"
  ON energy_logs FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own energy_logs"
  ON energy_logs FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own sites"
  ON sites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own sites"
  ON sites FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own sites"
  ON sites FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own sites"
  ON sites FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own panels"
  ON panels FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own panels"
  ON panels FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own panels"
  ON panels FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own panels"
  ON panels FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own meters"
  ON meters FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own meters"
  ON meters FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own meters"
  ON meters FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own meters"
  ON meters FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own readings"
  ON readings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own readings"
  ON readings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own readings"
  ON readings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own readings"
  ON readings FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own contract_demands"
  ON contract_demands FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own contract_demands"
  ON contract_demands FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own contract_demands"
  ON contract_demands FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own contract_demands"
  ON contract_demands FOR DELETE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can view own analysis_results"
  ON analysis_results FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own analysis_results"
  ON analysis_results FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own analysis_results"
  ON analysis_results FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own analysis_results"
  ON analysis_results FOR DELETE
  USING (auth.uid() = user_id);
