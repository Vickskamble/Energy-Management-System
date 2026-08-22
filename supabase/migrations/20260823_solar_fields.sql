-- Add solar/net-metering fields to energy_logs
-- export_kwh/export_kvah: consumed export (fed to grid), raw diff before MF
-- generation_kwh: total solar panel generation, may exceed export (self-consumed portion)

ALTER TABLE energy_logs
  ADD COLUMN IF NOT EXISTS export_kwh     DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS export_kvah    DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS generation_kwh DOUBLE PRECISION;

COMMENT ON COLUMN energy_logs.export_kwh     IS 'Export (solar) kWh consumed — raw meter diff before MF. NULL = non-solar.';
COMMENT ON COLUMN energy_logs.export_kvah    IS 'Export (solar) kVAh consumed — raw meter diff before MF.';
COMMENT ON COLUMN energy_logs.generation_kwh IS 'Total solar generation kWh — raw meter diff before MF. May exceed export_kwh (self-consumed).';
