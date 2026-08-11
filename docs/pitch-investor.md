# PowerEMS — Investor Pitch

> **Product:** PowerEMS (Energy Management System) — discom-accurate electricity bill intelligence for MSME industry.
> **Stage:** Post-MVP, revenue-ready · v1.0.3 live on Web/Android/Windows/macOS
> **Ask:** Seed funding (see §10) · **Deck date:** Aug 2026

---

## 1. Executive Summary

Indian MSMEs spend ₹4–10 lakh per month on electricity — and almost none of them understand their bill. Discom tariffs are the most complex part of running a factory: demand charges, power-factor penalties, fuel adjustment charges, wheeling, duty, taxes, time-of-day multipliers, and an 11-month demand ratchet that punishes a single bad peak.

**PowerEMS decodes the discom bill with the discom's own math.** It ingests one meter reading per month, recomputes the exact bill, predicts MD breaches before they happen, alerts on PF penalties, and ranks savings opportunities by rupees. It is hardware-free, cloud-first, multi-platform, and secured with database-level row isolation.

We have shipped a production-grade MVP (3 releases, automated CI/CD, full test + static-analysis pipeline, 15-item security register), with a live web deployment and installers for Android, Windows, and macOS.

## 2. The Problem (Market Pain)

- **Opaque billing:** MSME owners cannot decompose a bill into energy, demand, FAC, wheeling, duty, tax, PF, TOD. They can't audit the discom.
- **Silent leakage:** PF penalty (5% on energy+demand), missed 1% rebate, single 15-min demand spike at ₹650/kVA — thousands of rupees/month, discovered months late or never.
- **No tooling:** Excel is manual; no alerts, no forecasts, no trend analysis; energy auditors charge ₹25k–1L per audit and visit quarterly.
- **Post-COVID energy-cost pressure:** electricity tariffs have risen ~5–8%/year; MSME margins are thinning — energy cost control is now a board-level topic.

## 3. The Solution

A rule-based billing intelligence engine + consumer app:

1. **Reading ingestion** — Excel/PDF import with smart column mapping, manual entry, validation, dedupe, per-meter CT/PT ratio.
2. **Discom-grade billing engine** — kVAh × MF billing, demand ratchet (max of recorded MD vs trailing 11-month peak + manual inputs), PF rebate/surcharge slabs, FAC/wheeling/duty/tax, TOD zones, subsidies, net-bill composition.
3. **Predictive alerts** — MD breach date forecast (growth-rate extrapolation), PF penalty alert, month-end reading reminders (push + in-app).
4. **Actionable insight engine** — Bill Health Score (0–100), load factor, average unit cost, anomaly detection (±30%), capacitor bank sizing, demand reduction, load smoothing, contract-demand optimizer, tariff review.
5. **Reconciliation** — compares computed vs actual bill (±10% configurable tolerance) → dispute/audit ammunition.
6. **Multi-platform** — Android, Web, Windows, macOS from one Flutter codebase; cloud-first (Supabase) with full RLS isolation.

## 4. Traction & Progress

| Item | Status |
|---|---|
| Releases | v1.0.0 → v1.0.3 (Aug 2026), critical boundary bug fixed + shipped same-day |
| CI/CD | GitHub Actions: tests → `dart analyze` → APK + Web + Windows + macOS builds → GitHub Pages + Release assets (APK, installers, zips) |
| Tests | Unit tests for bill calculator, forecast, savings engine (bill_breakdown, bill_forecast, savings_opportunity) |
| Security | 15-item register (G1–G15): RLS on 11 tables, single-device sessions, secure token storage, CSP + security headers on web, import size caps, dedup unique index, Dependabot |
| Live | GitHub Pages web build live; Android APK + Windows installer + macOS/Windows zips on GitHub Releases |
| Audit | Final security/functional audit 01 Aug 2026 — all issues closed (Phase 2 items clearly scoped) |

## 5. Market (TAM / SAM / SOM)

