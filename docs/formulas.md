# PowerEMS — Calculation Formulas (Complete Reference)

> All constants below are the shipped defaults (editable in Settings → Billing unless noted).
> All monetary values are in ₹ (INR). Billing is performed on **kVAh** (apparent energy), not kWh.

---

## 1. Power Factor

```
PF = kWh / kVAh
```
- Clamped to [0.000, 1.000]. Returns 0.000 if kWh ≤ 0 or kVAh ≤ 0. Rounded to 3 decimals.
- Used in: bill calculation, dashboard KPI, PF alerts, insight generation.
- *Example: 100 kWh / 125 kVAh = 0.800*

## 2. Multiplying Factor (per meter)

```
MF = CT ratio × PT ratio        (CT/PT set per meter; default 1.0, default MF = 5.0)
Total Units = Σ(consumed kVAh × MF) per billing month
```

## 3. Billing Demand (Demand Ratchet)

```
Ratchet Peak   = max( highest monthly MD in trailing 11 months, user-entered preceding 11-month demands )
Billing Demand = max( Recorded MD of current month, Ratchet Peak )
```
- Recorded MD = `md_recorded × MF`.
- ⚠️ The **75% of contract demand is a chart reference only — it is never part of the bill.** (75% appears as a dashed "stay above" line and inside savings logic.)

## 4. Bill Components (all in ₹)

| Component | Formula | Default rate |
|---|---|---|
| Energy Charges | Total Units × Tariff | ₹8.44 / unit |
| Demand Charges | Billing Demand × Demand Rate | ₹650.00 / kVA |
| FAC | Total Units × 0.30 | ₹0.30 / unit |
| Wheeling | Total Units × 0.81 | ₹0.81 / unit |
| Electricity Duty | Total Units × 0.275 (flat, not %) | ₹0.275 / unit |
| Taxes | Total Units × 0.279 (flat, not %) | ₹0.279 / unit |
| TOD | Energy × (weightedAvgMultiplier − 1) | 0 (all multipliers 1.0) |
| PF Rebate | (Energy + Demand) × 1.0% if PF ≥ 0.95 | 1.0% |
| PF Surcharge | (Energy + Demand) × 5.0% if PF < 0.90 | 5.0% |
| Subsidy | (Energy + Demand + FAC + Wheeling + TOD) × % | 0% |
| Region Subsidy | flat deduction | ₹0 |
| Rebate u/s 106 | flat deduction | ₹0 |

### TOD details
```
TOD = Energy Charges × (weightedAvgMultiplier − 1)
weightedAvg = mean of 4 zone multipliers [A, B, C, D]
if |weightedAvg − 1| < 0.0001 → TOD = 0
```
Zones: A = 00:00–06:00, B = 06:00–18:00, C = 09:00–18:00, D = 17:00–24:00. Defaults `[1.0, 1.0, 1.0, 1.0]`.

## 5. Net Bill

```
Net Bill = (Energy + Demand + FAC + Wheeling + TOD)
         + Duty + Taxes
         + PF Surcharge
         − PF Rebate − Subsidy − Region Subsidy − Rebate u/s 106
```
All components rounded to 2 decimals before summing.

### Worked example
Month with 1,250 kVAh units (250 kVAh × MF 5) and 150 kVA demand, PF 0.80:
- Energy = 1,250 × 8.44 = ₹10,550
- Demand = 150 × 650 = ₹97,500
- FAC = 1,250 × 0.30 = ₹375 · Wheeling = 1,250 × 0.81 = ₹1,012.50
- Duty = 1,250 × 0.275 = ₹343.75 · Taxes = 1,250 × 0.279 = ₹348.75
- PF surcharge (PF < 0.90) = 5% × (10,550 + 97,500) = ₹5,402.50
- **Net Bill ≈ ₹1,15,532.50**

## 6. Derived KPIs

```
Load Factor        = Avg Demand / Peak Demand, clamped [0,1] (0 if peak ≤ 0)
Average Unit Cost  = Net Bill / Total Units (₹/unit; 0 if units ≤ 0)
Estimated Bill     = units × MF × tariffRate   (units = (kWh × MF).round())
Percent Change     = prev == 0 ? (cur > 0 ? 100 : 0) : (cur − prev)/|prev| × 100
```

## 7. Scores (0–100)

