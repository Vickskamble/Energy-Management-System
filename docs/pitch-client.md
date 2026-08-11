# PowerEMS — Client Pitch (Customer Deck)

> **Product:** PowerEMS (Energy Management System)
> **Audience:** MSME industrial / commercial electricity consumers (India), factory owners, plant managers, energy consultants.
> **Version:** v1.0.3 · Status: Live (Web, Android, Windows, macOS)

---

## 1. The One-Liner

PowerEMS reads your electricity meter data once a month, and tells you exactly what your bill *should* be, why it is what it is, and how to cut ₹50,000–₹5,00,000+ per year — before the discom bill even arrives.

---

## 2. The Problem

- Electricity bills are **opaque**. MSME owners pay ₹1–10 lakh/month without knowing which component (demand, PF, FAC, wheeling, duty, taxes) is eating their margin.
- **Demand charges** (₹650/kVA) punish a single bad peak — one 15-minute spike can cost more than a whole month of savings.
- **Power factor** penalties (5% surcharge) and missed **rebates** (1%) silently leak money every month.
- Bills are paper PDFs; there is **no trend, no forecast, no alert** — problems are discovered months late.
- Excel is manual, error-prone, and nobody reconciles the discom bill against actual meter data.

## 3. The Solution

PowerEMS is a cross-platform app (Android / Web / Windows / macOS) that:

1. **Imports readings in seconds** — paste or import Excel/PDF, or enter manually (one reading per meter per day).
2. **Recomputes your bill with the discom's own tariff logic** — kVAh billing, demand ratchet, PF rebate/surcharge, FAC, wheeling, duty, taxes, TOD, subsidies.
3. **Predicts MD breaches before they happen** — a forecast tells you "you will cross 190 kVA on 24 Aug at this growth rate."
4. **Alerts you instantly** — Low PF penalty alert, near-MD-breach alert, month-end reading reminder (push notifications).
5. **Shows you exactly where money is leaking** — Bill Health Score (0–100), load factor, average unit cost, anomaly detection (±30% spikes/dips).
6. **Recommends savings** — capacitor bank sizing (kVAR), demand reduction, load smoothing, contract-demand optimization, all ranked by ₹ saved.
7. **Reconciles against the actual discom bill** — tolerance ±10%; every difference is highlighted for a dispute/audit.

## 4. What You Get (Feature Snapshot)

| Area | Capability |
|---|---|
| Dashboard | Estimated bill, consumption, max demand, PF, health score, load factor, today's usage, bill forecast, MoM comparison, top-3 savings opportunities |
| Analysis | Full bill breakdown with % share, PF banding, MD vs contract, MD breach prediction, anomaly detection, multi-meter trends |
| Billing engine | kVAh-based billing × CT/PT ratio, 11-month demand ratchet, PF rebate (≥0.95) / surcharge (<0.90), FAC ₹0.30, wheeling ₹0.81, duty ₹0.275, taxes ₹0.279, TOD zones, subsidies |
| Alerts | Low PF penalty, near MD breach, reading reminder, sync complete (push + in-app) |
| Meters | Multiple meters, CT/PT multiplying factor per meter, contract demand, sites |
| Import | Excel (.xlsx/.xls, 10 MB / 5,000 rows) with smart column mapping + editable preview; PDF import; backup/restore (JSON) |
| Reports | CSV/PDF export, bill reconciliation, reading log with edit/delete |

## 5. Savings Math (Real Examples)

- **PF 0.80 → 0.95** on a ₹1,00,000 energy+demand bill: eliminates **5% surcharge + earns 1% rebate ≈ ₹6,000/month ≈ ₹72,000/year**.
- **MD reduction 2,500 kVA → 2,250 kVA** (load smoothing): **(2,500 − 2,250) × ₹650 = ₹1,62,500/year**.
- **Capacitor bank**: `kVAR = (1/PF − 1/0.95) × Billing Demand` — a ₹15,000 capacitor investment typically recovers in 2–4 months.

## 6. How It Works (Your Monthly Flow, ~10 Minutes)

1. Get meter reading / bill PDF from discom (or your meter itself).
2. Open PowerEMS → Reports → Import (or manual entry).
3. App validates, dedupes (one reading per meter/day), shows editable preview.
4. App computes the full bill, health score, savings, forecast, alerts.
5. Compare with the actual bill — reconciliation report flags any difference.

No hardware, no sensors, no installation. Your existing readings are enough.

## 7. Data Safety — What We Promise (Summary)

- **You own your data.** Row-Level Security: each user's data is physically isolated in the database; no other account can ever read or write your rows.
- **Encrypted in transit (HTTPS end-to-end)**; session tokens stored in OS-level secure storage (Android Keystore / Windows DPAPI / macOS Keychain / WebCrypto).
- **Single-device sessions** — your account can't be silently used elsewhere; conflict = forced sign-out + alert.
- **No data selling, no ads, no third-party sharing.** Full details in `privacy-policy.md`, `dpa.md`, `security-overview.md`.
- **Backup/restore** lets you migrate devices safely (encrypted backups on the roadmap).

