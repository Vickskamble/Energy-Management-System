-- EMS - Supabase Schema
-- Run this in your Supabase SQL Editor to create the cloud tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Sites table
CREATE TABLE sites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  name TEXT NOT NULL,
  location TEXT,
  contract_demand_kva REAL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own sites"
  ON sites FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Panels table
CREATE TABLE panels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  panel_type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE panels ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own panels"
  ON panels FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Meters table
CREATE TABLE meters (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  panel_id UUID REFERENCES panels(id) ON DELETE CASCADE NOT NULL,
  meter_number TEXT NOT NULL,
  meter_type TEXT,
  ct_ratio REAL,
  pt_ratio REAL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE meters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own meters"
  ON meters FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Readings table
CREATE TABLE readings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  meter_id UUID REFERENCES meters(id) ON DELETE CASCADE NOT NULL,
  reading_date DATE NOT NULL,
  kwh_import REAL,
  kwh_export REAL,
  kvah_import REAL,
  kvah_export REAL,
  kw_demand REAL,
  kva_demand REAL,
  voltage_ln_avg REAL,
  current_avg REAL,
  power_factor REAL,
  frequency REAL,
  thd REAL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own readings"
  ON readings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_readings_meter_date ON readings(meter_id, reading_date);
CREATE INDEX idx_readings_user_date ON readings(user_id, reading_date);

-- Contract Demands table
CREATE TABLE contract_demands (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE NOT NULL,
  contract_demand_kva REAL NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE contract_demands ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own contract demands"
  ON contract_demands FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Analysis Results table
CREATE TABLE analysis_results (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  panel_id UUID REFERENCES panels(id) ON DELETE CASCADE,
  meter_id UUID REFERENCES meters(id) ON DELETE CASCADE,
  reading_id UUID REFERENCES readings(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  severity TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  recommendation TEXT,
  metrics JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE analysis_results ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own analysis"
  ON analysis_results FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_analysis_user_site ON analysis_results(user_id, site_id);
CREATE INDEX idx_analysis_severity ON analysis_results(severity);