### Bill Health Score
```
start 100
− (0.95 − PF) × 100                  if PF < 0.95
− (0.75 − LF) × 50                   if LF < 0.75
− ((Billing − Contract)/Contract) × 30  if Billing > Contract
− 15                                 if PF Surcharge > 0
clamp [0, 100]
```

### Energy Score
```
start 100
− 20  if PF < 0.95
− 15  if LF < 0.75
then × (1 / (1 + avgUnitCost × 0.001))
clamp [0, 100]
```

## 8. Bill Forecast (projected month-end)

```
scale            = daysInMonth / daysElapsed        (daysElapsed clamped [1, daysInMonth])
Projected Units  = monthBreakdown.totalUnits × scale
Forecast Energy  = projectedUnits × tariff
Forecast FAC     = projectedUnits × 0.30
Forecast Wheeling= projectedUnits × 0.81
Forecast Duty    = projectedUnits × 0.275
Forecast Demand  = billingDemand × ₹650
```
*Example (test): 2 logs × 250 kVAh × MF 5 = 2,500 units; on day 10 of 31 → 2,500 × 31/10 = 7,750 projected units.*

## 9. Savings Opportunities (top 3, ₹-ranked)

```
Demand reduction:      floor   = contract × 0.75
                       reduced = max(floor, billingDemand × 0.9)
                       savings = (billingDemand − reduced) × ₹650

PF improvement:        PF < 0.90  → 6% (5% surcharge + 1% rebate) of (Energy + Demand)
                       0.90 ≤ PF < 0.95 → 1% of (Energy + Demand)

Load smoothing:        avg        = billingDemand × loadFactor
                       targetPeak = avg / 0.85
                       newBilling = max(floor, targetPeak)
                       savings    = (billingDemand − newBilling) × ₹650

Contract demand opt.:  needs ≥ 6 months data; if maxPeak < contract × 0.8
                       → suggest ceil(maxPeak/50) × 50 kVA step
                       savings = (contract − suggested) × ₹650
```

## 10. Capacitor Bank Recommendation

```
kVAR = (1/PF − 1/0.95) × Billing Demand
```
*Example: PF 0.85, demand 200 kVA → (1/0.85 − 1/0.95) × 200 ≈ 24.8 kVAR.*

## 11. Recommendation Engine (priorities)

| Priority | Rule |
|---|---|
| 10 | Urgent: Improve PF (capacitor sizing above) |
| 9 | Demand > 85% of contract → penalty estimate `(billingDemand − contract) × ₹650` |
| 6 | Demand < 50% of contract → reduce contract to `billingDemand × 1.2` |
| 5 | Avg unit cost > ₹10 → tariff review |
| 4 | Non-energy charges > 40% → tariff optimization |

## 12. MD Breach Prediction (Analysis page)

```
threshold  = contract × 0.9            (mdWarningRatio)
if peakMd > contract        → "breach crossed" (penalty applies)
elif peakMd ≥ threshold     → daysToBreach = (threshold − peakMd) / growthRate
                              breachDate  = now + ceil(daysToBreach)
```
Growth rate = month-over-month MD growth from the latest month (extrapolation).

## 13. Consumption Chain & Data Integrity

```
consumed = current cumulative reading − previous cumulative reading   (per meter)
```
- **Legacy rows** (no stored cumulative): `currentKwh` reconstructed as a running sum anchored to the first real reading.
- **Chain repair** (`repairConsumptionChain`): if a stored consumed value ≥ 80% of the cumulative reading (corrupt import), it is recomputed as `current − previous`; a meter **rollover** (lower reading) starts a new baseline and keeps its value.
- **Duplicate rule:** one reading per meter per calendar day — enforced in the app AND by a database unique index `(user_id, meter_name, logged_at)`.

## 14. Fixed Thresholds (not UI-editable)

| Constant | Value |
|---|---|
| PF rebate threshold | PF ≥ 0.95 |
| PF surcharge threshold | PF < 0.90 |
| PF penalty warning | PF < 0.95 |
| MD warning ratio | 0.9 × contract |
| MD warning absolute | ≥ 190 kVA |
| Load factor "good" | ≥ 0.75 |
| Ratchet window | trailing 11 months |
| Billing demand floor (reference only) | 75% of contract |
| Bill accuracy tolerance (reconciliation) | ±10% |

---

*Formula engine: `EnergyCalculator` / `CalculationEngine` (client-side, rule-based, no AI) · verified by unit tests in `test/unit/` (bill_breakdown, bill_forecast, savings_opportunity).*