- **TAM:** ~6.3 crore MSMEs in India (MSME Ministry); ~22% industrial electricity consumption share. Electricity billed to industry is a multi-trillion-₹ annual market.
- **SAM:** MSMEs with LT/HT industrial connections with contract demand ≥50 kVA (where demand + PF logic applies) — est. several lakh consumers across UP, Maharashtra, Karnataka, Gujarat, TN, MP.
- **SOM (12–24 mo):** 500–2,000 paying accounts across 2–3 states via direct sales + energy-auditor channel (each auditor manages 50–200 client factories).

## 6. Business Model

SaaS subscription per account (indicative):

| Tier | Price/month | Scope |
|---|---|---|
| Lite | ₹499–999 | 1 meter, core tracking, estimated bill |
| Pro | ₹1,999–4,999 | Multi-meter, analysis, alerts, reconciliation, savings engine |
| Enterprise | ₹50k–2L/year | Multi-site, auditor/consultant accounts, branded PDF reports, SLA |

Revenue levers: subscription ARR, energy-auditor white-label channel, per-state tariff-preset packs, future paid insights (AI/OCR premium tier).

## 7. Competitive Moat

1. **Billing-accuracy engine** — discom tariff math (ratchet, PF bands, TOD, per-unit levies) implemented and unit-tested; most competitors show "estimated" figures that cannot survive a bill audit.
2. **Reconciliation** — the only feature that turns the app into an audit tool against the discom bill.
3. **Prediction before penalty** — MD breach date forecast is proactive, not reactive.
4. **Security-first architecture** — database-level RLS, single-device sessions, hardened web deployment; ready for enterprise compliance conversations (DPA, NDA templates included in this package).
5. **Hardware-free, zero-OPEX adoption** — no sensors, no IoT, no installation cost → near-zero customer acquisition friction.
6. **Multi-platform from day one** — factory owner (Android), consultant (Web), office (Windows/macOS).

## 8. Roadmap (Funded)

**Phase 2 (0–9 months):**
- AI-driven insights (Gemini-based natural-language bill explanation)
- Per-state tariff presets (UPCL, MKVVNL, MSEDCL, …) + auto rate updates
- MD breach report (PDF) + report-type dropdown + branded PDFs
- OCR/JPG bill import; WhatsApp sharing; Hindi i18n
- Offline-first mode; encrypted backups
- MFA (TOTP), server-side session revocation, certificate pinning

**Phase 3 (9–18 months):**
- Role-based access (owner/operator/auditor) + auditor multi-tenant dashboard
- CA/auditor export pack, YoY comparisons, cohort insights
- B2B SaaS admin console, billing/subscription management
- Supabase App Check / Edge Functions for server-side business rules

## 9. Financial Projections (Indicative — to be detailed in data room)

| Year | Accounts | ARR (₹ cr) | Note |
|---|---|---|---|
| Y1 | 300 | ~0.6 | Pro-heavy onboarding, 2 states |
| Y2 | 1,200 | ~3.0 | Auditor channel + 2 more states |
| Y3 | 4,000 | ~11.0 | Enterprise tier + AI premium |

Unit economics: CAC ~₹2,000–4,000 (direct) / ~₹500–1,000 (auditor channel); gross margin ~85–90% (cloud + support only); monthly churn target <2%.

## 10. The Ask

**₹75L–1.5Cr seed** for 18 months:
- 40% product (AI insights, OCR, offline, enterprise console)
- 25% sales & onboarding (2 states, auditor channel)
- 15% security & compliance (MFA, pen-test, SOC2-readiness)
- 10% cloud & tooling (supabase scale, monitoring)
- 10% buffer

Milestones on funding: 1,000 paying accounts + 2 state presets + AI insights GA in 12 months.

## 11. Investor FAQ

**Q1. What is the core unit of value?**
One factory = one subscription. Value is proven by savings: a PF fix alone typically saves ₹50k–1L+/year vs a ₹24k–60k/year Pro subscription.

