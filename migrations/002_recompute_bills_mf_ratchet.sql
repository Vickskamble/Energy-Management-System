-- 002_recompute_bills_mf_ratchet.sql
-- Recomputes the stored bill figures of every energy_log row using the
-- ACTUAL demand (raw MD × multiplying factor) instead of the raw MD.
--
-- New logic (matches lib/core):
--   billing_demand = max(md_recorded × multiplying_factor, contract_demand × 0.75)
--   total_units    = kwh × multiplying_factor
--   pf             = stored power_factor (already saved per row)
--   energy_charges = total_units × 8.44
--   demand_charges = billing_demand × 650
--   fac_charges    = total_units × 0.30
--   wheeling_charges = total_units × 0.81
--   electricity_duty  = total_units × 0.275
--   taxes              = total_units × 0.279
--   pf_rebate    = pf >= 0.95 ? (energy + demand) × 1%  : 0
--   pf_surcharge = pf < 0.90 ? (energy + demand) × 5%   : 0
--   net_bill     = energy + demand + fac + wheeling + duty + taxes
--                  + pf_surcharge - pf_rebate - subsidy
--   estimated_bill = total_units × 8.44 (energy only, as stored at create)
--
-- NOTE: the monthly ratchet (highest of preceding 11 months) is applied by
-- the app's live BillCalculator on the dashboard/reports — it is a monthly
-- concept and is NOT stored per row. This migration only fixes the per-entry
-- stored values so reports/PDF/CSV match the app's per-entry calculation.
--
-- If tariff rates were changed in app Settings, adjust the constants below
-- to the client's configured values before running.
--
-- Run this once in Supabase Dashboard -> SQL Editor.

UPDATE public.energy_logs
SET
  billing_demand = ROUND(GREATEST(md_recorded * multiplying_factor,
                                  contract_demand * 0.75)::numeric, 2),
  energy_charges = ROUND((kwh * multiplying_factor * 8.44)::numeric, 2),
  demand_charges = ROUND((GREATEST(md_recorded * multiplying_factor,
                                   contract_demand * 0.75) * 650.0)::numeric, 2),
  fac_charges = ROUND((kwh * multiplying_factor * 0.30)::numeric, 2),
  wheeling_charges = ROUND((kwh * multiplying_factor * 0.81)::numeric, 2),
  electricity_duty = ROUND((kwh * multiplying_factor * 0.275)::numeric, 2),
  taxes = ROUND((kwh * multiplying_factor * 0.279)::numeric, 2),
  pf_rebate = CASE
    WHEN power_factor >= 0.95 THEN
      ROUND(((kwh * multiplying_factor * 8.44) +
             (GREATEST(md_recorded * multiplying_factor,
                       contract_demand * 0.75) * 650.0)) * 0.01::numeric, 2)
    ELSE 0
  END,
  pf_surcharge = CASE
    WHEN power_factor < 0.90 THEN
      ROUND(((kwh * multiplying_factor * 8.44) +
             (GREATEST(md_recorded * multiplying_factor,
                       contract_demand * 0.75) * 650.0)) * 0.05::numeric, 2)
    ELSE 0
  END,
  net_bill = ROUND(
    ((kwh * multiplying_factor * 8.44) +
     (GREATEST(md_recorded * multiplying_factor,
               contract_demand * 0.75) * 650.0) +
     (kwh * multiplying_factor * 0.30) +
     (kwh * multiplying_factor * 0.81) +
     (kwh * multiplying_factor * 0.275) +
     (kwh * multiplying_factor * 0.279) +
     (CASE WHEN power_factor < 0.90 THEN
        ((kwh * multiplying_factor * 8.44) +
         (GREATEST(md_recorded * multiplying_factor,
                   contract_demand * 0.75) * 650.0)) * 0.05
      ELSE 0 END) -
     (CASE WHEN power_factor >= 0.95 THEN
        ((kwh * multiplying_factor * 8.44) +
         (GREATEST(md_recorded * multiplying_factor,
                   contract_demand * 0.75) * 650.0)) * 0.01
      ELSE 0 END) -
     (CASE WHEN subsidy > 0 THEN
        ((kwh * multiplying_factor * 8.44) +
         (GREATEST(md_recorded * multiplying_factor,
                   contract_demand * 0.75) * 650.0) +
         (kwh * multiplying_factor * 0.30) +
         (kwh * multiplying_factor * 0.81)) * subsidy / 100
      ELSE 0 END)
    )::numeric, 2),
  estimated_bill = ROUND((kwh * multiplying_factor * 8.44)::numeric, 2),
  avg_unit_cost = CASE
    WHEN kwh * multiplying_factor > 0 THEN
      ROUND((net_bill / (kwh * multiplying_factor))::numeric, 2)
    ELSE 0
  END;

-- Sanity check: sample rows with raw vs actual MD and the new billing demand.
SELECT
  meter_name,
  logged_at,
  md_recorded,
  multiplying_factor,
  ROUND((md_recorded * multiplying_factor)::numeric, 1) AS actual_md_kva,
  billing_demand,
  demand_charges,
  net_bill
FROM public.energy_logs
ORDER BY logged_at DESC
LIMIT 20;
