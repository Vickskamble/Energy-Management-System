-- Multi-MD (T1-T4) feature: store individual MD phase values as JSONB.
-- md_recorded continues to hold the MAX of T1-T4 for backward compatibility.
-- md_values is nullable; NULL = legacy/single-MD entries.

ALTER TABLE energy_logs
  ADD COLUMN IF NOT EXISTS md_values JSONB DEFAULT NULL;