**Q2. Is this just another dashboard app?**
No — the moat is the billing engine + reconciliation + prediction. Dashboards show charts; PowerEMS shows what the discom *should have billed* and why, and predicts penalties before they occur.

**Q3. How do you acquire customers?**
Direct (factory owner associations, exhibitions, WhatsApp/regional marketing) + energy-auditor channel (commission model) + consultant white-label. No hardware → no installation lead-time.

**Q4. What is the churn risk?**
Low once history accumulates — the 11-month ratchet and trend value create switching cost; backup/export keeps us honest (no lock-in by design).

**Q5. How is data secured?**
Supabase RLS (all 11 tables, `auth.uid() = user_id`), single-device session enforcement, OS-level secure storage, HTTPS, hardened web (CSP/headers), import/restore caps, unique-index dedupe. Details: `security-overview.md`. Roadmap: MFA, pinning, server-side revocation.

**Q6. What compliance do you have?**
Privacy Policy, Terms of Service, DPA, NDA templates shipped with the product (this package); SOC2-readiness scoped for Phase 3.

**Q7. Who are the competitors?**
Energy-audit consultancies (manual, expensive, quarterly), generic Excel models, and thin IoT dashboards. PowerEMS is cheaper than one quarterly audit and always-on.

**Q8. What is the regulatory risk?**
Tariffs change per discom — our configurable tariff editor + per-state presets absorb changes; the reconciliation feature turns tariff changes into an audit advantage, not a liability.

**Q9. What does the unit test suite cover?**
Bill breakdown (kVAh × MF, ratchet, PF bands), forecast scaling, savings opportunities (demand, PF, smoothing, contract optimizer) — verified in CI on every release.

**Q10. Can a competitor copy this quickly?**
Copying the UI is easy; copying discom-grade accuracy requires tariff domain expertise, ratchet logic, reconciliation workflow, and the trust/security layer — that is our 12–18 month head start.

**Q11. What are the biggest risks?**
(1) Sales velocity in a fragmented MSME market — mitigated by auditor channel; (2) tariff complexity across 28 states — mitigated by configurable engine + preset packs; (3) dependence on users submitting monthly readings — mitigated by reminders, import automation, and (Phase 3) bill-OCR.

**Q12. What is the founder/team status?**
Product-led, solo-founder executed to v1.0.3 with full CI/CD and security register — details in data room.

**Q13. What milestones do you commit to on this round?**
1,000 paying accounts, 2 state presets, AI insights GA, MFA shipped, 3 auditor partnerships — all within 12 months of funding.

**Q14. What are your unit economics assumptions?**
CAC ₹2–4k direct / ₹0.5–1k channel; LTV ~₹40–60k (3–4 yr lifetime at Pro tier); payback <6 months.

**Q15. What does a liquidation/exit look like?**
Acquisition by energy-audit firms, ERP vendors, or discom-tech platforms; or B2B SaaS roll-up. Recurring SaaS revenue with a defensible data moat (11-month ratchet history per factory) is the asset.

## 12. Investor Expectations (What We Expect From You)

- **Strategic network:** introductions to energy auditors, MSME associations, industrial parks, and discom-facing partners.
- **Governing:** monthly metrics board (MRR, churn, activation, savings-captured), quarterly product roadmap review; no day-to-day operational interference.
- **Speed of decisions:** 4-week due-diligence window — data room (financials, security docs, tests, audit trail) is ready.
- **Alignment:** long-term (7+ year) horizon; energy cost intelligence in India is a decade-long tailwind.

## 13. Documentation Package (included)

- `formulas.md` — every billing/calculation formula with constants and examples
- `security-overview.md` — RLS, auth, sessions, web hardening, input validation, gaps
- `privacy-policy.md`, `terms-of-service.md`, `dpa.md`, `nda.md` — client-facing legal pack
- `pitch-client.md` — the customer-facing pitch + client FAQ

---

*PowerEMS — "Your bill, decoded. Your savings, automated."*
