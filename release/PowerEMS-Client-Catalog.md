# PowerEMS — Energy Management System
### Client Product Catalog & Feature Overview

**Version 1.0.0** | 5 August 2026

---

## 1. Product Overview

PowerEMS is a complete **Energy Management & Billing System** built for industrial and commercial clients who need to track electricity consumption, analyze power quality, and estimate monthly bills. It replaces manual register books and spreadsheet tracking with a digital platform that automatically calculates bills, detects anomalies, and recommends savings.

**Key benefits for your clients:**
- Real-time visibility of daily consumption, demand, and power factor
- Automatic bill estimation with utility-style calculations (energy, demand, PF penalty/rebate, duty, taxes)
- Excel import from ANY client file format — no manual re-entry of historical data
- Actionable insights: how to reduce the next bill
- Works offline-first, syncs to cloud when online
- One system for multiple sites and multiple meters

---

## 2. Platform Availability

| Platform | Status | Distribution |
|----------|--------|--------------|
| **Android** | ✅ Ready | APK (59.4 MB) — direct install / Play Store |
| **Web** | ✅ Ready | Hosted at vickskamble.github.io/Energy-Management-System |
| **Windows Desktop** | 🔧 In progress | EXE installer (build tools being set up) |

All platforms share the same features, data, and calculations.

---

## 3. Core Features

### 3.1 Dashboard — Energy Overview
- **Est. Monthly Bill** — full bill calculated automatically (energy + demand + PF + duty + taxes)
- **Total Consumption** — monthly kWh usage
- **Max Demand** — peak kVA recorded and compared against contract demand
- **Power Factor** — live PF with rebate/penalty status
- **Bill Health Score** — 0-100 score with penalty flags
- **Load Factor** — how efficiently the demand is utilized
- **Bill Forecast** — projected month-end bill based on current usage pace
- **Month Comparison** — this month vs previous: bill, units, demand, PF with % change
- **System Alerts** — immediate warning when PF drops below 0.95 or demand crosses 190 kVA
- **Bill Saving Opportunities** — prioritized savings list (demand reduction, PF improvement, load smoothing, contract optimization)
- **Smart Insights** — plain-language explanation of what the numbers mean
- **Recommendations** — actionable steps with estimated savings
- Site selector — view all sites combined or individual sites

### 3.2 Reading Entry — Manual
- Record daily readings: kWh, kVAh, rkVARh Lag, rkVARh Lead, Max Demand
- Meter selection with automatic CT/PT multiplying factor
- Duplicate date detection, validation warnings (PF mismatch, abnormal jumps)

### 3.3 Excel Import — Bulk History Upload
- Import complete historical data from client Excel files
- **Smart column detection** — automatically identifies Date, kWh, kVAh, MD, Lag, Lead columns
- **Manual column mapping** — user confirms/overrides mapping for any file format (works with every client's register style)
- **Cumulative reading detection** — auto-converts meter running totals (57,037 → per-day usage) to daily consumption
- **PF as-is** — power factor from client file stored exactly as recorded, never recalculated
- Full preview with edit before import, duplicate detection

### 3.4 Analysis
- **Reading History** — complete table with date, kWh, kVAh, PF, MD, Lag/Lead
- **Power Quality Trends** — PF & Load Factor charts over recent readings
- **kWh Consumption chart** — daily consumption trends
- **Max Demand chart** — daily peak demand trends
- **Month-over-month comparison** — bill, units, demand, PF deltas
- **Anomaly Highlights** — months where consumption deviates 30%+ from average
- Edit/delete any reading with validation

### 3.5 Reports
- Executive summary with KPI breakdown for selected period/meter
- Estimated vs actual bill comparison
- **PDF export** — professional energy management report
- **CSV export** — data for client spreadsheets

### 3.6 Meter Management
- Add/delete meters with name, site, contract demand, CT/PT ratio (multiplying factor)
- Site grouping for multi-site clients

### 3.7 Billing Engine (Utility-Accurate)
- **Energy charges** — units × tariff
- **Demand charges** — billing demand (max of recorded MD and 75% of contract) × rate/kVA
- **PF rebate** — 1% rebate when PF ≥ 0.95
- **PF surcharge** — 5% penalty when PF < 0.90
- **FAC (Fuel Adjustment)** — per-unit rate
- **Wheeling charges** — per-unit rate
- **Electricity duty** — per-unit rate
- **Taxes** — per-unit rate
- **TOU/TOD charges** — optional time-of-day component
- Bill Health Score with validation (rebate/penalty consistency checks)

### 3.8 Data & Cloud
- **Supabase cloud sync** — user-scoped secure data (login required)
- **Offline-first** — readings saved locally, sync when online
- **Backup & Restore** — full data backup to file, restore from file
- **Multi-user** — each user sees only their own data (RLS-protected)

### 3.9 User Experience
- Login / Registration with password reset
- Dark & light theme
- Fully responsive: Android (drawer nav, 2-column grid), Desktop (sidebar, 4-column grid)
- Hindi/English-friendly interface labels

---

## 4. Security

- Supabase authentication (email/password)
- Row-Level Security — data isolated per user account
- Data validation on every entry (PF bounds, demand checks, duplicate detection)
- No secrets stored in client code

---

## 5. Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (single codebase → Android, Web, Windows) |
| Backend | Supabase (PostgreSQL + Auth + RLS) |
| Charts | fl_chart |
| Excel | excel package (read/write .xlsx) |
| File pick / share | file_picker, share_plus |
| PDF | custom report service |

---

## 6. Demo Credentials (for client demonstration)

> Login: **gkh@ems.com** | Password: **gkh1234**

---

## 7. What's Next (Roadmap)

- ✅ Dashboard with estimated bill + forecast
- ✅ Excel import with universal column mapping
- ✅ Android + Web release
- 🔧 Windows desktop EXE
- 📌 Client-specific tariff profiles
- 📌 Multi-month demand tracking (rolling 12-month max demand)
- 📌 Push notifications for PF/demand alerts
