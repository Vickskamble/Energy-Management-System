-- 001_add_actual_readings.sql
-- Adds ACTUAL (cumulative) meter readings to energy_logs.
--
-- The system previously stored only per-day CONSUMED values (kwh/kvah =
-- current - previous). Clients need to see the actual meter reading on
-- Analysis/Reports, so every entry now also stores the raw meter reading
-- it was recorded against.
--
--   current_kwh  = meter's kWh reading at the time of this entry
--   current_kvah = meter's kVAh reading at the time of this entry
--
-- Consumption (kwh/kvah) keeps its meaning: current - previous. All existing
-- calculations (bills, charts, reports) are unchanged.
--
-- Run this once in Supabase Dashboard -> SQL Editor.

ALTER TABLE public.energy_logs
  ADD COLUMN IF NOT EXISTS current_kwh DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS current_kvah DOUBLE PRECISION;

-- Backfill: old rows have no actual reading stored. Reconstruct it as the
-- running sum of consumed values per meter, in date order. This equals the
-- meter's cumulative value whenever the per-day chain is consistent (which
-- is the normal case). New entries store the true reading going forward.
UPDATE public.energy_logs e
SET current_kwh = t.cum_kwh,
    current_kvah = t.cum_kvah
FROM (
  SELECT
    id,
    SUM(kwh)  OVER (PARTITION BY meter_name ORDER BY logged_at, id) AS cum_kwh,
    SUM(kvah) OVER (PARTITION BY meter_name ORDER BY logged_at, id) AS cum_kvah
  FROM public.energy_logs
) t
WHERE e.id = t.id
  AND e.current_kwh IS NULL
  AND e.current_kvah IS NULL;

-- Sanity check: counts of rows still missing actual readings.
SELECT
  COUNT(*) FILTER (WHERE current_kwh IS NULL) AS missing_kwh,
  COUNT(*) FILTER (WHERE current_kvah IS NULL) AS missing_kvah,
  COUNT(*) AS total
FROM public.energy_logs;
