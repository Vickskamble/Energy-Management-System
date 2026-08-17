# PowerEMS — Release Notes / Version History

**Maintained by:** PowerEMS (Brilliants Automation and Software Solutions)
**Latest version:** 1.2.2+22 (17 August 2026)
**Last updated:** 18 August 2026

> Changelog compiled from the release history. Dates are release dates (git history).
> Version format: `MAJOR.MINOR.PATCH+build`. Where a version row is empty, the change
> was a build/packaging-only release.

---

## 1.2.x — Web-first distribution

### v1.2.2 — 17 Aug 2026 · Release build
- Daily kWh consumption chart — dashed daily target line in Analysis Trends.

### v1.2.1 — 17 Aug 2026 · Bugfix
- Fixed blank Import screen (sidebar index 7 now maps to the correct stack slot 5).

### v1.2.0 — 17 Aug 2026 · Excel + compliance
- **Excel import** promoted to the main navigation (Import screen, manual column mapping, preview).
- Professional English copy refresh across app.
- Daily kWh target line on the consumption chart.
- **DPDP Act 2023 compliance batch:**
  - "Delete Account" self-service in Settings (full erasure via `delete_account` RPC — all tables + auth user; SQL: `supabase/migrations/20260817_data_governance.sql`).
  - "Reset All Data" now wipes sessions + legacy tables via `delete_all_user_data` RPC.
  - Explicit consent checkbox at registration (ToS + Privacy Policy links).
  - Backup export now paginates — no more truncation beyond 1,000 logs.
  - Grievance contact (Mrvikas_kamble@rediffmail.com) added to Privacy Policy / ToS / DPA;
    hosting docs updated (Vercel; Supabase hosted in India — no cross-border transfer).

## 1.1.x — Payments, tariff parity, installer, live filters

### v1.1.19 — 15 Aug 2026 · Release
- Switched to **Razorpay live keys** (production payments live).
- Dropdown live-refresh: meters register via `MeterRepository` listeners on Dashboard / Analysis / Reports — add/delete a meter and every selector updates instantly (no restart).
- Year dropdown: only real years ("All Years" + years present/current); "This Month" lives in the month dropdown.
- Year/Month selectors work with zero data (current year/month always available).
- All registered meters always visible in Analysis/Reports selectors, even with no readings.
- No-crash guards when a meter is deleted or "All Time" is selected.
- **Signed Windows installer pipeline** (app-local VC++ runtime, Inno Setup, self-signed; see docs/windows-dependency-report.md).

### v1.1.18 — 14 Aug 2026
- Dashboard dropdown filters (year/month/meter) with shared filter bar.
- Owner key "NEW20" added; Razorpay webhook hex-format fix.

### v1.1.17 — 14 Aug 2026
- Immediate payment-status call after checkout + instant UI refresh.

### v1.1.16 — 14 Aug 2026
- Installer build fix: ISPP constant pattern + reliable Inno Setup step in CI.

### v1.1.15 — 14 Aug 2026
- Version alignment; reliable Inno Setup install step in CI.

### v1.1.14 — 14 Aug 2026
- Desktop checkout now uses the browser instead of WebView2 (WebView2 Runtime no longer required).

### v1.1.13 — 14 Aug 2026
- Windows CI fix (PowerShell stderr handling).

### v1.1.12 — 14 Aug 2026
- Real **Windows Setup.exe installer** via Inno Setup.

### v1.1.11 — 14 Aug 2026
- Multi-platform release pipeline (web/APK/Windows in CI).

### v1.1.10 — 14 Aug 2026
- Extra-meter addon idempotency fix; meter filter always visible.

### v1.1.9 — 14 Aug 2026
- Webhook-independent payment sync; app version badge in settings.

### v1.1.8 — 13 Aug 2026
- PF: user-input-first; dashboard meter filter; in-app checkout polling.

### v1.1.7 — 13 Aug 2026
- Instant payment confirmation via Razorpay direct query (payment-status edge function, no webhook wait).
- PF aggregation respects multiplying factors; kVAh-missing fallback.
- Daily-mode bill estimate excludes the demand charge.

### v1.1.6 — 13 Aug 2026
- Date-wise dashboard: Daily/Monthly modes — all KPI cards follow the selected date.
- Web checkout page (desktop layout, auto-redirect after payment).
- Instant plan update via 4-second payment polling.

### v1.1.5 — 13 Aug 2026
- Tariff parity batch 2: monthly FAC passthrough, tax as % of energy charges, ICR ₹0.75/unit, load-factor incentive, PPD 2%, bulk rebate, arrears/DPC, ₹10 rounding, kVAh billing toggle.

### v1.1.4 — 13 Aug 2026
- MERC tariff category selector + FY 25-26 / FY 26-27 presets; duty % (HT exempt); LT slab billing; fixed charges; revised ToD defaults; razorpay-webhook `subscription.paid` fix.

### v1.1.3 — 12 Aug 2026 · Build-only
- CORS headers + OPTIONS preflight for subscription-checkout (web payments unblocked).
- `RAZORPAY_KEY_ID` embedded from CI secrets (.env) — in-app checkout works in released builds.

### v1.1.2 — 12 Aug 2026
- Render-error logging; WebView-init fallback to browser payment.

### v1.1.1 — 12 Aug 2026
- In-app WebView checkout; extra-meter top-ups (₹99/meter, no base re-charge); installer refresh; auto-refresh plan status on app resume; backward-compatible checkout response.

### v1.1.0 — 12 Aug 2026 · Billing release
- **SaaS subscriptions + referrals (Razorpay)** — checkout, plan entitlements, referral program (+1 free month per referral).
- RLS verified live (11 tables, 49 policies); session-gate Edge Function deployed.
- Demo credentials purged from git history; gap register updated.
- Working email-confirmation redirects; encrypted backups (AES-256-GCM + PBKDF2).
- Windows installer attached to releases (versioned + stable alias).

## Pre-1.1.0 foundation (06–11 Aug 2026)
Features shipped in the 1.0.x line and rolled into 1.1.0:
- Actual meter readings (store `current_kwh`/`current_kvah`; Reading + Consumed shown in reports/analysis/PDF/CSV).
- Month filter across Dashboard/Analysis/Reports; auto-fetch previous reading by date.
- MD shown as actual kVA (raw × MF) with monthly MAX charts; 11-month ratchet billing demand.
- Billing correctness: bill on kVAh units; max(recorded MD, 11-month preceding high) only — 75% of MD is a chart reference, never billed; user-filled preceding-11-month demand now respected.
- 0-unit baseline for first readings (with confirm alert); meter renames locked once readings exist; guarded consumption-chain auto-heal.
- Analysis: month-wise trends with daily drill-down (replaces last-30-readings).
- Demo account exempt from single-device enforcement (multiple clients can evaluate simultaneously).
- Import fix: exclusive upper bound on date ranges (midnight-IST duplicates).
- Security hardening: CSP allows gstatic canvaskit + Google Fonts (white-screen fix); false "already signed in" lockout fixed.
- CI: APK + Windows/macOS zip/installer attached to GitHub releases; Flutter 3.44.4 pinned.

---

## Published artifacts (GitHub Release v1.1.19)
| Asset | Link |
|---|---|
| Android APK | github.com/Vickskamble/Energy-Management-System/releases/download/v1.1.19/app-release.apk |
| Windows installer | .../releases/download/v1.1.19/EMS.Setup.v1.1.19.exe |
| Windows portable ZIP | .../releases/download/v1.1.19/Energy-Management-System-Windows-v1.1.19.zip |
| Web app | https://app.brilliants.in (Vercel, continuous deploy) |