## 8. Client FAQ (Questions You Can Ask Us)

**Q1. Is my factory's electricity data visible to anyone else?**
No. Supabase Row-Level Security (RLS) enforces `auth.uid() = user_id` on all 11 tables — your rows are only ever returned to your own logged-in account. This is enforced at the database level, not just in the app.

**Q2. Do I need new hardware or sensors?**
No. PowerEMS works with the readings you already take from your meter and the bills you already receive.

**Q3. How accurate is the bill calculation?**
It applies the same tariff math discoms use (kVAh × CT/PT ratio, 11-month demand ratchet, PF bands, FAC/wheeling/duty/tax per unit, TOD, subsidies). Reconciliation mode compares against your actual bill with a configurable tolerance (default ±10%) and flags every difference.

**Q4. What happens if I have no internet?**
The app requires a connection to save/load data (cloud-first). During brief outages the app shows clear error messages; data is never silently lost. Offline mode is on the roadmap.

**Q5. Which tariff rates does it use?**
All rates are fully configurable per account (Settings → Billing): per-unit tariff, demand charge, FAC, wheeling, duty, tax, subsidy, TOD multipliers, contract demand, preceding 11-month demands. Per-state presets (UPCL, MKVVNL, MSEDCL) are on the roadmap.

**Q6. Can I track multiple meters and multiple sites?**
Yes — unlimited meters, each with its own CT/PT multiplying factor, contract demand, and site grouping.

**Q7. Will the app help me reduce my bill, or just track it?**
Both. It tracks with discom-grade accuracy and actively recommends: capacitor sizing, demand reduction, load smoothing, contract-demand optimization, tariff review — each with the ₹ amount you can save.

**Q8. What are the MD breach alerts?**
If your peak demand crosses 90% of contract (warning) or the contract itself (breach), the app predicts the breach date from your growth trend and alerts you — so you can shift load before the penalty (₹650/kVA) hits.

**Q9. How do I know the readings are right?**
Every entry is validated: no negatives, current ≥ previous, no future dates, one reading per meter per day (duplicate blocked at app and database level). The cumulative chain is auto-repaired if a bad import is detected.

**Q10. Can I export my data?**
Yes — CSV/PDF reports and a full JSON backup (logs, meters, tariff settings, actual bills) that you can restore on any device.

**Q11. Is there a free trial or demo?**
Yes — a live demo account is available; ask us for credentials. The web version runs on GitHub Pages and can be tested immediately.

**Q12. What support do I get?**
Onboarding (data import help), tariff configuration assistance, and bill-reconciliation reviews. SLA and support tiers are offered with paid plans.

**Q13. How often is the app updated?**
Continuous: CI/CD pipeline runs tests + static analysis on every release; bug fixes are shipped via web instantly and via app-store releases for mobile/desktop (v1.0.0 → v1.0.3 shipped on a single-day cycle for a critical fix).

**Q14. What if I already have months of historical data?**
Import it — the consumption chain reconstructs cumulative readings automatically, so history, trends, and the 11-month ratchet work from day one.

**Q15. Do you store my bill PDFs / personal identity?**
Only what you enter: email, meter details, readings, tariff settings, and (optional) actual-bill amounts for reconciliation. No identity documents, no payment details, no location tracking.

## 9. Client Expectations (What We Expect From You)

- Provide **correct meter readings** (or import files) each month — garbage in, garbage out; the app validates what it can but can't know your meter better than you.
- Set your **real contract demand and tariff rates** once during onboarding (or accept defaults and refine later).
- Review the **reconciliation report** monthly — that's where billing errors from the discom surface.
- Keep your **login credentials secure**; single-device enforcement will log out an unauthorized session automatically.
- Give us **30–60 days of data** before judging savings — trends need a full billing cycle; MD/ratchet insights need ≥6 months (the contract-demand optimizer explicitly requires 6+ months).

## 10. Pricing Models (Indicative)

| Tier | Fit | Price (indicative) |
|---|---|---|
| Lite | Single meter, single site, core tracking | ₹499–999/month |
| Pro | Multi-meter, analysis, alerts, reconciliation | ₹1,999–4,999/month |
| Enterprise | Multi-site, consultant access, audit exports, SLA | Custom (annual) |

*Final pricing is decided with the client; no lock-in — export your data any time.*

## 11. Contact & Demo

- Web app (live): GitHub Pages — link available on request
- Demo account: `demo@example.com` (ask for password)
- Repository: github.com/Vickskamble/Energy-Management-System
- Documents: Privacy Policy · Terms of Service · DPA · NDA · Security Overview (this package)

---

*PowerEMS — "Your bill, decoded. Your savings, automated."*
